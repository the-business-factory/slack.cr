alias Slack::Interactions::StateValue = Slack::Interactions::PlainTextValue | Slack::Interactions::StaticSelectValue | Slack::Interactions::MultiStaticSelectValue | Slack::Interactions::UnknownStateValue

# Reads state.values by stable block and action IDs without imposing outbound rules.
struct Slack::Interactions::StateMap
  getter raw : JSON::Any?

  def initialize(@raw : JSON::Any? = nil, @path : String = "state")
  end

  def presence : ValuePresence
    ValuePresence.of(@raw)
  end

  def values_presence : ValuePresence
    ValuePresence.of(values_raw)
  end

  def []?(block_id : String, action_id : String) : StateValue?
    values = PayloadAccess.object?(values_raw, "#{@path}.values")
    block = PayloadAccess.object?(values.try(&.[block_id]?), "#{@path}.values[#{block_id.inspect}]")
    item = block.try(&.[action_id]?)
    return unless item
    path = entry_path(block_id, action_id)
    object = PayloadAccess.object?(item, path)
    type = PayloadAccess.string?(object.try(&.["type"]?), "#{path}.type")
    case type
    when "plain_text_input"
      PlainTextValue.new(item, path)
    when "static_select"
      StaticSelectValue.new(item, path)
    when "multi_static_select"
      MultiStaticSelectValue.new(item, path)
    else
      UnknownStateValue.new(type, item)
    end
  end

  def plain_text_value?(block_id : String, action_id : String) : PlainTextValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil            then nil
    when PlainTextValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "plain_text_input", entry.type || "null or untyped state value")
    end
  end

  def static_select_value?(block_id : String, action_id : String) : StaticSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil               then nil
    when StaticSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "static_select", entry.type || "null or untyped state value")
    end
  end

  def multi_static_select_value?(block_id : String, action_id : String) : MultiStaticSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                    then nil
    when MultiStaticSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "multi_static_select", entry.type || "null or untyped state value")
    end
  end

  def plain_text?(block_id : String, action_id : String) : String?
    plain_text_value?(block_id, action_id).try(&.value)
  end

  private def values_raw : JSON::Any?
    PayloadAccess.object?(@raw, @path).try(&.["values"]?)
  end

  private def entry_path(block_id : String, action_id : String) : String
    "#{@path}.values[#{block_id.inspect}][#{action_id.inspect}]"
  end
end
