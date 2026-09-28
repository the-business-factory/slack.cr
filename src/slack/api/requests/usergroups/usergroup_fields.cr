require "uri"
require "../../../ui/validation_issue"

module Slack::Api
  # :nodoc:
  # The group fields that `UsergroupsCreate` and `UsergroupsUpdate` share.
  #
  # An including request declares `@channels` and `@additional_channels` as
  # `Array(String)?`, `@description`, `@handle`, `@team_id` as `String?`, and
  # `@include_count` as `Bool`. Each request encodes its own `enable_section`.
  module UsergroupFields
    getter description : String?
    getter handle : String?
    getter team_id : String?
    getter? include_count : Bool

    def channels : Array(String)?
      @channels.dup
    end

    def additional_channels : Array(String)?
      @additional_channels.dup
    end

    # Library policy: an empty list sends an empty field, which Slack does not
    # document. Omit the argument instead.
    private def channel_issues : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      {"channels" => @channels, "additional_channels" => @additional_channels}.each do |field, ids|
        next unless ids && ids.empty?
        issues << UI::ValidationIssue.new(
          "usergroups.#{field}.empty", field, "Supply at least one channel ID, or omit #{field}.")
      end
      issues
    end

    private def group_fields(form : URI::Params) : Nil
      @channels.try { |ids| form.add "channels", ids.join(',') }
      @additional_channels.try { |ids| form.add "additional_channels", ids.join(',') }
      @description.try { |description| form.add "description", description }
      @handle.try { |handle| form.add "handle", handle }
      form.add "include_count", "true" if @include_count
      @team_id.try { |team_id| form.add "team_id", team_id }
    end
  end
end
