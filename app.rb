#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require File.expand_path('../models/external_url', __FILE__)
require File.expand_path('../models/resource', __FILE__)

class App
  SOURCE_URL   = ENV['SOURCE_URL']
  WHITELIST    = ENV.fetch('WHITELIST', '').split(',').map{ |d| Regexp.escape(d) }.join('|')
  THREAD_COUNT = (ENV['MAX_THREADS'] || 20).to_i

  attr_accessor :errors, :moved, :queue
  attr_reader :mutex

  def self.start
    new().start
  end

  def initialize
    @errors, @moved, @queue = Array.new, Array.new, Queue.new
    @mutex = Mutex.new

    JSON.parse(open(SOURCE_URL).read).
      reject{ |l| WHITELIST.length > 0 ? l['url'] =~ /(#{WHITELIST})/i : false }.
      inject(Hash.new{ |h,k| h[k] = [] }) { |a, l| a[l.delete('url')] << l; a }.
      each{ |url, resources| @queue.push(ExternalUrl.new(url, resources.map{ |r| Resource.new(r) })) }

    self
  end

  def start
    Thread.abort_on_exception = true
    STDERR.puts "Checking #{@queue.length} urls with #{THREAD_COUNT} threads..."

    @threads = Array.new(THREAD_COUNT) do
      Thread.new do
        until @queue.empty?
          # This will remove the first object from @queue
          external_url = @queue.shift

          case external_url.status
          when 400, 405, 503
            # These seem to be mostly false positives
            next
          when 400..499
            @mutex.synchronize { @errors << external_url }
            STDERR.puts "#{external_url.status} - #{external_url.url}"
          when 500..599
            @mutex.synchronize { @errors << external_url }
            STDERR.puts "#{external_url.status} - #{external_url.url}"
          else
            # do nothing
          end
        end
      end
    end

    @threads.each(&:join)

    html =  "<!DOCTYPE html>"
    html << "<html lang=\"en\">"
    html << "<head>"
    html << "<meta charset=\"utf-8\">"
    html << "<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">"
    html << "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    html << "<title>Upload Errors</title>"
    html << "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css\">"
    html << "<script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js\"></script>"
    html << "</head>"
    html << "<body>"
    html << "<div class=\"container\">"
    html << "<h1>Errors</h1>"
    html << "<table class=\"table\">"
    html << "<thead>"
    html << "<tr><th>URL</th><th>Status Code</th><th>Items</th></tr>"
    html << "</thead>"
    html << "<tbody>"
    @errors.each do |error|
      html << "<tr>"
      html << "<td><ul style='list-style-type: none;'>"
      error.resources.each do |resource|
        html << "<li>#{resource.klass} ##{resource.id} (#{resource.name}) - #{resource.attribute}</li>"
      end
      html << "</ul></td>"
      html << "<td><a href=\"#{error.url}\" title=\"#{error.url}\" target=_blank>#{error.friendly_url}</a></td><td>#{error.status}</td>"
      html << "</tr>"
    end
    html << "</tbody>"
    html << "</table>"
    html << "</div>"
    html << "</body>"
    html << "</html>"

    puts html
  end
end

App.start()
