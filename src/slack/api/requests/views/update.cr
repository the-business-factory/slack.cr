# Replaces an open modal with a copied view. See https://docs.slack.dev/reference/methods/views.update.
struct Slack::Api::ViewsUpdate < Slack::Api::Request(Slack::Models::ViewsUpdate)
  include Slack::Api::JsonBody

  @snapshot : Slack::UI::Modal

  getter view_id : String?
  getter external_id : String?
  getter hash : String?

  def initialize(
    view : Slack::UI::Modal,
    @hash : String? = nil,
    *,
    @view_id : String? = nil,
    @external_id : String? = nil,
  )
    @snapshot = view.snapshot
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @snapshot.validate.map(&.at("view"))
    # Exactly one explicit selector is library policy; nested external_id is metadata.
    if @view_id.nil? && @external_id.nil?
      issues << Slack::UI::ValidationIssue.new(
        "views_update.target.required", "view_id", "Supply a view_id or external_id target.")
    elsif !@view_id.nil? && !@external_id.nil?
      issues << Slack::UI::ValidationIssue.new(
        "views_update.target.ambiguous", "external_id", "Supply only one target selector.")
    end
    Slack::Api::FieldChecks.blank_issue(issues, "views_update", "view_id", @view_id, "View ID")
    if external_id = @external_id
      if external_id.blank?
        issues << Slack::UI::ValidationIssue.new(
          "views_update.external_id.blank", "external_id", "External ID must not be blank.")
      elsif external_id.size > 255
        issues << Slack::UI::ValidationIssue.new(
          "views_update.external_id.too_long", "external_id", "External ID cannot exceed 255 characters.")
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "view_id", @view_id if @view_id
      json.field "external_id", @external_id if @external_id
      json.field "view", @snapshot
      json.field "hash", @hash if @hash
    end
  end

  def method_path : String
    "views.update"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier4
  end
end
