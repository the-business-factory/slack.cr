require "json"
require "uri"

module Slack::Api
  # Where and how `files.completeUploadExternal` shares completed files.
  # See https://docs.slack.dev/reference/methods/files.completeUploadExternal.
  #
  # Without `channel_id` or `channels`, the files stay private. Slack ignores
  # `blocks` when `initial_comment` is present and uses `icon_emoji` instead of
  # `icon_url`; as library policy, each pair is rejected. Only the blocks of
  # *blocks* are sent, not its fallback text.
  struct FileShare
    CHANNELS_MAX_SIZE = 100

    getter channel_id : String?
    getter thread_ts : String?
    getter initial_comment : String?
    getter username : String?
    getter icon_url : String?
    getter icon_emoji : String?
    @channels : Array(String)?
    @blocks : UI::Message?

    def initialize(*, @channel_id : String? = nil, channels : Enumerable(String)? = nil,
                   @thread_ts : String? = nil, @initial_comment : String? = nil, blocks : UI::Message? = nil,
                   @username : String? = nil, @icon_url : String? = nil, @icon_emoji : String? = nil)
      # `Array#to_a` returns self; `map` always makes an owned copy.
      @channels = channels.try(&.map(&.itself))
      @blocks = blocks.try(&.snapshot)
    end

    def channels : Array(String)?
      @channels.try(&.dup)
    end

    def blocks : UI::Message?
      @blocks.try(&.snapshot)
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      channels = @channels
      if channels && channels.size > CHANNELS_MAX_SIZE
        issues << issue("channels.too_many", "channels", "Channels must contain at most 100 IDs.")
      end
      if @channel_id && channels
        # Slack does not document how the two fields combine.
        issues << issue("channel.conflict", "channel_id", "Set channel_id or channels, not both.")
      end
      thread_issues(issues)
      if @icon_url && @icon_emoji
        issues << issue("icon.conflict", "icon_url", "Set icon_url or icon_emoji, not both.")
      end
      blocks_issues(issues)
      issues
    end

    # Adds the share fields to *form*. `channels` is comma-separated and
    # `blocks` is JSON text, as the method reference describes.
    def add_to(form : URI::Params) : Nil
      @channel_id.try { |value| form.add "channel_id", value }
      @channels.try { |value| form.add "channels", value.join(',') }
      @thread_ts.try { |value| form.add "thread_ts", value }
      @initial_comment.try { |value| form.add "initial_comment", value }
      @blocks.try { |message| form.add "blocks", JSON.build { |json| message.blocks_to_json(json) } }
      @username.try { |value| form.add "username", value }
      @icon_url.try { |value| form.add "icon_url", value }
      @icon_emoji.try { |value| form.add "icon_emoji", value }
    end

    private def thread_issues(issues : Array(UI::ValidationIssue)) : Nil
      timestamp = @thread_ts
      return unless timestamp

      FieldChecks.timestamp_issue(issues, "file_share", "thread_ts", timestamp, "Thread timestamp")
      unless channel_count == 1
        issues << issue("thread_ts.single_channel_required", "thread_ts",
          "A thread reply must be shared to exactly one channel.")
      end
    end

    private def blocks_issues(issues : Array(UI::ValidationIssue)) : Nil
      message = @blocks
      return unless message

      if @initial_comment
        issues << issue("blocks.with_initial_comment", "blocks",
          "Set initial_comment or blocks, not both. Slack ignores blocks with an initial comment.")
      end
      issues.concat(message.validate.map(&.at("blocks")))
    end

    private def channel_count : Int32
      (@channel_id ? 1 : 0) + (@channels.try(&.size) || 0)
    end

    private def issue(code : String, path : String, message : String) : UI::ValidationIssue
      UI::ValidationIssue.new("file_share.#{code}", path, message)
    end
  end
end
