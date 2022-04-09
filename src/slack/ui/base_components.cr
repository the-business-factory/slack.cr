module Slack::UI::BaseComponents
  module TypeAliases
    alias Blocks = Slack::UI::Blocks
    alias Elements = Slack::UI::BlockElements
    alias Components = Slack::UI::Components

    alias Button = Components::Button
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

  macro included
    include TypeAliases
  end
end
