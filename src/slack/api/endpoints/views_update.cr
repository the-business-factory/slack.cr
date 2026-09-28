# Updates an owned modal snapshot through the existing API transport.
class Slack::Api::ViewsUpdate
  @snapshot : Slack::UI::Modal
  @result : HTTP::Client::Response?

  getter view_id : String?
  getter external_id : String?
  getter hash : String?

  def initialize(
    @token : String,
    view : Slack::UI::Modal,
    @hash : String? = nil,
    *,
    @view_id : String? = nil,
    @external_id : String? = nil,
    @configuration : Slack::Auth::APIConfiguration = Slack.settings.api_configuration,
    @transport : Slack::Auth::Transport? = nil,
    @limiter : RateLimiter::LimiterLike? = nil,
  )
    @snapshot = view.snapshot
    @result = nil
  end

  def self.from_json(source : String | IO) : NoReturn
    {% raise "request deserialization is unsupported" %}
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
    if view_id = @view_id
      if view_id.blank?
        issues << Slack::UI::ValidationIssue.new(
          "views_update.view_id.blank", "view_id", "View ID must not be blank.")
      end
    end
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

  def validate! : Nil
    issues = validate
    raise Slack::UI::ValidationError.new(issues) unless issues.empty?
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

  def result : HTTP::Client::Response
    validate!
    @result ||= begin
      descriptor = JsonBodyRequest(Slack::Models::ViewsUpdate).new(
        token: @token, method_path: "views.update", body: to_json,
        configuration: @configuration, transport: @transport, limiter: @limiter
      )
      descriptor.result
    end
  end

  def call : Slack::Models::ViewsUpdate
    validate!
    Slack::Api::ResponseHandler(Slack::Models::ViewsUpdate).from_json(result.body)
  end
end
