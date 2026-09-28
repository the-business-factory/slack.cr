alias Slack::UI::Checked::Blocks::InputElement = Slack::UI::Checked::BlockElements::PlainTextInput | Slack::UI::Checked::BlockElements::StaticSelect | Slack::UI::Checked::BlockElements::MultiStaticSelect | Slack::UI::Checked::BlockElements::ExternalSelect | Slack::UI::Checked::BlockElements::MultiExternalSelect | Slack::UI::Checked::BlockElements::Checkboxes | Slack::UI::Checked::BlockElements::RadioButtons | Slack::UI::Checked::BlockElements::UsersSelect | Slack::UI::Checked::BlockElements::MultiUsersSelect | Slack::UI::Checked::BlockElements::ConversationsSelect | Slack::UI::Checked::BlockElements::MultiConversationsSelect | Slack::UI::Checked::BlockElements::DatePicker | Slack::UI::Checked::BlockElements::TimePicker | Slack::UI::Checked::BlockElements::DatetimePicker | Slack::UI::Checked::BlockElements::ChannelsSelect | Slack::UI::Checked::BlockElements::MultiChannelsSelect

struct Slack::UI::Checked::Blocks::Input
  include Slack::UI::Checked::Blocks::InputContent

  getter label : Slack::UI::Checked::CompositionObjects::PlainText
  getter element : InputElement
  getter block_id : String?
  getter hint : Slack::UI::Checked::CompositionObjects::PlainText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(
    @label : Slack::UI::Checked::CompositionObjects::PlainText,
    @element : InputElement,
    @block_id : String? = nil,
    @hint : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @optional : Bool? = nil,
    @dispatch_action : Bool? = nil,
  )
    validate!
  end
end
