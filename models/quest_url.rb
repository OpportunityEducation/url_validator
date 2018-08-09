require File.expand_path('external_url', __dir__)
require 'uri'

class QuestUrl < ExternalUrl
  attr_accessor :subject, :grade_levels, :mock_course, :mock_level
end
