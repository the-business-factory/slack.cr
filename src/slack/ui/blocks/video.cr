require "uri"

# Embedded video display block. Slack also requires the `links.embed:write`
# scope, a `video_url` on a configured unfurl domain, and an embeddable,
# reachable page; only Slack can check those.
struct Slack::UI::Blocks::Video
  include Slack::UI::ValueValidation

  # Slack requires fewer than 200 and fewer than 50 characters.
  TEXT_MAX_LENGTH        = 199
  AUTHOR_NAME_MAX_LENGTH =  49

  getter alt_text : String
  getter title : Slack::UI::CompositionObjects::PlainText
  getter thumbnail_url : String
  getter video_url : String
  getter title_url : String?
  getter description : Slack::UI::CompositionObjects::PlainText?
  getter author_name : String?
  getter provider_name : String?
  getter provider_icon_url : String?
  getter block_id : String?

  def initialize(
    *,
    @alt_text : String,
    @title : Slack::UI::CompositionObjects::PlainText,
    @thumbnail_url : String,
    @video_url : String,
    @title_url : String? = nil,
    @description : Slack::UI::CompositionObjects::PlainText? = nil,
    @author_name : String? = nil,
    @provider_name : String? = nil,
    @provider_icon_url : String? = nil,
    @block_id : String? = nil,
  )
    validate!
  end

  def type : String
    "video"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @alt_text.empty?
      issues << Slack::UI::ValidationIssue.new("video.alt_text.empty", "alt_text", "Provide a plain-text summary of the video.")
    end
    if @thumbnail_url.empty?
      issues << Slack::UI::ValidationIssue.new("video.thumbnail_url.empty", "thumbnail_url", "Thumbnail URL must not be empty.")
    end
    https_issue(issues, @video_url, "video_url")
    if title_url = @title_url
      https_issue(issues, title_url, "title_url")
    end
    text_issues(issues, @title, "title")
    if description = @description
      text_issues(issues, description, "description")
    end
    length_issue(issues, @author_name, AUTHOR_NAME_MAX_LENGTH, "video.author_name.too_long", "author_name")
    length_issue(issues, @block_id, 255, "video.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "alt_text", @alt_text
      json.field "title", @title
      json.field "title_url", @title_url if @title_url
      json.field "description", @description if @description
      json.field "thumbnail_url", @thumbnail_url
      json.field "video_url", @video_url
      json.field "author_name", @author_name if @author_name
      json.field "provider_name", @provider_name if @provider_name
      json.field "provider_icon_url", @provider_icon_url if @provider_icon_url
      json.field "block_id", @block_id if @block_id
    end
  end

  # Slack documents HTTPS for the embedded and title links.
  private def https_issue(issues : Array(Slack::UI::ValidationIssue), url : String, path : String) : Nil
    return if https_url?(url)
    issues << Slack::UI::ValidationIssue.new("video.#{path}.not_https", path, "URL must be an absolute HTTPS URL.")
  end

  private def https_url?(url : String) : Bool
    uri = URI.parse(url)
    uri.scheme.try(&.downcase) == "https" && !uri.host.to_s.empty?
  rescue URI::Error
    false
  end

  private def text_issues(issues : Array(Slack::UI::ValidationIssue), text : Slack::UI::CompositionObjects::PlainText, path : String) : Nil
    text.validate.each { |issue| issues << issue.at(path) }
    length_issue(issues, text.text, TEXT_MAX_LENGTH, "video.#{path}.too_long", "#{path}.text")
  end
end
