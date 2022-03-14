struct Slack::Models::Conversation < Slack::Model
  def self.from_json(json : String | IO)
    keyed_json_object(json, "channel") do |pull|
      pull.read_object do |key|
        case key
        when "is_channel"
          pull.read_bool
          return PublicChannel.from_json(json)
        when "is_im"
          pull.read_bool
          return IMChat.from_json(json)
        when "is_group"
          pull.read_bool
          return PrivateChannel.from_json(json)
        else
          pull.skip
        end
      end
    end

    raise Slack::Errors::Api.new(json)
  end
end
