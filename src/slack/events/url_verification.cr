class Slack::UrlVerification
  include JSON::Serializable

  property challenge : String, token : String, type : String

  def response
    {challenge: challenge}
  end
end
