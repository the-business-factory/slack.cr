require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Builds a table from application records and posts it. Slack also limits the
# characters in all cells of a message to 10,000; split large reports into
# separate messages.
module OfflineTableExample
  alias UI = Slack::UI
  alias RT = UI::RichText

  record Region, name : String, owner_id : String, deals : Int32, revenue : Float64

  REGIONS = [
    Region.new("EMEA", "U-EMEA", 12, 1_250_000.0),
    Region.new("APAC", "U-APAC", 7, 980_000.5),
  ]

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000300","message":{"text":"Q3 revenue by region"}}))
    end

    message = UI.message(fallback_text: "Q3 revenue by region") do |builder|
      builder.table(report_rows(REGIONS), block_id: "q3.revenue", column_settings: [
        UI::Table::ColumnSetting.new(is_wrapped: true),
        nil,
        UI::Table::ColumnSetting.new(align: UI::Table::ColumnAlignment::Right),
        UI::Table::ColumnSetting.new(align: UI::Table::ColumnAlignment::Right),
      ])
    end
    result = Slack::Api::ChatPostMessage.new(token: "xoxb-synthetic-table", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call
    output.puts "Posted #{REGIONS.size} regions to #{result.channel}/#{result.ts}"

    begin
      UI::Blocks::Table.new(rows: {Array.new(21) { |day| UI::Table::RawNumber.new(day + 1, (day + 1).to_s) }})
    rescue error : UI::ValidationError
      output.puts "Rejected before sending: #{error.issues.map(&.code).join(", ")}"
    end
    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end

  def self.report_rows(regions : Array(Region)) : Array(Array(UI::Table::Cell))
    header = [] of UI::Table::Cell
    {"Region", "Owner", "Deals", "Revenue"}.each { |title| header << UI::Table::RawText.new(title) }
    rows = [header]
    regions.each do |region|
      owner = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::User.new(region.owner_id)})})
      rows << [
        UI::Table::RawText.new(region.name), owner,
        UI::Table::RawNumber.new(region.deals, region.deals.to_s),
        UI::Table::RawNumber.new(region.revenue, "$%.2f" % region.revenue),
      ] of UI::Table::Cell
    end
    rows
  end
end
