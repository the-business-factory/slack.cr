struct Slack::Api::ResponseHandler(ResponseModel)
  def self.from_json(json : String | IO, &block) : ResponseModel
    pull = JSON::PullParser.new(json)

    pull.read_object do |key|
      case key
      when "ok"
        ok = pull.read_bool
        if ok
          return yield(json)
        else
          raise Slack::Errors::Api.new(json)
        end
      else
        pull.skip
      end
    end

    raise Slack::Errors::Api.new(json)
  end

  def self.from_json(json : String | IO) : ResponseModel
    from_json(json) do
      ResponseModel.new JSON::PullParser.new(json)
    end
  end
end
