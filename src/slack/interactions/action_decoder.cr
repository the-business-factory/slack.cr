alias Slack::Interactions::Action = Slack::Interactions::ButtonAction | Slack::Interactions::StaticSelectAction | Slack::Interactions::MultiStaticSelectAction | Slack::Interactions::OverflowAction | Slack::Interactions::CheckboxesAction | Slack::Interactions::RadioButtonsAction | Slack::Interactions::UsersSelectAction | Slack::Interactions::MultiUsersSelectAction | Slack::Interactions::ConversationsSelectAction | Slack::Interactions::MultiConversationsSelectAction | Slack::Interactions::ChannelsSelectAction | Slack::Interactions::MultiChannelsSelectAction | Slack::Interactions::UnknownAction

module Slack::Interactions::ActionDecoder
  def self.decode(raw : JSON::Any?) : Array(Action)
    actions = [] of Action
    return actions if raw.nil? || raw.raw.nil?
    items = raw.as_a? || raise TypeMismatch.new("actions", "array", raw.raw.class.to_s)
    items.each_with_index do |item, index|
      path = "actions[#{index}]"
      actions << decode_item(item, path)
    end
    actions
  end

  # Keep explicit family dispatch together rather than split the discriminator mapping.
  # ameba:disable Metrics/CyclomaticComplexity
  private def self.decode_item(item : JSON::Any, path : String) : Action
    object = PayloadAccess.object?(item, path)
    type = PayloadAccess.string?(object.try(&.["type"]?), "#{path}.type")
    case type
    when "channels_select"
      ChannelsSelectAction.new(item, path)
    when "multi_channels_select"
      MultiChannelsSelectAction.new(item, path)
    when "conversations_select"
      ConversationsSelectAction.new(item, path)
    when "multi_conversations_select"
      MultiConversationsSelectAction.new(item, path)
    when "users_select"
      UsersSelectAction.new(item, path)
    when "multi_users_select"
      MultiUsersSelectAction.new(item, path)
    when "radio_buttons"
      RadioButtonsAction.new(item, path)
    when "checkboxes"
      CheckboxesAction.new(item, path)
    when "overflow"
      OverflowAction.new(item, path)
    when "button"
      ButtonAction.new(item, path)
    when "static_select"
      StaticSelectAction.new(item, path)
    when "multi_static_select"
      MultiStaticSelectAction.new(item, path)
    else
      UnknownAction.new(type, item)
    end
  end
end
