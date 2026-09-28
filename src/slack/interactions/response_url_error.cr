# Raised when a `response_url` answers a post with a non-2xx status, for
# example after the URL expires or after its five uses. The message carries
# only the status: the URL is a credential and the body is not read.
class Slack::Interactions::ResponseUrlError < Exception
  getter http_status : Int32

  def initialize(@http_status : Int32)
    super("response_url post failed with HTTP #{@http_status}")
  end
end
