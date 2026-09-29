# Adds custom previews to links that users post or compose.
# See https://docs.slack.dev/reference/methods/chat.unfurl.
#
# Identify the links by the posted message (*channel* and *ts*), or by the
# `unfurl_id` and `source` of a `link_shared` event. *unfurls* maps each URL to a
# `UI::Unfurl` (blocks) or a `UI::Attachment`. The `user_auth_*` fields ask the
# user to connect an account before the app shows full previews.
#
# ```
# unfurl = Slack::UI::Unfurl.new(blocks: [Slack::UI::Blocks::Section.new(text: Slack::UI.mrkdwn("*Issue 7*"))])
# client.call(Slack::Api::ChatUnfurl.new(channel: "C123", ts: "1710000000.000100",
#   unfurls: {"https://example.com/issues/7" => unfurl}))
# ```
struct Slack::Api::ChatUnfurl < Slack::Api::Request(Slack::Models::DefaultResponse)
  include Slack::Api::JsonBody

  alias Value = Slack::UI::Unfurl | Slack::UI::Attachment

  # Where the link is: in the message composer, or in a posted message.
  enum Source
    Composer
    ConversationsHistory

    def wire_value : String
      case self
      in .composer?              then "composer"
      in .conversations_history? then "conversations_history"
      end
    end
  end

  @unfurls : Hash(String, Value)?
  @user_auth_blocks : Slack::UI::Message?

  getter channel : String?
  getter ts : String?
  getter unfurl_id : String?
  getter source : Source?
  getter user_auth_required : Bool?
  getter user_auth_message : String?
  getter user_auth_url : String?

  # Unfurls links in the posted message at *channel* and *ts*.
  def initialize(*, channel : String, ts : String, unfurls : Hash(String, T)? = nil,
                 @user_auth_required : Bool? = nil, @user_auth_message : String? = nil,
                 @user_auth_url : String? = nil, user_auth_blocks : Enumerable(B)? = nil) forall T, B
    @channel = channel
    @ts = ts
    @unfurls = copy_unfurls(unfurls)
    @user_auth_blocks = user_auth_blocks.try { |blocks| Slack::UI::Message.with_slack_generated_fallback(blocks) }
  end

  # Unfurls the link that a `link_shared` event identifies by *unfurl_id* and *source*.
  def initialize(*, unfurl_id : String, source : Source, unfurls : Hash(String, T)? = nil,
                 @user_auth_required : Bool? = nil, @user_auth_message : String? = nil,
                 @user_auth_url : String? = nil, user_auth_blocks : Enumerable(B)? = nil) forall T, B
    @unfurl_id = unfurl_id
    @source = source
    @unfurls = copy_unfurls(unfurls)
    @user_auth_blocks = user_auth_blocks.try { |blocks| Slack::UI::Message.with_slack_generated_fallback(blocks) }
  end

  def unfurls : Hash(String, Value)?
    @unfurls.try(&.dup)
  end

  def user_auth_blocks : Array(Slack::UI::MessageBlock)?
    @user_auth_blocks.try(&.blocks)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    Slack::Api::FieldChecks.blank_issue(issues, "chat_unfurl", "channel", @channel, "Channel")
    Slack::Api::FieldChecks.timestamp_issue(issues, "chat_unfurl", "ts", @ts)
    Slack::Api::FieldChecks.blank_issue(issues, "chat_unfurl", "unfurl_id", @unfurl_id, "Unfurl ID")
    unfurl_issues(issues)
    Slack::Api::FieldChecks.blank_issue(issues, "chat_unfurl", "user_auth_message", @user_auth_message, "User auth message")
    Slack::Api::FieldChecks.blank_issue(issues, "chat_unfurl", "user_auth_url", @user_auth_url, "User auth URL")
    @user_auth_blocks.try { |message| issues.concat(message.validate.map(&.at("user_auth_blocks"))) }
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel if @channel
      json.field "ts", @ts if @ts
      json.field "unfurl_id", @unfurl_id if @unfurl_id
      if source = @source
        json.field "source", source.wire_value
      end
      json.field "unfurls", @unfurls if @unfurls
      json.field "user_auth_required", @user_auth_required unless @user_auth_required.nil?
      json.field "user_auth_message", @user_auth_message if @user_auth_message
      json.field "user_auth_url", @user_auth_url if @user_auth_url
      if blocks = @user_auth_blocks
        json.field("user_auth_blocks") { blocks.blocks_to_json(json) }
      end
    end
  end

  def method_path : String
    "chat.unfurl"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier3
  end

  # Copies the map once. A value that is not an unfurl or an attachment does not compile.
  private def copy_unfurls(unfurls : Hash(String, T)?) : Hash(String, Value)? forall T
    unfurls.try &.each_with_object({} of String => Value) { |(url, value), copy| copy[url] = value }
  end

  private def unfurl_issues(issues : Array(Slack::UI::ValidationIssue)) : Nil
    @unfurls.try &.each do |url, value|
      if url.blank?
        issues << Slack::UI::ValidationIssue.new("chat_unfurl.unfurls.url_blank", "unfurls", "Unfurl URLs must not be blank.")
      end
      issues.concat(value.validate.map(&.at("unfurls[#{url}]")))
    end
  end
end
