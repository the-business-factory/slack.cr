struct Slack::Interactions::ViewSubmission < Slack::Interaction
  @[JSON::Field(emit_null: false)]
  property response_urls : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?

  def state_map : StateMap
    @view.try(&.state_map) || StateMap.new(nil, "view.state")
  end

  def plain_text?(block_id : String, action_id : String) : String?
    state_map.plain_text?(block_id, action_id)
  end
end
