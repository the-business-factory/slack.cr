require "uri"

module Slack::Api
  # Changes the title, link, or emoji of a bookmark. Slack keeps the fields
  # that the request does not send.
  # See https://docs.slack.dev/reference/methods/bookmarks.edit.
  #
  # ```
  # Slack::Api::BookmarksEdit.new("C123", "Bk123", title: "Runbook v2")
  # ```
  struct BookmarksEdit < Request(Models::Bookmarks::BookmarkResponse)
    include FormBody

    getter channel_id : String
    getter bookmark_id : String
    getter title : String?
    getter link : String?
    getter emoji : String?

    def initialize(@channel_id : String, @bookmark_id : String, *, @title : String? = nil,
                   @link : String? = nil, @emoji : String? = nil)
    end

    def method_path : String
      "bookmarks.edit"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @title.nil? && @link.nil? && @emoji.nil?
        issues << UI::ValidationIssue.new("bookmarks_edit.changes.empty", "title",
          "Supply a title, link, or emoji to change.")
      end
      if @title.try(&.empty?)
        issues << UI::ValidationIssue.new("bookmarks.title.empty", "title", "Bookmark title must not be empty.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params{"channel_id" => @channel_id, "bookmark_id" => @bookmark_id}
      @title.try { |title| form.add "title", title }
      @link.try { |link| form.add "link", link }
      @emoji.try { |emoji| form.add "emoji", emoji }
      form
    end
  end
end
