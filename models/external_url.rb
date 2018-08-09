require File.expand_path('../services/status_service', __dir__)
require 'uri'

class ExternalUrl
  attr_accessor :id, :name, :property, :url, :organization

  def initialize(attributes = {})
    attributes.each do |k, v|
      public_send("#{k}=", v)
    end
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

  def valid?
    case status
    when 400, 405, 503
      true
    when 400..499
      false
    when 500..599
      false
    else
      true
    end
  end
end
