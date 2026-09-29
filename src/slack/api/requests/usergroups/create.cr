require "uri"

module Slack::Api
  # Creates a user group. See https://docs.slack.dev/reference/methods/usergroups.create.
  #
  # *channels* are the group's default channels; *additional_channels* are
  # channels that members can add. *enable_section* shows the group as a
  # sidebar section and needs default channels. *team_id* is needed only with
  # an org-level token. Slack checks that *name* and *handle* are unique.
  struct UsergroupsCreate < Request(Models::Usergroups::UsergroupResponse)
    include FormBody
    include UsergroupFields

    @channels : Array(String)?
    @additional_channels : Array(String)?

    getter name : String
    getter? enable_section : Bool

    def initialize(@name : String, *, channels : Enumerable(String)? = nil,
                   additional_channels : Enumerable(String)? = nil, @description : String? = nil,
                   @handle : String? = nil, @include_count : Bool = false, @team_id : String? = nil,
                   @enable_section : Bool = false)
      # Copy once: Array#to_a returns the caller's array itself.
      @channels = channels.try(&.map(&.itself))
      @additional_channels = additional_channels.try(&.map(&.itself))
    end

    def method_path : String
      "usergroups.create"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      FieldChecks.blank_issue(issues, "usergroups", "name", @name, "Name")
      issues.concat(channel_issues)
      if @enable_section && @channels.nil?
        issues << UI::ValidationIssue.new("usergroups.enable_section.channels_missing", "enable_section",
          "A sidebar section needs default channels.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params{"name" => @name}
      group_fields(form)
      form.add "enable_section", "true" if @enable_section
      form
    end
  end
end
