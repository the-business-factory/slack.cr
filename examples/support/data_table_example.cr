require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Builds a paged data table from application records and posts it. Slack also
# limits the characters in all table cells of a message to 20,000; split large
# reports into separate messages.
module OfflineDataTableExample
  alias UI = Slack::UI
  alias RT = UI::RichText

  record Ticket, key : String, assignee_id : String, age_days : Int32

  TICKETS = [
    Ticket.new("SUP-101", "U-ALEX", 3),
    Ticket.new("SUP-102", "U-SAM", 12),
    Ticket.new("SUP-103", "U-ALEX", 1),
  ]

  # Returns the JSON body that the stubbed chat.postMessage endpoint received.
  def self.run(output : IO = STDOUT) : JSON::Any
    posted : JSON::Any? = nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      posted = JSON.parse(request.body || raise "Missing posted message")
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000400","message":{"type":"message","ts":"1710000000.000400","text":"Open support tickets"}}))
    end

    header = {UI::Table::RawText.new("Ticket"), UI::Table::RawText.new("Assignee"), UI::Table::RawText.new("Age (days)")}
    message = UI.message(fallback_text: "Open support tickets") do |builder|
      builder.data_table(caption: "Open support tickets", header: header, rows: ticket_rows(TICKETS),
        page_size: 2, block_id: "support.open")
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic-data-table", transport: OfflineExample::WebMockTransport.new)
    result = client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))
    output.puts "Posted #{TICKETS.size} tickets to #{result.channel}/#{result.ts}"

    begin
      UI::Blocks::DataTable.new(caption: "Open support tickets", header: header, rows: { {UI::Table::RawText.new("SUP-104")} })
    rescue error : UI::ValidationError
      output.puts "Rejected before sending: #{error.issues.map(&.code).join(", ")}"
    end
    body = posted
    raise "chat.postMessage was not called" unless body
    body
  end

  def self.ticket_rows(tickets : Array(Ticket)) : Array(Array(UI::Table::Cell))
    tickets.map do |ticket|
      assignee = UI::Blocks::RichText.new(elements: {RT::Section.new(elements: {RT::User.new(ticket.assignee_id)})})
      [UI::Table::RawText.new(ticket.key), assignee, UI::Table::RawNumber.new(ticket.age_days, ticket.age_days.to_s)] of UI::Table::Cell
    end
  end
end
