require "uri"

# Reads one page of the messages that are scheduled to post.
# See https://docs.slack.dev/reference/methods/chat.scheduledMessages.list.
#
# Give *channel* to read one conversation, and *oldest* and *latest* to limit
# the time range. Org-level tokens need *team_id*. Use `Client#each_page` to
# read every page.
struct Slack::Api::ChatScheduledMessagesList < Slack::Api::Request(Slack::Models::Chat::ScheduledMessagesList)
  include Slack::Api::FormBody
  include Slack::Api::Paginated

  getter channel : String?
  getter latest : Time?
  getter oldest : Time?
  getter team_id : String?
  getter cursor : String?
  getter limit : Int32?

  def initialize(*, @channel : String? = nil, @latest : Time? = nil, @oldest : Time? = nil,
                 @team_id : String? = nil, @cursor : String? = nil, @limit : Int32? = nil)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    page_issues
  end

  def form : URI::Params
    form = URI::Params.new
    @channel.try { |value| form.add "channel", value }
    @latest.try { |value| form.add "latest", value.to_unix.to_s }
    @oldest.try { |value| form.add "oldest", value.to_unix.to_s }
    @team_id.try { |value| form.add "team_id", value }
    page_fields(form)
    form
  end

  def method_path : String
    "chat.scheduledMessages.list"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier3
  end
end
