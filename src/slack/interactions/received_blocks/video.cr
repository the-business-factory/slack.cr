# A received `video` block.
# https://docs.slack.dev/reference/block-kit/blocks/video-block/
struct Slack::Interactions::ReceivedBlocks::Video
  getter raw : JSON::Any
  getter block_id : String?
  getter alt_text : String
  getter title : ReceivedText
  getter video_url : String
  getter thumbnail_url : String
  getter title_url : String?
  getter description : ReceivedText?
  getter author_name : String?
  getter provider_name : String?
  getter provider_icon_url : String?

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @alt_text = Decoder.string(object, "alt_text", path)
    @title = Decoder.text(object, "title", path)
    @video_url = Decoder.string(object, "video_url", path)
    @thumbnail_url = Decoder.string(object, "thumbnail_url", path)
    @title_url = Decoder.string?(object, "title_url", path)
    @description = Decoder.text?(object, "description", path)
    @author_name = Decoder.string?(object, "author_name", path)
    @provider_name = Decoder.string?(object, "provider_name", path)
    @provider_icon_url = Decoder.string?(object, "provider_icon_url", path)
  end
end
