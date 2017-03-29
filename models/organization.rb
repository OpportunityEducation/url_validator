class Organization
  attr_accessor :quest_errors, :resource_errors

  def initialize
    @quest_errors = []
    @resource_errors = []
  end

  # Hacky, but :shrug:
  def id
    if error = @quest_errors.first || @resource_errors.first
      error.organization['id']
    end
  end

  def name
    if error = @quest_errors.first || @resource_errors.first
      error.organization['name']
    end
  end

  def has_errors?
    @quest_errors.blank? && @resource_errors.blank?
  end
end
