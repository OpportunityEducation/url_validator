class StatusService
  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.89 Safari/537.36'

  attr_reader :url

  def initialize(url)
    @url = url

    self
  end

  def self.call(url)
    new(url).call
  end

  def call
    `curl -A "#{USER_AGENT}" --connect-timeout 30 --max-time 30 -s -o /dev/null -I -w "%{http_code}" "#{url}"`.to_i
  end
end
