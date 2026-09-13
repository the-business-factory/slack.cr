alias Slack::UI::Checked::DisplayModalBlock = Slack::UI::Checked::MessageBlock
alias Slack::UI::Checked::ModalBlock = Slack::UI::Checked::DisplayModalBlock | Slack::UI::Checked::Blocks::Input
alias Slack::UI::Checked::Modal = Slack::UI::Checked::DisplayModal | Slack::UI::Checked::FormModal

# Shared wire and validation rules; each concrete surface owns its child union.
module Slack::UI::Checked::ModalContent
  include Slack::UI::Checked::ValueValidation

  def type : String
    "modal"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
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
      issues << Slack::UI::Checked::ValidationIssue.new("modal.blocks.too_many", "blocks", "A modal cannot contain more than 100 blocks.")
    end
    block_ids = Set(String).new
    focused = false
    @blocks.each_with_index do |block, index|
      block.validate.each { |issue| issues << issue.at("blocks[#{index}]") }
      if id = block.block_id
        unless block_ids.add?(id)
          issues << Slack::UI::Checked::ValidationIssue.new("modal.block_id.duplicate", "blocks[#{index}].block_id", "Block IDs must be unique within a view.")
        end
      end
      if block.is_a?(Slack::UI::Checked::Blocks::Input) && block.element.focus_on_load
        if focused
          issues << Slack::UI::Checked::ValidationIssue.new("modal.focus_on_load.duplicate", "blocks[#{index}].element.focus_on_load", "Only one element in a view can focus on load.")
        end
        focused = true
      end
    end
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
