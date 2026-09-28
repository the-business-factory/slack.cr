# The icon of a streamed task update.
#
# Undocumented: Slack's only example is `{"type":"icon","name":"https://…"}`, which
# does not match the Slack icon object (a fixed name list). The library sends
# *name* unchanged and does not check it.
struct Slack::Api::Streaming::IconRef
  getter name : String

  def initialize(@name : String)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "type", "icon"
      json.field "name", @name
    end
  end
end
