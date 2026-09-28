struct Slack::Interactions::RichText::WorkflowMention
  getter raw : JSON::Any
  getter workflow_id : String
  getter function_trigger_id : String
  getter text : String
  getter url : String?
  # The encoded channel ID and message timestamp where the mention lives.
  getter channel_id : String?
  getter ts : String?
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @workflow_id = PayloadAccess.string(object["workflow_id"]?, "#{path}.workflow_id")
    @function_trigger_id = PayloadAccess.string(object["function_trigger_id"]?, "#{path}.function_trigger_id")
    @text = PayloadAccess.string(object["text"]?, "#{path}.text")
    @url = PayloadAccess.string?(object["url"]?, "#{path}.url")
    @channel_id = PayloadAccess.string?(object["channel_id"]?, "#{path}.channel_id")
    @ts = PayloadAccess.string?(object["ts"]?, "#{path}.ts")
    @style = Decoder.style?(object, path)
  end
end
