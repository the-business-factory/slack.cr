# Publishes a copied Home view. See https://docs.slack.dev/reference/methods/views.publish.
struct Slack::Api::ViewsPublish < Slack::Api::Request(Slack::Models::ViewsPublish)
  include Slack::Api::JsonBody

  @snapshot : Slack::UI::Home

  getter user_id : String
  getter hash : String?
  getter interactivity_pointer : String?

  def initialize(
    @user_id : String,
    view : Slack::UI::Home,
    @hash : String? = nil,
    @interactivity_pointer : String? = nil,
  )
    @snapshot = view.snapshot
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @snapshot.validate.map(&.at("view"))
    if @user_id.empty?
      issues << Slack::UI::ValidationIssue.new("views_publish.user_id.empty", "user_id", "User ID must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "user_id", @user_id
      json.field "view", @snapshot
      json.field "hash", @hash if @hash
      json.field "interactivity_pointer", @interactivity_pointer if @interactivity_pointer
    end
  end

  def method_path : String
    "views.publish"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier4
  end
end
