require "../ui/validation_issue"
require "../ui/validation_error"
require "./rate_limit_tier"

module Slack::Api
  # One Web API method call. `M` is the response model that `Client#call` returns.
  #
  # A request holds only wire fields. It never holds a token, a transport, or a
  # limiter. Include `JsonBody` or `FormBody` to choose the wire encoding.
  abstract struct Request(M)
    abstract def method_path : String
    abstract def tier : RateLimitTier
    abstract def content_type : String
    abstract def encode(io : IO) : Nil

    # Local validation issues. The client sends nothing while issues remain.
    def validate : Array(UI::ValidationIssue)
      [] of UI::ValidationIssue
    end

    # Top-level boolean fields that make an `ok: false` response without `error`
    # a documented outcome. When one of them is `true`, `Client#call` returns the
    # model instead of raising. Every other `ok: false` response still raises.
    def outcome_flags : Array(String)
      [] of String
    end

    def validate! : Nil
      issues = validate
      raise UI::ValidationError.new(issues) unless issues.empty?
    end

    def body : String
      String.build { |io| encode(io) }
    end
  end
end
