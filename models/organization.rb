class Organization
  attr_accessor :quest_errors, :resource_errors

  def initialize
    @quest_errors = []
    @resource_errors = []
  end

  # Hacky, but :shrug:
  def id
    return unless (error = @quest_errors.first || @resource_errors.first)

    error.organization['id']
  end

  def name
    return unless (error = @quest_errors.first || @resource_errors.first)

    error.organization['name']
  end
end
