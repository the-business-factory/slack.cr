alias Slack::Interactions::Action = Slack::Interactions::ButtonAction | Slack::Interactions::StaticSelectAction | Slack::Interactions::MultiStaticSelectAction | Slack::Interactions::UnknownAction

module Slack::Interactions::ActionDecoder
  def self.decode(raw : JSON::Any?) : Array(Action)
    actions = [] of Action
    return actions if raw.nil? || raw.raw.nil?
    items = raw.as_a? || raise TypeMismatch.new("actions", "array", raw.raw.class.to_s)
    items.each_with_index do |item, index|
      path = "actions[#{index}]"
      object = PayloadAccess.object?(item, path)
      type = PayloadAccess.string?(object.try(&.["type"]?), "#{path}.type")
      actions << case type
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
    actions
  end
end
