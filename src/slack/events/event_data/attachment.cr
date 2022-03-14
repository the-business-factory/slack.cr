struct Slack::EventData::Attachment
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer id : Int16,
    original_url : String?,
    service_icon : String?,
    service_name : String?,
    text : String,
    title : String,
    title_link : String?,
    fallback : String
end
