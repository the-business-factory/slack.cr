# Outbound JSON acknowledgment that closes every view in a modal stack.
# Return this JSON in an HTTP 200 response to a view_submission within three
# seconds. An empty HTTP 200 instead closes only the submitted view.
struct Slack::Interactions::ModalClear
  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "response_action", "clear"
    end
  end
end
