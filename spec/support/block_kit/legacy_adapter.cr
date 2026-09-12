require "../../../src/slack"
require "./ui_only"

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
        field_text(value, "fields[#{index}]", issues)
      end
    end
    accessory = source.accessory.try { |value| button(value, issues) }

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

  private def self.section_text(
    source : LegacySection::Text,
    path : String,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : CheckedText
    text(source.text, source.type, source.emoji, source.verbatim, path, issues)
  end

  private def self.field_text(
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

  private def self.button(
    source : Slack::UI::BlockElement,
    issues : Array(Slack::UI::Checked::ValidationIssue),
  ) : Slack::UI::Checked::BlockElements::Button?
    unless source.is_a?(Slack::UI::BlockElements::Button)
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "legacy.section.accessory.unsupported",
        path: "accessory",
        message: "The legacy accessory is not supported by this checked prototype."
      )
      return
    end

    style = source.style.try do |value|
      unless Slack::UI::BlockElements::Button::Styles.valid?(value)
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "legacy.button.style.invalid",
          path: "accessory.style",
          message: "Legacy button style must be primary or danger."
        )
        next
      end
      value.primary? ? Slack::UI::Checked::BlockElements::ButtonStyle::Primary : Slack::UI::Checked::BlockElements::ButtonStyle::Danger
    end

    text = Slack::UI::Checked::CompositionObjects::PlainText.new(
      source.text.text,
      emoji: source.text.emoji
    )
    Slack::UI::Checked::BlockElements::Button.new(
      text: text,
      action_id: source.action_id,
      style: style
    )
  end
end
