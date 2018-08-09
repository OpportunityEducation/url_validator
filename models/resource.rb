class Resource
  attr_accessor :klass, :id, :name, :attribute

  def initialize(attributes = {})
    attributes.each do |k, v|
      k = :klass if k =~ /class/

      public_send("#{k}=", v.is_a?(String) ? v.strip : v)
    end
  end
end
