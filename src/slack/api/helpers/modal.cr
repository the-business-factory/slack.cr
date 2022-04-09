require "../../ui/base_components"

class Slack::Helpers::Modal
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
    title : String
  )
    Slack::Api::ViewsOpen.new(
      token: access_token,
      trigger_id: trigger_id,
      view: UIModal.new(
        title: UIModal::Title.new(text: title),
        submit: UIModal::Submit.new(text: submit),
        close: UIModal::Close.new(text: close),
        blocks: blocks
      )
    ).call
  end
end
