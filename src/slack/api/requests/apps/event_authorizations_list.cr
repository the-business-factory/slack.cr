require "uri"

module Slack::Api
  # Reads one page of the installations that can see an event. Requires an
  # app-level token (`xapp-`) with `authorizations:read`.
  # See https://docs.slack.dev/reference/methods/apps.event.authorizations.list.
  #
  # `event_context` comes from the Events API envelope.
  struct AppsEventAuthorizationsList < Request(Models::Apps::EventAuthorizationsList)
    include FormBody
    include Paginated

    getter event_context : String
    getter cursor : String?
    getter limit : Int32?

    def initialize(@event_context : String, *, @cursor : String? = nil, @limit : Int32? = nil)
    end

    def method_path : String
      "apps.event.authorizations.list"
    end

    # Slack documents a special limit of 600 calls per minute for each app and team.
    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def validate : Array(UI::ValidationIssue)
      page_issues
    end

    def form : URI::Params
      form = URI::Params{"event_context" => @event_context}
      page_fields(form)
      form
    end
  end
end
