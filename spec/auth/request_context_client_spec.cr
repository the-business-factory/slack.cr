require "../spec_helper"
require "../support/request_authorizer/fakes"

describe "Slack::Auth::RequestContext#client" do
  it "reads the fenced credential only after local validation and blocks a replaced grant" do
    store = RequestAuthorizerSupport::Store.new(RequestAuthorizerSupport::Clock.new)
    transport = RequestAuthorizerSupport::Transport.new
    key = RequestAuthorizerSupport.workspace_key
    record = RequestAuthorizerSupport.seed(store, key)
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
    context = Slack::Auth::RequestContext.new(query, store.acquire(query), store, transport,
      Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/")))
    message = Slack::UI.message(fallback_text: "Done", &.divider)

    expect_raises(Slack::UI::ValidationError) do
      context.client.call(Slack::Api::ChatPostMessage.new(channel: "", message: message))
    end
    store.dispatch_count.should eq 0

    transport.enqueue(%({"ok":true,"channel":"C1","ts":"1710000000.000001"}))
    context.client.call(Slack::Api::ChatDelete.new(channel: "C1", ts: "1710000000.000001"))
    store.dispatch_count.should eq 1
    transport.requests.first.headers["Authorization"].should eq "Bearer bot-token"

    store.store(key, Slack::Auth::InstallationPatch.new(
      bot: RequestAuthorizerSupport.grant("U_BOT", "replacement-token")), record.version)
    expect_raises(Slack::Auth::ContractError, "Conflict") do
      context.client.call(Slack::Api::ChatDelete.new(channel: "C1", ts: "1710000000.000001"))
    end
    transport.requests.size.should eq 1
  end
end
