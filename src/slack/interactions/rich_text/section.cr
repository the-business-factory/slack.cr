alias Slack::Interactions::RichText::Element = Slack::Interactions::RichText::Text |
                                               Slack::Interactions::RichText::Link |
                                               Slack::Interactions::RichText::Emoji |
                                               Slack::Interactions::RichText::User |
                                               Slack::Interactions::RichText::Usergroup |
                                               Slack::Interactions::RichText::Channel |
                                               Slack::Interactions::RichText::Broadcast |
                                               Slack::Interactions::RichText::Date |
                                               Slack::Interactions::RichText::Color |
                                               Slack::Interactions::RichText::Team |
                                               Slack::Interactions::RichText::File |
                                               Slack::Interactions::RichText::Canvas |
                                               Slack::Interactions::RichText::WorkflowMention |
                                               Slack::Interactions::RichText::Unknown

struct Slack::Interactions::RichText::Section
  getter raw : JSON::Any
  @elements : Array(Element)

  def initialize(@raw : JSON::Any, path : String)
    @elements = Decoder.elements(Decoder.object(@raw, path), path)
  end

  def elements : Array(Element)
    @elements.dup
  end
end
