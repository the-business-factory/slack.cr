class Slack::UrlVerification
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer challenge : String, token : String, type : String

  def response
    {challenge: challenge}
  end
end
