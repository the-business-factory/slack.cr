# A legacy attachment field. Slack shows a `short` field beside other short fields.
struct Slack::UI::Attachment::Field
  getter title : String?
  getter value : String?
  getter short : Bool?

  def initialize(@title : String? = nil, @value : String? = nil, @short : Bool? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "title", @title if @title
      json.field "value", @value if @value
      json.field "short", @short unless @short.nil?
    end
  end
end
