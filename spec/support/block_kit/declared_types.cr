module Slack::UI::Checked::Proof::DeclaredTypes
  def self.display_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::Proof::DisplayModalSourceBlock %}
      {% raise "display modal rejects its declared block item type" %}
    {% end %}
  end

  def self.form_modal_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::Proof::FormModalSourceBlock %}
      {% raise "form modal rejects its declared block item type" %}
    {% end %}
  end

  def self.home_block(type : T.class) : Nil forall T
    {% unless T <= Slack::UI::Checked::Proof::HomeSourceBlock %}
      {% raise "synthetic home surface rejects its declared block item type" %}
    {% end %}
  end
end
