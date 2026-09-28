require "../spec_helper"

module ContextActionsSpec
  alias UI = Slack::UI

  def self.feedback(action_id : String? = nil, positive_value : String = "up") : UI::BlockElements::FeedbackButtons
    UI::BlockElements::FeedbackButtons.new(
      positive_button: UI::CompositionObjects::FeedbackButton.new(text: UI.plain("👍"), value: positive_value),
      negative_button: UI::CompositionObjects::FeedbackButton.new(text: UI.plain("👎"), value: "down"),
      action_id: action_id
    )
  end

  def self.trash(action_id : String? = nil) : UI::BlockElements::IconButton
    UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Remove"), action_id: action_id)
  end

  def self.codes(& : ->) : Array(String)
    yield
    raise "Expected a validation error"
  rescue error : UI::ValidationError
    error.issues.map(&.code)
  end

  describe UI::Blocks::ContextActions do
    it "serializes feedback buttons and icon buttons in a message" do
      confirm = UI::CompositionObjects::Confirmation.new(
        title: UI.plain("Delete answer?"), text: UI.plain("The answer is removed for everyone."),
        confirm: UI.plain("Delete"), deny: UI.plain("Keep"), style: UI::CompositionObjects::ConfirmationStyle::Danger
      )
      rating = UI::BlockElements::FeedbackButtons.new(
        action_id: "answer.feedback",
        positive_button: UI::CompositionObjects::FeedbackButton.new(
          text: UI.plain("Good"), value: "positive_feedback", accessibility_label: "Mark this response as good"),
        negative_button: UI::CompositionObjects::FeedbackButton.new(
          text: UI.plain("Bad"), value: "negative_feedback", accessibility_label: "Mark this response as bad"),
      )
      delete = UI::BlockElements::IconButton.new(
        UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Delete"), action_id: "answer.delete",
        value: "delete_item", confirm: confirm, accessibility_label: "Delete this answer",
        visible_to_user_ids: {"U-ASKER", "U-ADMIN"}
      )
      message = UI.message(fallback_text: "Draft answer") do |builder|
        builder.context_actions({rating, delete}, block_id: "answer.actions")
        builder.add(UI::Blocks::ContextActions.new(elements: [feedback, trash]))
      end

      JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/context_actions_message.json"))
    end

    it "owns copies of elements and visible user IDs" do
      elements = [trash] of UI::Blocks::ContextActions::Element
      users = ["U-ASKER"]
      button = UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Delete"), visible_to_user_ids: users)
      block = UI::Blocks::ContextActions.new(elements: elements)
      elements << feedback
      users << "U-OTHER"
      block.elements << feedback
      button.visible_to_user_ids.try(&.clear)

      JSON.parse(block.to_json)["elements"].size.should eq 1
      button.visible_to_user_ids.should eq ["U-ASKER"]
    end

    it "accepts Slack's documented maximums" do
      text = UI.plain("x" * 75)
      button = UI::CompositionObjects::FeedbackButton.new(text: text, value: "v" * 2000, accessibility_label: "a" * 75)
      rating = UI::BlockElements::FeedbackButtons.new(positive_button: button, negative_button: button, action_id: "f" * 255)
      icons = Array.new(4) do |index|
        UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: text, action_id: "#{index}" + "i" * 254,
          value: "v" * 2000, accessibility_label: "a" * 75)
      end
      block = UI::Blocks::ContextActions.new(elements: [rating] + icons, block_id: "界" * 255)

      block.elements.size.should eq 5
    end

    it "rejects values beyond Slack's documented limits" do
      codes { UI::CompositionObjects::FeedbackButton.new(text: UI.plain("x" * 76), value: "v" * 2001, accessibility_label: "a" * 76) }
        .should eq ["feedback_button.text.too_long", "feedback_button.value.too_long", "feedback_button.accessibility_label.too_long"]
      codes { feedback(action_id: "f" * 256) }.should eq ["feedback_buttons.action_id.too_long"]
      codes do
        UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("x" * 76), action_id: "i" * 256,
          value: "v" * 2001, accessibility_label: "a" * 76)
      end.should eq ["icon_button.text.too_long", "icon_button.action_id.too_long", "icon_button.value.too_long", "icon_button.accessibility_label.too_long"]
      codes { UI::Blocks::ContextActions.new(elements: Array.new(6) { trash }) }.should eq ["context_actions.elements.too_many"]
      codes { UI::Blocks::ContextActions.new(elements: [trash], block_id: "b" * 256) }.should eq ["context_actions.block_id.too_long"]
    end

    it "rejects an empty block, an empty visibility list, and duplicate action IDs" do
      codes { UI::Blocks::ContextActions.new(elements: [] of UI::Blocks::ContextActions::Element) }.should eq ["context_actions.elements.empty"]
      codes { UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Delete"), visible_to_user_ids: [] of String) }
        .should eq ["icon_button.visible_to_user_ids.empty"]
      codes { UI::BlockElements::IconButton.new(UI::BlockElements::IconButtonIcon::Trash, text: UI.plain("Delete"), visible_to_user_ids: {"U1", ""}) }
        .should eq ["icon_button.visible_to_user_ids.blank"]
      error = expect_raises(UI::ValidationError) { UI::Blocks::ContextActions.new(elements: {feedback(action_id: "same"), trash(action_id: "same")}) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"context_actions.action_id.duplicate", "elements[1].action_id"}]
    end
  end
end
