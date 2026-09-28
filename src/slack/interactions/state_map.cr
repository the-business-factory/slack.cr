alias Slack::Interactions::StateValue = Slack::Interactions::PlainTextValue | Slack::Interactions::StaticSelectValue | Slack::Interactions::MultiStaticSelectValue | Slack::Interactions::ExternalSelectValue | Slack::Interactions::MultiExternalSelectValue | Slack::Interactions::CheckboxesValue | Slack::Interactions::RadioButtonsValue | Slack::Interactions::UsersSelectValue | Slack::Interactions::MultiUsersSelectValue | Slack::Interactions::ConversationsSelectValue | Slack::Interactions::MultiConversationsSelectValue | Slack::Interactions::ChannelsSelectValue | Slack::Interactions::MultiChannelsSelectValue | Slack::Interactions::DatePickerValue | Slack::Interactions::TimePickerValue | Slack::Interactions::DatetimePickerValue | Slack::Interactions::NumberInputValue | Slack::Interactions::UrlInputValue | Slack::Interactions::FileInputValue | Slack::Interactions::EmailInputValue | Slack::Interactions::UnknownStateValue

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

  # Keep explicit family dispatch together rather than split the discriminator mapping.
  # ameba:disable Metrics/CyclomaticComplexity
  def []?(block_id : String, action_id : String) : StateValue?
    values = PayloadAccess.object?(values_raw, "#{@path}.values")
    block = PayloadAccess.object?(values.try(&.[block_id]?), "#{@path}.values[#{block_id.inspect}]")
    item = block.try(&.[action_id]?)
    return unless item
    path = entry_path(block_id, action_id)
    object = PayloadAccess.object?(item, path)
    type = PayloadAccess.string?(object.try(&.["type"]?), "#{path}.type")
    case type
    when "number_input"
      NumberInputValue.new(item, path)
    when "url_text_input"
      UrlInputValue.new(item, path)
    when "email_text_input"
      EmailInputValue.new(item, path)
    when "datepicker"
      DatePickerValue.new(item, path)
    when "timepicker"
      TimePickerValue.new(item, path)
    when "datetimepicker"
      DatetimePickerValue.new(item, path)
    when "file_input"
      FileInputValue.new(item, path)
    when "channels_select"
      ChannelsSelectValue.new(item, path)
    when "multi_channels_select"
      MultiChannelsSelectValue.new(item, path)
    when "conversations_select"
      ConversationsSelectValue.new(item, path)
    when "multi_conversations_select"
      MultiConversationsSelectValue.new(item, path)
    when "users_select"
      UsersSelectValue.new(item, path)
    when "multi_users_select"
      MultiUsersSelectValue.new(item, path)
    when "radio_buttons"
      RadioButtonsValue.new(item, path)
    when "checkboxes"
      CheckboxesValue.new(item, path)
    when "plain_text_input"
      PlainTextValue.new(item, path)
    when "static_select"
      StaticSelectValue.new(item, path)
    when "multi_static_select"
      MultiStaticSelectValue.new(item, path)
    when "external_select"
      ExternalSelectValue.new(item, path)
    when "multi_external_select"
      MultiExternalSelectValue.new(item, path)
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

  def radio_buttons_value?(block_id : String, action_id : String) : RadioButtonsValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil               then nil
    when RadioButtonsValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "radio_buttons", entry.type || "null or untyped state value")
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

  def external_select_value?(block_id : String, action_id : String) : ExternalSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                 then nil
    when ExternalSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "external_select", entry.type || "null or untyped state value")
    end
  end

  def multi_external_select_value?(block_id : String, action_id : String) : MultiExternalSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                      then nil
    when MultiExternalSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "multi_external_select", entry.type || "null or untyped state value")
    end
  end

  def users_select_value?(block_id : String, action_id : String) : UsersSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil              then nil
    when UsersSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "users_select", entry.type || "null or untyped state value")
    end
  end

  def multi_users_select_value?(block_id : String, action_id : String) : MultiUsersSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                   then nil
    when MultiUsersSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "multi_users_select", entry.type || "null or untyped state value")
    end
  end

  def number_input_value?(block_id : String, action_id : String) : NumberInputValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil              then nil
    when NumberInputValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "number_input", entry.type || "null or untyped state value")
    end
  end

  def url_input_value?(block_id : String, action_id : String) : UrlInputValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil           then nil
    when UrlInputValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "url_text_input", entry.type || "null or untyped state value")
    end
  end

  def email_input_value?(block_id : String, action_id : String) : EmailInputValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil             then nil
    when EmailInputValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "email_text_input", entry.type || "null or untyped state value")
    end
  end

  def date_picker_value?(block_id : String, action_id : String) : DatePickerValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil             then nil
    when DatePickerValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "datepicker", entry.type || "null or untyped state value")
    end
  end

  def time_picker_value?(block_id : String, action_id : String) : TimePickerValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil             then nil
    when TimePickerValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "timepicker", entry.type || "null or untyped state value")
    end
  end

  def datetime_picker_value?(block_id : String, action_id : String) : DatetimePickerValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                 then nil
    when DatetimePickerValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "datetimepicker", entry.type || "null or untyped state value")
    end
  end

  def file_input_value?(block_id : String, action_id : String) : FileInputValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil            then nil
    when FileInputValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "file_input", entry.type || "null or untyped state value")
    end
  end

  def channels_select_value?(block_id : String, action_id : String) : ChannelsSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                 then nil
    when ChannelsSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "channels_select", entry.type || "null or untyped state value")
    end
  end

  def multi_channels_select_value?(block_id : String, action_id : String) : MultiChannelsSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                      then nil
    when MultiChannelsSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "multi_channels_select", entry.type || "null or untyped state value")
    end
  end

  def conversations_select_value?(block_id : String, action_id : String) : ConversationsSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                      then nil
    when ConversationsSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "conversations_select", entry.type || "null or untyped state value")
    end
  end

  def multi_conversations_select_value?(block_id : String, action_id : String) : MultiConversationsSelectValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil                           then nil
    when MultiConversationsSelectValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "multi_conversations_select", entry.type || "null or untyped state value")
    end
  end

  def checkboxes_value?(block_id : String, action_id : String) : CheckboxesValue?
    entry = self[block_id, action_id]?
    case entry
    when Nil             then nil
    when CheckboxesValue then entry
    else
      raise TypeMismatch.new(entry_path(block_id, action_id), "checkboxes", entry.type || "null or untyped state value")
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
