require File.expand_path('external_url', __dir__)
require 'uri'

class ResourceUrl < ExternalUrl
  attr_accessor :quest, :activity
end
