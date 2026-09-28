# Content in a card: an optional hero image, icon, texts, and up to three
# buttons. Slack shows cards in messages, modals, and Home tabs, and as the
# only child of a `Carousel`.
#
# Slack sends `actions` as a plain array of buttons. The reference names an
# Actions block type for this field, but all of its examples send an array.
struct Slack::UI::Blocks::Card
  include Slack::UI::ValueValidation

  # Slack renders `icon` and `slack_icon` in the same place and accepts only
  # one of them, so one value selects the wire field.
  alias Icon = Slack::UI::BlockElements::Image | Slack::UI::CompositionObjects::SlackIcon

  TITLE_MAX_LENGTH    =  150
  BODY_MAX_LENGTH     =  200
  ALT_TEXT_MAX_LENGTH = 2000
  ACTIONS_MAX_SIZE    =    3

  getter hero_image : Slack::UI::BlockElements::Image?
  getter icon : Icon?
  getter title : Slack::UI::CompositionObjects::Text?
  getter subtitle : Slack::UI::CompositionObjects::Text?
  getter body : Slack::UI::CompositionObjects::Text?
  getter subtext : Slack::UI::CompositionObjects::Text?
  getter block_id : String?
  @actions : Array(Slack::UI::BlockElements::Button)?

  def initialize(
    *,
    @hero_image : Slack::UI::BlockElements::Image? = nil,
    @icon : Icon? = nil,
    @title : Slack::UI::CompositionObjects::Text? = nil,
    @subtitle : Slack::UI::CompositionObjects::Text? = nil,
    @body : Slack::UI::CompositionObjects::Text? = nil,
    @subtext : Slack::UI::CompositionObjects::Text? = nil,
    actions : Enumerable(T)? = nil,
    @block_id : String? = nil,
  ) forall T
    @actions = if actions
                 copied = [] of Slack::UI::BlockElements::Button
                 actions.each { |button| append_button(copied, button) }
                 copied
               end
    validate!
  end

  def type : String
    "card"
  end

  def actions : Array(Slack::UI::BlockElements::Button)?
    @actions.try(&.dup)
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    unless @hero_image || @title || @actions || @body
      issues << ValidationIssue.new("card.content.missing", "", "A card needs a hero_image, title, actions, or body.")
    end
    image_issues(issues, @hero_image, "hero_image")
    icon = @icon
    image_issues(issues, icon, "icon") if icon.is_a?(Slack::UI::BlockElements::Image)
    text_issues(issues, @title, TITLE_MAX_LENGTH, "title")
    text_issues(issues, @subtitle, TITLE_MAX_LENGTH, "subtitle")
    text_issues(issues, @body, BODY_MAX_LENGTH, "body")
    text_issues(issues, @subtext, BODY_MAX_LENGTH, "subtext")
    if actions = @actions
      action_issues(issues, actions)
    end
    length_issue(issues, @block_id, 255, "card.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "hero_image", @hero_image if @hero_image
      case icon = @icon
      when Slack::UI::BlockElements::Image
        json.field "icon", icon
      when Slack::UI::CompositionObjects::SlackIcon
        json.field "slack_icon", icon
      end
      json.field "title", @title if @title
      json.field "subtitle", @subtitle if @subtitle
      json.field "body", @body if @body
      json.field "subtext", @subtext if @subtext
      json.field "actions", @actions if @actions
    end
  end

  # The 2000-character alt text limit is specific to card images.
  private def image_issues(issues : Array(ValidationIssue), image : Slack::UI::BlockElements::Image?, path : String) : Nil
    return unless image

    image.validate.each { |issue| issues << issue.at(path) }
    length_issue(issues, image.alt_text, ALT_TEXT_MAX_LENGTH, "card.#{path}.alt_text.too_long", "#{path}.alt_text")
  end

  private def text_issues(issues : Array(ValidationIssue), text : Slack::UI::CompositionObjects::Text?, maximum : Int32, path : String) : Nil
    return unless text

    text.validate.each { |issue| issues << issue.at(path) }
    length_issue(issues, text.text, maximum, "card.#{path}.too_long", "#{path}.text")
  end

  # An empty array is library policy: omit `actions` for a card without buttons.
  private def action_issues(issues : Array(ValidationIssue), actions : Array(Slack::UI::BlockElements::Button)) : Nil
    if actions.empty?
      issues << ValidationIssue.new("card.actions.empty", "actions", "Omit actions instead of sending an empty list.")
    elsif actions.size > ACTIONS_MAX_SIZE
      issues << ValidationIssue.new("card.actions.too_many", "actions", "A card cannot contain more than #{ACTIONS_MAX_SIZE} buttons.")
    end
    action_ids = Set(String).new
    actions.each_with_index do |button, index|
      button.validate.each { |issue| issues << issue.at("actions[#{index}]") }
      action_id = button.action_id
      next unless action_id
      next if action_ids.add?(action_id)

      issues << ValidationIssue.new("card.action_id.duplicate", "actions[#{index}].action_id", "Action IDs must be unique within a card.")
    end
  end

  private def append_button(buttons : Array(Slack::UI::BlockElements::Button), button : Slack::UI::BlockElements::Button) : Nil
    buttons << button
  end
end
