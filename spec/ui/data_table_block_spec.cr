require "../spec_helper"

module DataTableBlockSpec
  alias UI = Slack::UI
  alias RT = UI::RichText

  def self.raw(text : String) : UI::Table::RawText
    UI::Table::RawText.new(text)
  end

  def self.codes(error : UI::ValidationError) : Array(Tuple(String, String))
    error.issues.map { |issue| {issue.code, issue.path} }
  end

  describe UI::Blocks::DataTable do
    it "sends the header as the first row, followed by raw and rich data rows" do
      owner = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::User.new("U-SYNTHETIC")})})
      deal = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::Text.new("Nimbus renewal", style: RT::TextStyle.new(bold: true))})})
      message = UI.message(fallback_text: "Open deals") do |builder|
        builder.data_table(
          caption: "Open deals by stage",
          header: {raw("Owner"), raw("Deal"), UI::Table::RawNumber.new(2026, "Value (2026)")},
          rows: [
            [owner, raw("Acme expansion"), UI::Table::RawNumber.new(1_200_000, "$1.2M")],
            [raw("Unassigned"), deal, UI::Table::RawNumber.new(87_500.5, "$87,500.50")],
          ],
          page_size: 10, row_header_column_index: 1, block_id: "deals"
        )
        builder.add(UI::Blocks::DataTable.new(caption: "Totals", header: {raw("Deals")}, rows: { {UI::Table::RawNumber.new(2, "2")} }))
      end

      JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/data_table_message.json"))
    end

    it "places a data table on Home" do
      home = UI.home(&.data_table(caption: "Queue", header: {raw("Ticket")}, rows: { {raw("T-1")} }, page_size: 1))

      JSON.parse(home.to_json)["blocks"].should eq JSON.parse(<<-JSON)
        [{"type":"data_table","caption":"Queue","page_size":1,
          "rows":[[{"type":"raw_text","text":"Ticket"}],[{"type":"raw_text","text":"T-1"}]]}]
        JSON
    end

    it "owns copies of the header and rows" do
      header = [raw("A")] of UI::Blocks::DataTable::HeaderCell
      row = [raw("a")] of UI::Table::Cell
      rows = [row]
      table = UI::Blocks::DataTable.new(caption: "Copy", header: header, rows: rows)
      header << raw("B")
      row << raw("b")
      rows << [raw("c")] of UI::Table::Cell
      table.header << raw("C")
      table.rows.first << raw("d")
      table.rows << [raw("e")] of UI::Table::Cell

      JSON.parse(table.to_json).should eq JSON.parse(<<-JSON)
        {"type":"data_table","caption":"Copy",
         "rows":[[{"type":"raw_text","text":"A"}],[{"type":"raw_text","text":"a"}]]}
        JSON
    end

    it "accepts Slack's documented maximums" do
      header = Array.new(20) { raw("h") }
      table = UI::Blocks::DataTable.new(caption: "Max", header: header, rows: Array.new(200) { Array.new(20) { raw("x") } },
        page_size: 100, row_header_column_index: 19, block_id: "界" * 255)

      JSON.parse(table.to_json)["rows"].as_a.size.should eq 201
    end

    it "rejects sizes beyond Slack's limits and rows that differ from the header width" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::DataTable.new(
          caption: "Too big",
          header: Array.new(21) { raw("h") },
          rows: Array.new(201) { |index| index == 1 ? [raw("x")] : Array.new(21) { raw("x") } },
          page_size: 101,
          block_id: "界" * 256
        )
      end
      codes(error).should eq [
        {"data_table.header.too_many_cells", "header"},
        {"data_table.rows.too_many", "rows"},
        {"data_table.row.width_mismatch", "rows[1]"},
        {"data_table.page_size.out_of_range", "page_size"},
        {"data_table.block_id.too_long", "block_id"},
      ]
    end

    it "rejects a table without a header cell, without data rows, or with page size 0" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::DataTable.new(caption: "Empty", header: [] of UI::Table::RawText, rows: [] of Array(UI::Table::Cell), page_size: 0)
      end
      codes(error).should eq [
        {"data_table.header.empty", "header"},
        {"data_table.rows.empty", "rows"},
        {"data_table.page_size.out_of_range", "page_size"},
      ]
    end

    it "rejects an empty caption and a row header index outside the columns as library policy" do
      [-1, 2].each do |index|
        error = expect_raises(UI::ValidationError) do
          UI::Blocks::DataTable.new(caption: "", header: {raw("A"), raw("B")}, rows: { {raw("a"), raw("b")} }, row_header_column_index: index)
        end
        codes(error).should eq [
          {"data_table.caption.empty", "caption"},
          {"data_table.row_header_column_index.out_of_range", "row_header_column_index"},
        ]
      end
    end
  end
end
