struct Slack::EventData::Attachment
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer \
    fallback : String,
    from_url : String? = nil,
    id : Int16,
    original_url : String? = nil,
    service_icon : String? = nil,
    service_name : String? = nil,
    service_url : String? = nil,
    text : String? = nil,
    thumb_height : Int64? = nil,
    thumb_url : String? = nil,
    thumb_width : Int64? = nil,
    title : String? = nil,
    title_link : String? = nil,
    video_html : String? = nil,
    video_html_height : Int64? = nil,
    video_html_width : Int64? = nil
end
