struct Slack::EventData::Attachment
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer \
    fallback : String,
    from_url : String?,
    id : Int16,
    original_url : String?,
    service_icon : String?,
    service_name : String?,
    service_url : String?,
    text : String?,
    thumb_height : Int64?,
    thumb_url : String?,
    thumb_width : Int64?,
    title : String,
    title_link : String?,
    video_html : String?,
    video_html_height : Int64?,
    video_html_width : Int64?
end
