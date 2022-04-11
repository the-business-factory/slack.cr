module Slack
  module TypeAliases
    alias Blocks = Slack::UI::Blocks
    alias Elements = Slack::UI::BlockElements
    alias Components = Slack::UI::Components

    alias ButtonElement = Components::ButtonElement
    alias ConfirmationDialog = Components::ConfirmationDialog
    alias TextSection = Components::TextSection
    alias InputElement = Components::InputElement

    alias ButtonStyles = Elements::Button::Styles

    alias ModalBlock = Blocks::Actions |
                       Blocks::Context |
                       Blocks::Divider |
                       Blocks::Header |
                       Blocks::Image |
                       Blocks::Input |
                       Blocks::Section
  end
end
