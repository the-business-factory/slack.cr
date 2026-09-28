require "uri"

module Slack::Api
  # Adds a link bookmark to a channel.
  # See https://docs.slack.dev/reference/methods/bookmarks.add.
  #
  # Slack documents only the `link` bookmark type, so the request always sends
  # `type=link`; `entity_id`, which applies only to message and file types, is
  # not sent. *parent_id* puts the bookmark in a bookmark folder. Slack
  # checks the link and the emoji (`invalid_link`, `invalid_emoji`).
  #
  # ```
  # Slack::Api::BookmarksAdd.new("C123", "Runbook", "https://example.com/runbook", emoji: ":books:")
  # ```
  struct BookmarksAdd < Request(Models::Bookmarks::BookmarkResponse)
    include FormBody

    getter channel_id : String
    getter title : String
    getter link : String
    getter emoji : String?
    getter parent_id : String?

    def initialize(@channel_id : String, @title : String, @link : String, *, @emoji : String? = nil,
                   @parent_id : String? = nil)
    end

    def method_path : String
      "bookmarks.add"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @title.empty?
        issues << UI::ValidationIssue.new("bookmarks.title.empty", "title", "Bookmark title must not be empty.")
      end
      if @link.empty?
        issues << UI::ValidationIssue.new("bookmarks_add.link.empty", "link", "Bookmark link must not be empty.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params{"channel_id" => @channel_id, "title" => @title, "type" => "link", "link" => @link}
      @emoji.try { |emoji| form.add "emoji", emoji }
      @parent_id.try { |parent_id| form.add "parent_id", parent_id }
      form
    end
  end
end
