require File.expand_path('../../services/status_service', __FILE__)
require 'uri'

class ExternalUrl
  attr_accessor :url, :resources

  def initialize(url, resources)
    @url = url.strip
    @resources = resources

    self
  end

  def friendly_url
    if url.length > 40
      url[0..37] + '...'
    else
      url
    end
  end

  def domain
    URI(url).host
  end

  def status
    @status ||= StatusService.call(url)
  end
end
