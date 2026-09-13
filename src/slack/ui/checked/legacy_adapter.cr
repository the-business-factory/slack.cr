module Slack::UI::Checked::LegacyAdapter
  alias CheckedText = Slack::UI::Checked::CompositionObjects::Text
  alias LegacySection = Slack::UI::Blocks::Section

  def self.section(source : LegacySection) : Slack::UI::Checked::Blocks::Section
    issues = [] of Slack::UI::Checked::ValidationIssue
    unless source.type == "section"
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "legacy.section.type.invalid",
        path: "type",
        message: "Legacy section type must be section."
      )
    end

    text = source.text.try { |value| section_text(value, "text", issues) }
    fields = source.fields.try do |values|
      values.map_with_index do |value, index|
        section_field_text(value, "fields[#{index}]", issues)
      end
    end
    accessory = source.accessory.try { |value| section_accessory(value, issues) }

    raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?

    if text && fields
      Slack::UI::Checked::Blocks::Section.new(
        text: text,
        fields: fields,
        accessory: accessory,
        block_id: source.block_id
      )
    elsif text
      Slack::UI::Checked::Blocks::Section.new(
        text: text,
        accessory: accessory,
        block_id: source.block_id
      )
    elsif fields
      Slack::UI::Checked::Blocks::Section.new(
        fields: fields,
        accessory: accessory,
        block_id: source.block_id
      )
    else
      raise Slack::UI::Checked::ValidationError.new([
        Slack::UI::Checked::ValidationIssue.new(
          code: "legacy.section.content.missing",
          path: "section",
          message: "Legacy section must contain text or fields."
        ),
      ])
    end
  end

  def self.actions(source : Slack::UI::Blocks::Actions) : Slack::UI::Checked::Blocks::Actions
    issues = [] of Slack::UI::Checked::ValidationIssue
    elements = source.elements.map_with_index do |element, index|
      convert_button(element, "elements[#{index}]", issues)
    end
    raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?

    Slack::UI::Checked::Blocks::Actions.new(
      elements: elements,
      block_id: source.block_id
    )
  end

  def self.button(source : Slack::UI::BlockElements::Button) : Slack::UI::Checked::BlockElements::Button
    issues = [] of Slack::UI::Checked::ValidationIssue
    converted = convert_button(source, "", issues)
    raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?

    converted
  end

  private def self.section_text(
    source : LegacySection::Text,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : CheckedText
    text(source.text, source.type, source.emoji, source.verbatim, path, issues)
  end

  private def self.section_field_text(
    source : LegacySection::FieldText,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : CheckedText
    text(source.text, source.type, source.emoji, source.verbatim, path, issues)
  end

  private def self.text(
    value : String,
    type : String,
    emoji : Bool,
    verbatim : Bool,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : CheckedText
    with_validation_path(path) do
      case type
      when "plain_text"
        Slack::UI::Checked::CompositionObjects::PlainText.new(value, emoji: emoji)
      when "mrkdwn"
        Slack::UI::Checked::CompositionObjects::Mrkdwn.new(value, verbatim: verbatim)
      else
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "legacy.text.type.invalid",
          path: "#{path}.type",
          message: "Legacy text type must be plain_text or mrkdwn."
        )
        Slack::UI::Checked::CompositionObjects::PlainText.new(value)
      end
    end
  end

  private def self.section_accessory(
    source : Slack::UI::BlockElement,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : Slack::UI::Checked::BlockElements::Button?
    unless source.is_a?(Slack::UI::BlockElements::Button)
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "legacy.section.accessory.unsupported",
        path: "accessory",
        message: "The legacy accessory is not supported by the checked Section."
      )
      return
    end

    convert_button(source, "accessory", issues)
  end

  private def self.convert_button(
    source : Slack::UI::BlockElements::Button,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : Slack::UI::Checked::BlockElements::Button
    prefix = path.empty? ? "" : "#{path}."
    unless source.type == "button"
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "legacy.button.type.invalid",
        path: "#{prefix}type",
        message: "Legacy button type must be button."
      )
    end
    unless source.text.type == "plain_text"
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "legacy.button.text.type.invalid",
        path: "#{prefix}text.type",
        message: "Legacy button text must be plain_text."
      )
    end

    style = source.style.try do |value|
      unless Slack::UI::BlockElements::Button::Styles.valid?(value)
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "legacy.button.style.invalid",
          path: "#{prefix}style",
          message: "Legacy button style must be primary or danger."
        )
        next
      end
      value.primary? ? Slack::UI::Checked::BlockElements::ButtonStyle::Primary : Slack::UI::Checked::BlockElements::ButtonStyle::Danger
    end

    confirmation = source.confirm.try { |value| convert_confirmation(value, "#{prefix}confirm", issues) }
    text = with_validation_path("#{prefix}text") do
      Slack::UI::Checked::CompositionObjects::PlainText.new(
        source.text.text,
        emoji: source.text.emoji
      )
    end
    with_validation_path(path) do
      Slack::UI::Checked::BlockElements::Button.new(
        text: text,
        action_id: source.action_id,
        url: source.url,
        value: source.value,
        style: style,
        confirm: confirmation
      )
    end
  end

  private def self.convert_confirmation(
    source : Slack::UI::CompositionObjects::Confirmation,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : Slack::UI::Checked::CompositionObjects::Confirmation
    title = plain_confirmation_text(source.title.text, source.title.type, source.title.emoji, "#{path}.title", issues)
    body = text(source.text.text, source.text.type, source.text.emoji, source.text.verbatim, "#{path}.text", issues)
    confirm = plain_confirmation_text(source.confirm.text, source.confirm.type, source.confirm.emoji, "#{path}.confirm", issues)
    deny = plain_confirmation_text(source.deny.text, source.deny.type, source.deny.emoji, "#{path}.deny", issues)
    style = confirmation_style(source.style, path, issues)

    with_validation_path(path) do
      Slack::UI::Checked::CompositionObjects::Confirmation.new(
        title: title,
        text: body,
        confirm: confirm,
        deny: deny,
        style: style
      )
    end
  end

  private def self.plain_confirmation_text(
    value : String,
    type : String,
    emoji : Bool,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : Slack::UI::Checked::CompositionObjects::PlainText
    unless type == "plain_text"
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "legacy.confirmation.text.type.invalid",
        path: "#{path}.type",
        message: "This confirmation text must be plain_text."
      )
    end
    with_validation_path(path) do
      Slack::UI::Checked::CompositionObjects::PlainText.new(value, emoji: emoji)
    end
  end

  # Wrap only the local constructor; child conversions already have root-relative paths.
  private def self.with_validation_path(path : String, & : -> T) : T forall T
    yield
  rescue error : Slack::UI::Checked::ValidationError
    raise error if path.empty?

    raise Slack::UI::Checked::ValidationError.new(error.issues.map(&.at(path)))
  end

  private def self.confirmation_style(
    style : String?,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : Slack::UI::Checked::CompositionObjects::ConfirmationStyle?
    case style
    when nil
      nil
    when "primary"
      Slack::UI::Checked::CompositionObjects::ConfirmationStyle::Primary
    when "danger"
      Slack::UI::Checked::CompositionObjects::ConfirmationStyle::Danger
    else
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "legacy.confirmation.style.invalid",
        path: "#{path}.style",
        message: "Legacy confirmation style must be primary or danger."
      )
      nil
    end
  end
end
