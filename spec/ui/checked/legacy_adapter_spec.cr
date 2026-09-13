require "../../spec_helper"

describe Slack::UI::Checked::LegacyAdapter do
  it "copies every supported legacy Button and confirmation field" do
    confirmation = Slack::UI::CompositionObjects::Confirmation.new(
      title: Slack::UI::CompositionObjects::Confirmation::Title.new("Confirm"),
      text: Slack::UI::CompositionObjects::Confirmation::Text.new(
        "Continue with *request 42*?",
        type: "mrkdwn"
      ),
      confirm: Slack::UI::CompositionObjects::Confirmation::Confirm.new("Yes"),
      deny: Slack::UI::CompositionObjects::Confirmation::Deny.new("No"),
      style: "danger"
    )
    legacy = Slack::UI::BlockElements::Button.new(
      text: Slack::UI::BlockElements::Button::Text.new("Approve"),
      action_id: "request.approve",
      url: "https://example.test/requests/42",
      value: "request-42",
      style: Slack::UI::BlockElements::Button::Styles::Primary,
      confirm: confirmation
    )

    checked = Slack::UI::Checked::LegacyAdapter.button(legacy)
    payload = JSON.parse(checked.to_json)

    payload["action_id"].as_s.should eq "request.approve"
    payload["url"].as_s.should eq "https://example.test/requests/42"
    payload["value"].as_s.should eq "request-42"
    payload["style"].as_s.should eq "primary"
    payload["confirm"]["style"].as_s.should eq "danger"
    payload["confirm"]["text"]["type"].as_s.should eq "mrkdwn"
  end

  it "copies legacy Actions into an immutable checked snapshot" do
    legacy_button = Slack::UI::BlockElements::Button.new(
      text: Slack::UI::BlockElements::Button::Text.new("Approve"),
      action_id: "approve"
    )
    legacy = Slack::UI::Blocks::Actions.new(
      elements: [legacy_button],
      block_id: "controls"
    )
    checked = Slack::UI::Checked::LegacyAdapter.actions(legacy)
    before = checked.to_json

    legacy.elements.clear
    legacy.block_id = "changed"

    checked.to_json.should eq before
  end

  it "rejects unchecked legacy confirmation styles" do
    confirmation = Slack::UI::CompositionObjects::Confirmation.new(
      title: Slack::UI::CompositionObjects::Confirmation::Title.new("Confirm"),
      text: Slack::UI::CompositionObjects::Confirmation::Text.new("Continue?"),
      confirm: Slack::UI::CompositionObjects::Confirmation::Confirm.new("Yes"),
      deny: Slack::UI::CompositionObjects::Confirmation::Deny.new("No"),
      style: "warning"
    )
    legacy = Slack::UI::BlockElements::Button.new(
      text: Slack::UI::BlockElements::Button::Text.new("Approve"),
      action_id: "request.approve",
      confirm: confirmation
    )

    error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::LegacyAdapter.button(legacy)
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"legacy.confirmation.style.invalid", "confirm.style"},
    ]
  end

  it "keeps nested legacy discriminator and style issues rooted at the Section accessory" do
    text = Slack::UI::BlockElements::Button::Text.new("Valid")
    text.type = "mrkdwn"
    button = Slack::UI::BlockElements::Button.new(text: text, action_id: "approve")
    button.style = Slack::UI::BlockElements::Button::Styles.new(99)
    section = Slack::UI::Blocks::Section.new(
      text: Slack::UI::Blocks::Section::Text.new("Section"),
      accessory: button
    )

    error = expect_raises(Slack::UI::Checked::ValidationError) do
      Slack::UI::Checked::LegacyAdapter.section(section)
    end

    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"legacy.button.text.type.invalid", "accessory.text.type"},
      {"legacy.button.style.invalid", "accessory.style"},
    ]
  end

  {"button" => "", "actions" => "elements[1].", "section" => "accessory."}.each do |root, prefix|
    {76 => "button.text.too_long", 0 => "plain_text.text.empty", 3001 => "plain_text.text.too_long"}.each do |length, code|
      it "locates a #{length}-character Button label relative to the #{root} conversion root" do
        text = Slack::UI::BlockElements::Button::Text.new("Valid")
        text.text = "x" * length
        button = Slack::UI::BlockElements::Button.new(text: text, action_id: "second")

        error = expect_raises(Slack::UI::Checked::ValidationError) do
          case root
          when "button"
            Slack::UI::Checked::LegacyAdapter.button(button)
          when "actions"
            first = Slack::UI::BlockElements::Button.new(
              text: Slack::UI::BlockElements::Button::Text.new("First"),
              action_id: "first"
            )
            Slack::UI::Checked::LegacyAdapter.actions(Slack::UI::Blocks::Actions.new(elements: [first, button]))
          when "section"
            section = Slack::UI::Blocks::Section.new(
              text: Slack::UI::Blocks::Section::Text.new("Section"),
              accessory: button
            )
            Slack::UI::Checked::LegacyAdapter.section(section)
          end
        end

        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, "#{prefix}text.text"}]
      end
    end

    {% for field, maximum in {title: 100, text: 300, confirm: 30, deny: 30} %}
      {0 => "plain_text.text.empty", {{ maximum + 1 }} => "confirmation.{{ field.id }}.too_long"}.each do |length, code|
        it "locates a #{length}-character confirmation {{ field.id }} relative to the #{root} conversion root" do
          confirmation = Slack::UI::CompositionObjects::Confirmation.new(
            title: Slack::UI::CompositionObjects::Confirmation::Title.new("Confirm"),
            text: Slack::UI::CompositionObjects::Confirmation::Text.new("Continue?"),
            confirm: Slack::UI::CompositionObjects::Confirmation::Confirm.new("Yes"),
            deny: Slack::UI::CompositionObjects::Confirmation::Deny.new("No")
          )
          text = confirmation.{{ field.id }}
          text.text = "x" * length
          confirmation.{{ field.id }} = text
          button = Slack::UI::BlockElements::Button.new(
            text: Slack::UI::BlockElements::Button::Text.new("Valid"),
            action_id: "second",
            confirm: confirmation
          )

          error = expect_raises(Slack::UI::Checked::ValidationError) do
            case root
            when "button"
              Slack::UI::Checked::LegacyAdapter.button(button)
            when "actions"
              first = Slack::UI::BlockElements::Button.new(
                text: Slack::UI::BlockElements::Button::Text.new("First"),
                action_id: "first"
              )
              Slack::UI::Checked::LegacyAdapter.actions(Slack::UI::Blocks::Actions.new(elements: [first, button]))
            when "section"
              section = Slack::UI::Blocks::Section.new(
                text: Slack::UI::Blocks::Section::Text.new("Section"),
                accessory: button
              )
              Slack::UI::Checked::LegacyAdapter.section(section)
            end
          end

          error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, "#{prefix}confirm.{{ field.id }}.text"}]
        end
      end
    {% end %}
  end

  {"plain_text", "mrkdwn"}.each do |type|
    {0, 3001}.each do |length|
      it "locates invalid #{type} Section text with #{length} characters" do
        text = Slack::UI::Blocks::Section::Text.new("Valid", type: type)
        text.text = "x" * length
        section = Slack::UI::Blocks::Section.new(text: text)

        error = expect_raises(Slack::UI::Checked::ValidationError) do
          Slack::UI::Checked::LegacyAdapter.section(section)
        end

        code = length == 0 ? "#{type}.text.empty" : "#{type}.text.too_long"
        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, "text.text"}]
      end
    end

    {0 => "#{type}.text.empty", 2001 => "section.field.text.too_long", 3001 => "#{type}.text.too_long"}.each do |length, code|
      it "locates invalid #{type} Section fields with #{length} characters" do
        field = Slack::UI::Blocks::Section::FieldText.new("Valid", type: type)
        field.text = "x" * length
        section = Slack::UI::Blocks::Section.new(fields: [Slack::UI::Blocks::Section::FieldText.new("First"), field])

        error = expect_raises(Slack::UI::Checked::ValidationError) do
          Slack::UI::Checked::LegacyAdapter.section(section)
        end

        error.issues.map { |issue| {issue.code, issue.path} }.should eq [{code, "fields[1].text"}]
      end
    end
  end
end
