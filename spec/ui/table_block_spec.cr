require "../spec_helper"

module TableBlockSpec
  alias UI = Slack::UI
  alias RT = UI::RichText

  def self.raw(text : String) : UI::Table::RawText
    UI::Table::RawText.new(text)
  end

  describe UI::Blocks::Table do
    it "serializes raw text, raw number, and rich text cells with column settings" do
      owner = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::User.new("U-SYNTHETIC")})})
      team = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::Link.new("https://example.com/apac", text: "APAC team")})})
      rows = [
        [raw("Region"), raw("Owner"), raw("Revenue")],
        [raw("EMEA"), owner, UI::Table::RawNumber.new(1_250_000, "$1.25M")],
        [raw("APAC"), team, UI::Table::RawNumber.new(980_000.5, "$980,000.50")],
      ]
      settings = [
        UI::Table::ColumnSetting.new(is_wrapped: true),
        nil,
        UI::Table::ColumnSetting.new(align: UI::Table::ColumnAlignment::Right, is_wrapped: false),
      ]
      message = UI.message(fallback_text: "Quarterly revenue by region") do |builder|
        builder.table(rows, column_settings: settings, block_id: "revenue")
        builder.add(UI::Blocks::Table.new(rows: {[raw("Total"), UI::Table::RawNumber.new(-3, "-3")]}))
      end

      JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/table_message.json"))
    end

    it "places a table on Home" do
      home = UI.home(&.table({ {raw("Open"), UI::Table::RawNumber.new(4, "4")} }, column_settings: {UI::Table::ColumnSetting.new(align: UI::Table::ColumnAlignment::Center)}))

      JSON.parse(home.to_json)["blocks"].should eq JSON.parse(<<-JSON)
        [{"type":"table","column_settings":[{"align":"center"}],
          "rows":[[{"type":"raw_text","text":"Open"},{"type":"raw_number","value":4,"text":"4"}]]}]
        JSON
    end

    it "owns copies of rows, cells, and column settings" do
      row = [raw("A")] of UI::Table::Cell
      rows = [row]
      settings = [UI::Table::ColumnSetting.new(is_wrapped: true)] of UI::Table::ColumnSetting?
      table = UI::Blocks::Table.new(rows: rows, column_settings: settings)
      row << raw("B")
      rows << [raw("C")] of UI::Table::Cell
      settings << nil
      table.rows.first << raw("D")
      table.rows << [raw("E")] of UI::Table::Cell
      table.column_settings.try(&.clear)

      JSON.parse(table.to_json).should eq JSON.parse(%({"type":"table","column_settings":[{"is_wrapped":true}],"rows":[[{"type":"raw_text","text":"A"}]]}))
    end

    it "accepts Slack's documented maximums" do
      row = Array.new(20) { raw("x") }
      table = UI::Blocks::Table.new(rows: Array.new(100) { row }, column_settings: Array.new(20) { UI::Table::ColumnSetting.new }, block_id: "界" * 255)

      table.rows.size.should eq 100
      table.rows.first.size.should eq 20
    end

    it "rejects rows, cells, and settings beyond Slack's limits" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Table.new(
          rows: Array.new(101) { |index| index == 1 ? Array.new(21) { raw("x") } : [raw("x")] },
          column_settings: Array(UI::Table::ColumnSetting?).new(21, nil),
          block_id: "界" * 256
        )
      end
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [
        {"table.rows.too_many", "rows"},
        {"table.row.too_many_cells", "rows[1]"},
        {"table.column_settings.too_many", "column_settings"},
        {"table.block_id.too_long", "block_id"},
      ]
    end

    it "rejects empty tables, empty rows, and empty or non-finite cells as library policy" do
      expect_raises(UI::ValidationError, /at least one row/) { UI::Blocks::Table.new(rows: [] of Array(UI::Table::Cell)) }

      error = expect_raises(UI::ValidationError) { UI::Blocks::Table.new(rows: {[] of UI::Table::Cell}) }
      error.issues.map { |issue| {issue.code, issue.path} }.should eq [{"table.row.empty", "rows[0]"}]

      expect_raises(UI::ValidationError, /must not be empty/) { raw("") }
      expect_raises(UI::ValidationError, /must not be empty/) { UI::Table::RawNumber.new(1, "") }
      error = expect_raises(UI::ValidationError) { UI::Table::RawNumber.new(Float64::NAN, "n/a") }
      error.issues.map(&.code).should eq ["raw_number.value.not_finite"]
      expect_raises(UI::ValidationError) { UI::Table::RawNumber.new(Float64::INFINITY, "∞") }
    end
  end
end
