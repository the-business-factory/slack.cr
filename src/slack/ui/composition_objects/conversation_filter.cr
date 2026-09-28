# Restricts the Slack-provided list for conversation select menus.
struct Slack::UI::CompositionObjects::ConversationFilter
  include Slack::UI::ValueValidation

  @include : Array(String)?
  getter exclude_external_shared_channels : Bool?
  getter exclude_bot_users : Bool?

  def initialize(
    *,
    include included_types : Enumerable(T)? = nil,
    @exclude_external_shared_channels : Bool? = nil,
    @exclude_bot_users : Bool? = nil,
  ) forall T
    @include = if included_types
                 copied = [] of String
                 included_types.each { |kind| copied << kind }
                 copied
               end
    validate!
  end

  def include : Array(String)?
    @include.try(&.dup)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @include.nil? && @exclude_external_shared_channels.nil? && @exclude_bot_users.nil?
      issues << Slack::UI::ValidationIssue.new("conversation_filter.empty", "", "Supply at least one filter field.")
    end
    if kinds = @include
      if kinds.empty?
        issues << Slack::UI::ValidationIssue.new("conversation_filter.include.empty", "include", "Include must contain at least one conversation type.")
      end
      kinds.each_with_index do |kind, index|
        unless {"im", "mpim", "private", "public"}.includes?(kind)
          issues << Slack::UI::ValidationIssue.new("conversation_filter.include.invalid", "include[#{index}]", "Expected im, mpim, private, or public.")
        end
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "include", @include if @include
      json.field "exclude_external_shared_channels", @exclude_external_shared_channels unless @exclude_external_shared_channels.nil?
      json.field "exclude_bot_users", @exclude_bot_users unless @exclude_bot_users.nil?
    end
  end
end
