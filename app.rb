#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'open-uri'
require 'json'
require 'erb'
require 'fog/aws'
require 'sendgrid-ruby'
require File.expand_path('../models/quest_url', __FILE__)
require File.expand_path('../models/resource_url', __FILE__)
require File.expand_path('../models/organization', __FILE__)

class App
  include SendGrid

  QUEST_URL    = ENV['QUEST_URL']
  RESOURCE_URL = ENV['RESOURCE_URL']
  WHITELIST    = ENV.fetch('WHITELIST', '').split(',').map{ |d| Regexp.escape(d) }.join('|')
  THREAD_COUNT = (ENV['MAX_THREADS'] || 20).to_i

  attr_accessor :errors, :quest_queue, :resource_queue
  attr_reader :mutex

  def self.start
    new().start
  end

  def initialize
    @errors, @quest_queue, @resource_queue = Hash.new { |h, k| h[k] = Organization.new }, Queue.new, Queue.new
    @mutex = Mutex.new

    JSON.parse(open(QUEST_URL).read).
      reject{ |l| WHITELIST.length > 0 ? l['url'] =~ /(#{WHITELIST})/i : false }.
      each{ |quest_url| @quest_queue.push(QuestUrl.new(quest_url)) }

    JSON.parse(open(RESOURCE_URL).read).
      reject{ |l| WHITELIST.length > 0 ? l['url'] =~ /(#{WHITELIST})/i : false }.
      each{ |resource_url| @resource_queue.push(ResourceUrl.new(resource_url)) }

    self
  end

  def start
    Thread.abort_on_exception = true
    STDERR.puts "Checking #{@quest_queue.length} quests with #{THREAD_COUNT} threads..."

    @threads = Array.new(THREAD_COUNT) do
      Thread.new do
        until @quest_queue.empty?
          quest_url = @quest_queue.shift

          if !quest_url.valid?
            @mutex.synchronize { @errors[quest_url.organization['id']].quest_errors << quest_url }
            STDERR.puts "#{quest_url.status} - #{quest_url.url}"
          end
        end
      end
    end

    @threads.each(&:join)

    STDERR.puts "Checking #{@resource_queue.length} quests with #{THREAD_COUNT} threads..."

    @threads = Array.new(THREAD_COUNT) do
      Thread.new do
        until @resource_queue.empty?
          resource_url = @resource_queue.shift

          if !resource_url.valid?
            @mutex.synchronize { @errors[resource_url.organization['id']].resource_errors << resource_url }
            STDERR.puts "#{resource_url.status} - #{resource_url.url} - #{resource_url.property}"
          end
        end
      end
    end

    @threads.each(&:join)

    report_template = File.read(File.expand_path('../views/report.html.erb', __FILE__))
    renderer = ERB.new(report_template)

    # jruby?
    Excon.defaults[:ciphers] = 'DEFAULT'

    # create a connection
    connection = Fog::Storage.new({
      provider:               'AWS',
      aws_access_key_id:      ENV['AWS_ACCESS_KEY_ID'],
      aws_secret_access_key:  ENV['AWS_SECRET_ACCESS_KEY']
    })

    # First, a place to contain the glorious details
    directory = connection.directories.create(
      key:    "org-opportunityeducation-quest-development-report",
      public: true
    )

    # Upload the quest json
    @report = directory.files.create(
      key:    "broken_links.html",
      body:   renderer.result(binding),
      public: true
    )

    mail = Mail.new
    mail.from = Email.new(email: 'noreply@questlearning.org', name: 'Broken Links')
    mail.subject = 'Error Report'
    personalization = Personalization.new
    personalization.to = Email.new(email: 'links@questlearning.org', name: 'Links')
    mail.personalizations = personalization

    text_email = ERB.new(File.read(File.expand_path('../views/email.text.erb', __FILE__)))
    mail.contents = Content.new(type: 'text/plain', value: text_email.result(binding))

    html_email = ERB.new(File.read(File.expand_path('../views/email.html.erb', __FILE__)))
    mail.contents = Content.new(type: 'text/html', value: html_email.result(binding))

    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    response = sg.client.mail._('send').post(request_body: mail.to_json)

    puts @report.public_url
    puts response.status_code
    puts response.body
    puts response.headers
  end
end

App.start()
