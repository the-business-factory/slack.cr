module Slack::UI::Checked::DeclaredTypes
  def self.text(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::CompositionObjects::Text %}
      {% raise "checked text collection rejects its declared item type" %}
    {% end %}
  end

  def self.actions_element(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::BlockElements::Button %}
      {% raise "checked actions rejects its declared element item type" %}
    {% end %}
  end

  def self.message_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::MessageSourceBlock %}
      {% raise "checked message rejects its declared block item type" %}
    {% end %}
  end
end

module Slack::UI::Checked::DeclaredTypes
  def self.display_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::DisplayModalBlock %}
      {% raise "checked display_modal rejects its declared block item type" %}
    {% end %}
  end
end

module Slack::UI::Checked::DeclaredTypes
  def self.form_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::ModalBlock %}
      {% raise "checked form_modal rejects its declared block item type" %}
    {% end %}
  end
end

module Slack::UI::Checked::DeclaredTypes
  def self.context_element(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::Blocks::ContextElement %}
      {% raise "checked context rejects its declared element item type" %}
    {% end %}
  end

  def self.home_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::HomeBlock %}
      {% raise "checked home rejects its declared block item type" %}
    {% end %}
  end
end
