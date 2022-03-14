class Slack::UI::Components::TextSection < Slack::UI::BaseComponent
  def self.render(text : String,
                  button : BlockElements::Button) : Blocks::Section
    Blocks::Section.new(
      text: Blocks::Section::Text.new(text),
      accessory: button
    )
  end

  def self.render(text : String) : Blocks::Section
    Blocks::Section.new text: Blocks::Section::Text.new(text)
  end

  def self.render(text : String, markdown : Bool)
    return render(text) unless markdown

    Blocks::Section.new text: Blocks::Section::Text.new(text, type: "mrkdwn")
  end
end
