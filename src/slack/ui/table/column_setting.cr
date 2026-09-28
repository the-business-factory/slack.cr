# Alignment and wrapping for one table column. Omitted fields use Slack's
# defaults (left, not wrapped); an explicit `false` is sent as `false`.
struct Slack::UI::Table::ColumnSetting
  getter align : ColumnAlignment?
  getter is_wrapped : Bool?

  def initialize(@align : ColumnAlignment? = nil, @is_wrapped : Bool? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      if align = @align
        json.field "align", align.wire_value
      end
      json.field "is_wrapped", @is_wrapped unless @is_wrapped.nil?
    end
  end
end
