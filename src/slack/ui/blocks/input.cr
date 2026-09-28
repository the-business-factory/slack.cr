alias Slack::UI::Blocks::InputElement = Slack::UI::BlockElements::PlainTextInput | Slack::UI::BlockElements::StaticSelect | Slack::UI::BlockElements::MultiStaticSelect | Slack::UI::BlockElements::ExternalSelect | Slack::UI::BlockElements::MultiExternalSelect | Slack::UI::BlockElements::Checkboxes | Slack::UI::BlockElements::RadioButtons | Slack::UI::BlockElements::UsersSelect | Slack::UI::BlockElements::MultiUsersSelect | Slack::UI::BlockElements::ConversationsSelect | Slack::UI::BlockElements::MultiConversationsSelect | Slack::UI::BlockElements::DatePicker | Slack::UI::BlockElements::TimePicker | Slack::UI::BlockElements::DatetimePicker | Slack::UI::BlockElements::ChannelsSelect | Slack::UI::BlockElements::MultiChannelsSelect

struct Slack::UI::Blocks::Input
  include Slack::UI::Blocks::InputContent

  getter label : Slack::UI::CompositionObjects::PlainText
  getter element : InputElement
  getter block_id : String?
  getter hint : Slack::UI::CompositionObjects::PlainText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(
    @label : Slack::UI::CompositionObjects::PlainText,
    @element : InputElement,
    @block_id : String? = nil,
    @hint : Slack::UI::CompositionObjects::PlainText? = nil,
    @optional : Bool? = nil,
    @dispatch_action : Bool? = nil,
  )
    validate!
  end
end
