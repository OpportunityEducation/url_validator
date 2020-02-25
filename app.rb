#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'open-uri'
require 'json'
require 'erb'
require 'fog/aws'
require 'sendgrid-ruby'
require 'csv'
require File.expand_path('models/quest_url', __dir__)
require File.expand_path('models/resource_url', __dir__)
require File.expand_path('models/organization', __dir__)

# rubocop:disable Metrics/ClassLength
class App
  include SendGrid

  QUEST_URL    = ENV['QUEST_URL']
  RESOURCE_URL = ENV['RESOURCE_URL']
  WHITELIST    = ENV.fetch('WHITELIST', '').split(',').map { |d| Regexp.escape(d) }.join('|')
  THREAD_COUNT = (ENV['MAX_THREADS'] || 20).to_i

  attr_accessor :quest_errors, :resource_errors, :quest_queue, :resource_queue
  attr_reader :mutex

  def self.start
    new.start
  end

  # rubocop:disable Style/StderrPuts
  # rubocop:disable Layout/HashAlignment
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def initialize
    @quest_errors = []
    @resource_errors = []
    @quest_queue, @resource_queue = Queue.new, Queue.new
    @mutex = Mutex.new

    # rubocop:disable Security/Open
    JSON.parse(open(QUEST_URL).read)
        .reject { |l| !WHITELIST.empty? ? l['url'] =~ /(#{WHITELIST})/i : false }
        .reject { |l| l['url'].nil? || l['url'].empty? }
        .each { |quest_url| @quest_queue.push(QuestUrl.new(quest_url)) }

    JSON.parse(open(RESOURCE_URL).read)
        .reject { |l| !WHITELIST.empty? ? l['url'] =~ /(#{WHITELIST})/i : false }
        .reject { |l| l['url'].nil? || l['url'].empty? }
        .each { |resource_url| @resource_queue.push(ResourceUrl.new(resource_url)) }
    # rubocop:enable Security/Open
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  def start
    Thread.abort_on_exception = true
    STDERR.puts "Checking #{@quest_queue.length} quests with #{THREAD_COUNT} threads..."

    @threads = Array.new(THREAD_COUNT) do
      Thread.new do
        until @quest_queue.empty?
          quest_url = @quest_queue.shift

          @mutex.synchronize { quest_errors << quest_url } unless quest_url.valid?
        end
      end
    end

    @threads.each(&:join)

    STDERR.puts "Checking #{@resource_queue.length} quests with #{THREAD_COUNT} threads..."

    @threads = Array.new(THREAD_COUNT) do
      Thread.new do
        until @resource_queue.empty?
          resource_url = @resource_queue.shift

          @mutex.synchronize { resource_errors << resource_url } unless resource_url.valid?
        end
      end
    end

    @threads.each(&:join)

    quest_string = CSV.generate do |csv|
      csv << ['organization', 'id', 'name', 'subject', 'grade levels', 'intended course', 'intended level', 'url', 'status']

      quest_errors.each do |quest|
        csv << [
          quest.organization['name'],
          quest.id,
          quest.name,
          quest.subject,
          quest.grade_levels.join(', '),
          quest.mock_course,
          quest.mock_level,
          quest.url,
          quest.status
        ]
      end
    end

    resource_string = CSV.generate do |csv|
      csv << ['organization', 'quest', 'activity', 'subject', 'grade levels', 'intended course', 'intended level', 'id', 'name', 'url', 'status']

      resource_errors.each do |resource|
        csv << [
          resource.organization['name'],
          resource.quest['name'],
          resource.activity['name'],
          resource.quest['subject'],
          resource.quest['grade_levels'].join(', '),
          resource.quest['mock_course'],
          resource.quest['mock_level'],
          resource.id,
          resource.name,
          resource.url,
          resource.status
        ]
      end
    end

    # jruby?
    Excon.defaults[:ciphers] = 'DEFAULT'

    # create a connection
    connection = Fog::Storage.new(
      provider:               'AWS',
      aws_access_key_id:      ENV['AWS_ACCESS_KEY_ID'],
      aws_secret_access_key:  ENV['AWS_SECRET_ACCESS_KEY']
    )

    # First, a place to contain the glorious details
    directory = connection.directories.create(
      key:    'org-opportunityeducation-quest-development-report',
      public: true
    )

    unless @quest_errors.empty?
      # Upload the quest csv
      @quest_csv = directory.files.create(
        key:    'broken_quests.csv',
        body:   quest_string,
        public: true
      )

      puts "Quest Report: #{@quest_csv.public_url}"
    end

    unless @resource_errors.empty?
      # Upload the resource csv
      @resource_csv = directory.files.create(
        key:    'broken_resources.csv',
        body:   resource_string,
        public: true
      )

      puts "Resource Report: #{@resource_csv.public_url}"
    end

    mail = Mail.new
    mail.from = Email.new(email: 'no-reply@questforward.org', name: 'Quest Forward Team')
    mail.subject = 'Broken Links Report'
    personalization = Personalization.new
    personalization.add_to(Email.new(email: ENV['TO'], name: 'Links'))
    mail.add_personalization(personalization)

    text_email = ERB.new(File.read(File.expand_path('views/email.text.erb', __dir__)))
    mail.add_content(Content.new(type: 'text/plain', value: text_email.result(binding)))

    html_email = ERB.new(File.read(File.expand_path('views/email.html.erb', __dir__)))
    mail.add_content(Content.new(type: 'text/html', value: html_email.result(binding)))

    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    sg.client.mail._('send').post(request_body: mail.to_json)
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Layout/HashAlignment
  # rubocop:enable Style/StderrPuts
end
# rubocop:enable Metrics/ClassLength

App.start
