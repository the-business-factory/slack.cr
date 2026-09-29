require "uri"

module Slack::Api
  # Changes a user group. Slack changes only the fields that the request sends.
  # See https://docs.slack.dev/reference/methods/usergroups.update.
  #
  # The fields are the same as in `UsergroupsCreate`. *enable_section* is sent
  # when supplied, so `false` removes the sidebar section and nil keeps it.
  # A section needs default channels; Slack checks the group's current channels.
  struct UsergroupsUpdate < Request(Models::Usergroups::UsergroupResponse)
    include FormBody
    include UsergroupFields

    @channels : Array(String)?
    @additional_channels : Array(String)?

    getter usergroup : String
    getter name : String?
    getter enable_section : Bool?

    def initialize(@usergroup : String, *, @name : String? = nil, channels : Enumerable(String)? = nil,
                   additional_channels : Enumerable(String)? = nil, @description : String? = nil,
                   @handle : String? = nil, @include_count : Bool = false, @team_id : String? = nil,
                   @enable_section : Bool? = nil)
      # Copy once: Array#to_a returns the caller's array itself.
      @channels = channels.try(&.map(&.itself))
      @additional_channels = additional_channels.try(&.map(&.itself))
    end

    def method_path : String
      "usergroups.update"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      FieldChecks.blank_issue(issues, "usergroups", "name", @name, "Name")
      issues.concat(channel_issues)
    end

    def form : URI::Params
      form = URI::Params{"usergroup" => @usergroup}
      @name.try { |name| form.add "name", name }
      group_fields(form)
      @enable_section.try { |enabled| form.add "enable_section", enabled.to_s }
      form
    end
  end
end
