require "../../ui/base_components"

struct Slack::Helpers::Modal
  include Slack::UI::BaseComponents

  alias UIModal = Slack::UI::Modal

  # https://api.slack.com/surfaces/modals/using#response_actions
  CLOSE = {response_action: "clear"}

  def self.open(
    access_token : String,
    blocks : Array(ModalBlock),
    close : String,
    submit : String,
    trigger_id : String,
    title : String,
    *,
    configuration : Slack::Auth::APIConfiguration = Slack.settings.api_configuration,
    transport : Slack::Auth::Transport? = nil,
    limiter : RateLimiter::LimiterLike? = nil,
  ) : Slack::Models::ViewsOpen
    Slack::Api::ViewsOpen.new(
      token: access_token,
      trigger_id: trigger_id,
      view: UIModal.new(
        title: UIModal::Title.new(text: title),
        submit: UIModal::Submit.new(text: submit),
        close: UIModal::Close.new(text: close),
        blocks: blocks
      ),
      configuration: configuration,
      transport: transport,
      limiter: limiter
    ).call
  end

  def self.open(
    *,
    blocks : Array(ModalBlock),
    close : String,
    submit : String,
    trigger_id : String,
    title : String,
    transport : Slack::Auth::Transport,
    limiter : RateLimiter::LimiterLike,
    configuration : Slack::Auth::APIConfiguration = Slack.settings.api_configuration,
  ) : Slack::Models::ViewsOpen
    Slack::Api::ViewsOpen.tokenless(
      trigger_id: trigger_id,
      view: UIModal.new(
        title: UIModal::Title.new(text: title),
        submit: UIModal::Submit.new(text: submit),
        close: UIModal::Close.new(text: close),
        blocks: blocks
      ),
      configuration: configuration,
      transport: transport,
      limiter: limiter
    ).call
  end
end
