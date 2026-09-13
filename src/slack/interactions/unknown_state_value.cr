# Retains unimplemented state variants, including empty selection arrays.
struct Slack::Interactions::UnknownStateValue
  getter type : String?
  getter raw : JSON::Any

  def initialize(@type : String?, @raw : JSON::Any)
  end
end
