# Display membership is independent of Message: Input in a modal requires submit.
alias Slack::UI::DisplayModalBlock = Slack::UI::Blocks::Section |
                                     Slack::UI::Blocks::Actions |
                                     Slack::UI::Blocks::Divider |
                                     Slack::UI::Blocks::Header |
                                     Slack::UI::Blocks::Context |
                                     Slack::UI::Blocks::Image |
                                     Slack::UI::Blocks::Video |
                                     Slack::UI::Blocks::RichText |
                                     Slack::UI::Blocks::Alert |
                                     Slack::UI::Blocks::Card
alias Slack::UI::ModalBlock = Slack::UI::DisplayModalBlock | Slack::UI::Blocks::Input | Slack::UI::Blocks::ModalInput | Slack::UI::Blocks::ViewInput
alias Slack::UI::Modal = Slack::UI::DisplayModal | Slack::UI::FormModal

# Shared wire and validation rules; each concrete surface owns its child union.
module Slack::UI::ModalContent
  include Slack::UI::ValueValidation

  def type : String
    "modal"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    {"title" => @title, "submit" => @submit, "close" => @close}.each do |field, text|
      if text
        text.validate.each { |issue| issues << issue.at(field) }
        length_issue(issues, text.text, 24, "modal.#{field}.too_long", "#{field}.text")
      end
    end
    length_issue(issues, @private_metadata, 3000, "modal.private_metadata.too_long", "private_metadata")
    length_issue(issues, @callback_id, 255, "modal.callback_id.too_long", "callback_id")
    length_issue(issues, @external_id, 255, "modal.external_id.too_long", "external_id")
    if @blocks.size > 100
      issues << Slack::UI::ValidationIssue.new("modal.blocks.too_many", "blocks", "A modal cannot contain more than 100 blocks.")
    end
    BlockValidation.validate(@blocks, issues, "modal.block_id.duplicate", "Block IDs must be unique within a view.")
    issues.concat(Slack::UI::ViewFocus.validate(@blocks, "modal"))
    issues.concat(Slack::UI::WorkflowButtonPlacement.validate(@blocks, "modal"))
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "title", @title
      json.field "blocks", @blocks
      json.field "submit", @submit if @submit
      json.field "close", @close if @close
      json.field "private_metadata", @private_metadata if @private_metadata
      json.field "callback_id", @callback_id if @callback_id
      json.field "external_id", @external_id if @external_id
      json.field "clear_on_close", @clear_on_close unless @clear_on_close.nil?
      json.field "notify_on_close", @notify_on_close unless @notify_on_close.nil?
      json.field "submit_disabled", @submit_disabled unless @submit_disabled.nil?
    end
  end
end
