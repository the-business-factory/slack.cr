require "uri"

module Slack::Api
  # Reserves an upload URL and file ID for one file of *length* bytes.
  # See https://docs.slack.dev/reference/methods/files.getUploadURLExternal.
  struct FilesGetUploadURLExternal < Request(Models::Files::UploadURL)
    include FormBody

    ALT_TXT_MAX_SIZE = 1000

    getter filename : String
    getter length : Int64
    getter alt_txt : String?
    getter snippet_type : String?

    def initialize(@filename : String, length : Int, @alt_txt : String? = nil, @snippet_type : String? = nil)
      @length = length.to_i64
    end

    def method_path : String
      "files.getUploadURLExternal"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @filename.empty?
        issues << issue("filename.empty", "filename", "Filename must not be empty.")
      end
      if @length.negative?
        issues << issue("length.negative", "length", "Length must not be negative.")
      end
      if (alt_txt = @alt_txt) && alt_txt.size > ALT_TXT_MAX_SIZE
        issues << issue("alt_txt.too_long", "alt_txt", "Alt text must be at most 1000 characters.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params{"filename" => @filename, "length" => @length.to_s}
      @alt_txt.try { |alt_txt| form.add "alt_txt", alt_txt }
      @snippet_type.try { |snippet_type| form.add "snippet_type", snippet_type }
      form
    end

    private def issue(code : String, path : String, message : String) : UI::ValidationIssue
      UI::ValidationIssue.new("files_get_upload_url_external.#{code}", path, message)
    end
  end
end
