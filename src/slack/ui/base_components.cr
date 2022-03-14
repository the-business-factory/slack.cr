module Slack::UI::BaseComponents
  macro included
    alias Button = Slack::UI::Components::Button
    alias ConfirmationDialog = Slack::UI::Components::ConfirmationDialog
    alias TextSection = Slack::UI::Components::TextSection
    alias InputElement = Slack::UI::Components::InputElement
    alias ButtonStyles = Slack::UI::BlockElements::Button::Styles
  end
end
