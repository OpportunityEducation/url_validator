#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require File.expand_path('../models/quest_url', __FILE__)
require File.expand_path('../models/resource_url', __FILE__)
require File.expand_path('../models/organization', __FILE__)

class App
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

    JSON.parse(open(QUEST_URL).read).last(100).
      reject{ |l| WHITELIST.length > 0 ? l['url'] =~ /(#{WHITELIST})/i : false }.
      each{ |quest_url| @quest_queue.push(QuestUrl.new(quest_url)) }

    JSON.parse(open(RESOURCE_URL).read).last(100).
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
            STDERR.puts "#{resource_url.status} - #{resource_url.url}"
          end
        end
      end
    end

    @threads.each(&:join)
  end
end

App.start()
