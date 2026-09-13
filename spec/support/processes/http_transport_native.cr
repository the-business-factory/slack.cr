require "spec"
require "compress/deflate"
require "compress/gzip"
require "../../../src/slack"
require "../auth/one_shot_server"
require "../auth/host_cases"

{% if @top_level.has_constant?(:WebMock) %}
  {% raise "Native transport specs must not load WebMock" %}
{% end %}

private CA_FILE             = File.expand_path("../../fixtures/auth_transport/ca.pem", __DIR__)
private CERT_FILE           = File.expand_path("../../fixtures/auth_transport/server.pem", __DIR__)
private KEY_FILE            = File.expand_path("../../fixtures/auth_transport/server-key.pem", __DIR__)
private OAUTH_RESPONSE_FILE = File.expand_path("../../fixtures/oauth_responses/bot_workspace.json", __DIR__)

private def transport(options : Slack::Auth::TransportOptions = Slack::Auth::TransportOptions.new) : Slack::Auth::Transport
  Slack::Auth::HTTPTransportFactory.new.build(options)
end

private def request(uri : String, method : String = "GET", body : String? = nil) : Slack::Auth::TransportRequest
  Slack::Auth::TransportRequest.new(method, URI.parse(uri),
    HTTP::Headers{"Authorization" => "Bearer synthetic-token"}, body)
end

private def tls_context : OpenSSL::SSL::Context::Server
  context = OpenSSL::SSL::Context::Server.new
  context.certificate_chain = CERT_FILE
  context.private_key = KEY_FILE
  context
end

private def error_code(expected : Slack::Auth::ErrorCode, & : ->) : Nil
  error = expect_raises(Slack::Auth::ContractError) { yield }
  error.code.should eq(expected)
  error.cause.should be_nil
  error.message.to_s.should_not contain("synthetic-token")
end

private def compressed_body(encoding : String, body : String) : String
  output = IO::Memory.new
  case encoding
  when "gzip"
    Compress::Gzip::Writer.open(output) { |writer| writer << body }
  when "deflate"
    Compress::Deflate::Writer.open(output) { |writer| writer << body }
  else
    raise "Unsupported test encoding"
  end
  output.to_s
end

private def assert_compressed_response(encoding : String, header_value : String = encoding) : Nil
  encoded = compressed_body(encoding, "complete compressed response")
  server = AuthSupport::OneShotServer.new do |socket|
    incoming = AuthSupport.read_request(socket)
    incoming.headers["Accept-Encoding"].should contain(encoding)
    socket << "HTTP/1.1 200 OK\r\nContent-Encoding: #{header_value}\r\nContent-Length: #{encoded.bytesize}\r\nConnection: close\r\n\r\n"
    socket << encoded
    socket.flush
  end

  response = transport.execute(request("http://127.0.0.1:#{server.port}/#{encoding}"))
  response.body.should eq("complete compressed response")
  response.headers["Content-Encoding"]?.should be_nil
  response.headers["Content-Length"]?.should be_nil
  server.wait
ensure
  server.try(&.close)
end

describe Slack::Auth::HTTPTransport do
  it "returns status, headers, and body from one exact POST" do
    received = Channel(NamedTuple(method: String, resource: String, authorization: String, body: String)).new(1)
    server = AuthSupport::OneShotServer.new do |socket|
      incoming = AuthSupport.read_request(socket)
      received.send({
        method:        incoming.method,
        resource:      incoming.resource,
        authorization: incoming.headers["Authorization"],
        body:          incoming.body.try(&.gets_to_end) || "",
      })
      AuthSupport.respond(socket, 201, "created", HTTP::Headers{"X-Fixture" => "one"})
    end

    response = transport.execute(request("http://127.0.0.1:#{server.port}/api%20test?value=a%2Bb", "POST", "payload"))
    response.status.should eq(201)
    response.headers["X-Fixture"].should eq("one")
    response.body.should eq("created")

    incoming = received.receive
    incoming[:method].should eq("POST")
    incoming[:resource].should eq("/api%20test?value=a%2Bb")
    incoming[:authorization].should eq("Bearer synthetic-token")
    incoming[:body].should eq("payload")
    server.wait
  ensure
    server.try(&.close)
  end

  it "reads the final response after informational response headers" do
    server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 103 Early Hints\r\nLink: </asset.css>; rel=preload\r\n\r\n"
      socket << "HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nfinal"
      socket.flush
    end

    response = transport.execute(request("http://127.0.0.1:#{server.port}/informational"))
    response.status.should eq(200)
    response.body.should eq("final")
    server.wait
  ensure
    server.try(&.close)
  end

  it "connects to the explicit IPv6 loopback address with one-bracket authority" do
    host_header = Channel(String).new(1)
    server = AuthSupport::OneShotServer.new("::1") do |socket|
      incoming = AuthSupport.read_request(socket)
      host_header.send(incoming.headers["Host"])
      AuthSupport.respond(socket, 200, "ipv6")
    end

    transport.execute(request("http://[::1]:#{server.port}/ipv6")).body.should eq("ipv6")
    host_header.receive.should eq("[::1]:#{server.port}")
    server.wait
  ensure
    server.try(&.close)
  end

  it "returns redirects, rate limits, and server errors without following or retrying" do
    {
      302 => HTTP::Headers{"Location" => "http://127.0.0.1:1/unreachable"},
      429 => HTTP::Headers{"Retry-After" => "2"},
      503 => HTTP::Headers.new,
    }.each do |status, headers|
      count = Channel(Int32).new(1)
      server = AuthSupport::OneShotServer.new do |socket|
        AuthSupport.read_request(socket)
        count.send(1)
        AuthSupport.respond(socket, status, "fixture", headers)
      end

      response = transport.execute(request("http://127.0.0.1:#{server.port}/once"))
      response.status.should eq(status)
      count.receive.should eq(1)
      server.wait
    ensure
      server.try(&.close)
    end
  end

  it "distinguishes definitely-unsent refusal from post-send EOF and partial responses" do
    refused = TCPServer.new("127.0.0.1", 0)
    refused_port = refused.local_address.port
    refused.close
    error_code(Slack::Auth::ErrorCode::TransportFailure) do
      transport.execute(request("http://127.0.0.1:#{refused_port}/never-sent"))
    end

    eof_server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
    end
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport.execute(request("http://127.0.0.1:#{eof_server.port}/sent"))
    end
    eof_server.wait

    partial_server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nContent-Length: 10\r\nConnection: close\r\n\r\nshort"
      socket.flush
    end
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport.execute(request("http://127.0.0.1:#{partial_server.port}/partial"))
    end
    partial_server.wait
  ensure
    eof_server.try(&.close)
    partial_server.try(&.close)
  end

  it "decodes an independently generated HTTP zlib fixture and rejects incomplete or corrupt streams" do
    encoded = File.read(File.expand_path("../../fixtures/auth_transport/http-deflate.bin", __DIR__))
    server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket).headers["Accept-Encoding"].should contain("deflate")
      AuthSupport.respond(socket, 200, encoded, HTTP::Headers{"Content-Encoding" => "DeFlAtE"})
    end
    response = transport.execute(request("http://127.0.0.1:#{server.port}/zlib"))
    response.body.should eq(%({"ok":true}))
    response.headers["Content-Encoding"]?.should be_nil
    response.headers["Content-Length"]?.should be_nil
    server.wait

    # Every truncation includes an exact HTTP length, so the decoder must also
    # detect incomplete headers, compressed data, and the Adler-32 trailer.
    bodies = (0...encoded.bytesize).map { |length| encoded.byte_slice(0, length) }
    bodies << encoded.byte_slice(0, encoded.bytesize - 1) + "\0"
    bodies.each do |body|
      broken = AuthSupport::OneShotServer.new do |socket|
        AuthSupport.read_request(socket)
        AuthSupport.respond(socket, 200, body, HTTP::Headers{"Content-Encoding" => "deflate"})
      end
      error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
        transport.execute(request("http://127.0.0.1:#{broken.port}/broken-zlib"))
      end
      broken.wait
    ensure
      broken.try(&.close)
    end

    short = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nContent-Encoding: deflate\r\nContent-Length: #{encoded.bytesize + 1}\r\n\r\n#{encoded}"
      socket.flush
    end
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport.execute(request("http://127.0.0.1:#{short.port}/short-zlib"))
    end
    short.wait
  ensure
    server.try(&.close)
    short.try(&.close)
  end

  it "validates compressed wire length before returning the decoded body" do
    assert_compressed_response("gzip")
    assert_compressed_response("deflate")

    encoded = compressed_body("gzip", "truncated compressed response")
    truncated = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: #{encoded.bytesize + 4}\r\nConnection: close\r\n\r\n"
      socket << encoded
      socket.flush
    end
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport.execute(request("http://127.0.0.1:#{truncated.port}/truncated-gzip"))
    end
    truncated.wait
  ensure
    truncated.try(&.close)
  end

  it "validates representation bytes before applying the response charset" do
    complete = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=ISO-8859-1\r\nContent-Length: 1\r\nConnection: close\r\n\r\n\xE9"
      socket.flush
    end
    response = transport.execute(request("http://127.0.0.1:#{complete.port}/complete-latin1"))
    response.body.should eq("é")
    complete.wait

    truncated = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=ISO-8859-1\r\nContent-Length: 2\r\nConnection: close\r\n\r\n\xE9"
      socket.flush
    end
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport.execute(request("http://127.0.0.1:#{truncated.port}/truncated-latin1"))
    end
    truncated.wait
  ensure
    complete.try(&.close)
    truncated.try(&.close)
  end

  it "applies content decoding before charset decoding" do
    json = %({"ok":true})
    encoded = compressed_body("gzip", json)
    server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nContent-Encoding: gzip\r\nContent-Length: #{encoded.bytesize}\r\nConnection: close\r\n\r\n"
      socket << encoded
      socket.flush
    end

    response = transport.execute(request("http://127.0.0.1:#{server.port}/gzip-json"))
    response.body.should eq(json)
    response.headers["Content-Encoding"]?.should be_nil
    response.headers["Content-Length"]?.should be_nil
    server.wait
  ensure
    server.try(&.close)
  end

  it "handles response coding tokens case-insensitively with optional whitespace" do
    assert_compressed_response("gzip", "GZip \t")
    assert_compressed_response("deflate", "DeFlAtE \t")

    chunked = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nTransfer-Encoding: Chunked \t\r\nConnection: close\r\n\r\n2\r\nOK\r\n0\r\n\r\n"
      socket.flush
    end
    transport.execute(request("http://127.0.0.1:#{chunked.port}/mixed-case-chunked")).body.should eq("OK")
    chunked.wait

    unsupported = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip, Chunked\r\nConnection: close\r\n\r\n2\r\nOK\r\n0\r\n\r\n"
      socket.flush
    end
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport.execute(request("http://127.0.0.1:#{unsupported.port}/unsupported-transfer-coding"))
    end
    unsupported.wait
  ensure
    chunked.try(&.close)
    unsupported.try(&.close)
  end

  it "reads complete chunked and EOF-delimited responses and rejects incomplete chunks" do
    encoded = compressed_body("gzip", "chunked compressed response")
    chunked = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Encoding: gzip\r\nContent-Length: 99\r\nConnection: close\r\n\r\n"
      socket << encoded.bytesize.to_s(16) << "\r\n" << encoded << "\r\n0\r\n\r\n"
      socket.flush
    end
    transport.execute(request("http://127.0.0.1:#{chunked.port}/chunked")).body.should eq("chunked compressed response")
    chunked.wait

    eof_delimited = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\neof-delimited"
      socket.flush
    end
    transport.execute(request("http://127.0.0.1:#{eof_delimited.port}/eof")).body.should eq("eof-delimited")
    eof_delimited.wait

    incomplete = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nxx"
      socket.flush
    end
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport.execute(request("http://127.0.0.1:#{incomplete.port}/incomplete-chunk"))
    end
    incomplete.wait
  ensure
    chunked.try(&.close)
    eof_delimited.try(&.close)
    incomplete.try(&.close)
  end

  it "does not require representation length bytes for bodyless responses" do
    head_server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 200 Bodyless\r\nContent-Encoding: gzip\r\nContent-Length: 42\r\nConnection: close\r\n\r\n"
      socket.flush
    end

    head_response = transport.execute(request("http://127.0.0.1:#{head_server.port}/bodyless", "HEAD"))
    head_response.status.should eq(200)
    head_response.body.should be_empty
    head_response.headers["Content-Encoding"].should eq("gzip")
    head_response.headers["Content-Length"].should eq("42")
    head_server.wait

    no_content_server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 204 No Content\r\nContent-Encoding: gzip\r\nConnection: close\r\n\r\n"
      socket.flush
    end
    no_content_response = transport.execute(request("http://127.0.0.1:#{no_content_server.port}/bodyless"))
    no_content_response.status.should eq(204)
    no_content_response.body.should be_empty
    no_content_response.headers["Content-Encoding"].should eq("gzip")
    no_content_server.wait

    not_modified_server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      socket << "HTTP/1.1 304 Not Modified\r\nContent-Length: 42\r\nETag: synthetic\r\nConnection: close\r\n\r\n"
      socket.flush
    end
    not_modified_response = transport.execute(request("http://127.0.0.1:#{not_modified_server.port}/bodyless"))
    not_modified_response.status.should eq(304)
    not_modified_response.body.should be_empty
    not_modified_response.headers["Content-Length"].should eq("42")
    not_modified_response.headers["ETag"].should eq("synthetic")
    not_modified_server.wait
  ensure
    head_server.try(&.close)
    no_content_server.try(&.close)
    not_modified_server.try(&.close)
  end

  it "applies the configured read timeout after sending" do
    release = Channel(Nil).new(1)
    server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      select
      when release.receive
      when timeout(1.second)
      end
    end
    options = Slack::Auth::TransportOptions.new(read_timeout: 30.milliseconds)

    started = Time.instant
    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport(options).execute(request("http://127.0.0.1:#{server.port}/timeout"))
    end
    (Time.instant - started).should be < 500.milliseconds
    release.send(nil)
    server.wait
  ensure
    server.try(&.close)
  end

  it "closes the connection after reading a response" do
    closed = Channel(Bool).new(1)
    server = AuthSupport::OneShotServer.new do |socket|
      AuthSupport.read_request(socket)
      AuthSupport.respond(socket, 200, "complete")
      buffer = Bytes.new(1)
      closed.send(socket.read(buffer) == 0)
    end

    transport.execute(request("http://127.0.0.1:#{server.port}/cleanup")).body.should eq("complete")
    select
    when value = closed.receive
      value.should be_true
    when timeout(1.second)
      fail("Transport did not close the connection")
    end
    server.wait
  ensure
    server.try(&.close)
  end

  it "verifies TLS and trusts only the configured synthetic CA" do
    server = AuthSupport::OneShotServer.new do |socket|
      tls = OpenSSL::SSL::Socket::Server.new(socket, tls_context, sync_close: false)
      AuthSupport.read_request(tls)
      AuthSupport.respond(tls, 200, "trusted")
      tls.close
    end
    options = Slack::Auth::TransportOptions.new(ca_file: CA_FILE)
    transport(options).execute(request("https://127.0.0.1:#{server.port}/tls")).body.should eq("trusted")
    server.wait

    untrusted = AuthSupport::OneShotServer.new do |socket|
      tls = OpenSSL::SSL::Socket::Server.new(socket, tls_context, sync_close: false)
      AuthSupport.read_request(tls)
    ensure
      tls.try(&.close)
    end
    error_code(Slack::Auth::ErrorCode::TransportFailure) do
      transport.execute(request("https://127.0.0.1:#{untrusted.port}/untrusted"))
    end
    untrusted.wait(allow_error: true)
  ensure
    server.try(&.close)
    untrusted.try(&.close)
  end

  it "exchanges a session-bound OAuth callback through the concrete TLS transport once" do
    received = Channel(NamedTuple(method: String, resource: String, content_type: String, body: String)).new(1)
    server = AuthSupport::OneShotServer.new do |socket|
      tls = OpenSSL::SSL::Socket::Server.new(socket, tls_context, sync_close: false)
      incoming = AuthSupport.read_request(tls)
      received.send({
        method:       incoming.method,
        resource:     incoming.resource,
        content_type: incoming.headers["Content-Type"],
        body:         incoming.body.try(&.gets_to_end) || raise("Missing OAuth form"),
      })
      AuthSupport.respond(tls, 200, File.read(OAUTH_RESPONSE_FILE),
        HTTP::Headers{"Content-Type" => "application/json"})
      tls.close
    end

    configuration = Slack::Auth::OAuthConfiguration.new(
      URI.parse("https://auth.example.test/oauth/v2/authorize"),
      URI.parse("https://127.0.0.1:#{server.port}/oauth/token"),
      "synthetic-client",
      Slack::Auth::Secret.new("synthetic-secret"),
      URI.parse("https://app.example.test/install/callback?tenant=one")
    )
    state_store = Slack::Auth::MemoryStateStore.new
    oauth_transport = Slack::Auth::HTTPTransportFactory.new.build(
      Slack::Auth::TransportOptions.new(ca_file: CA_FILE)
    )
    handler = Slack::AuthHandler.new(configuration, state_store, oauth_transport,
      bot_scopes: ["commands"], user_scopes: ["users:read"])
    session = Slack::Auth::Secret.new("synthetic-browser-session")

    error_code(Slack::Auth::ErrorCode::InvalidState) do
      handler.authenticate_user(HTTP::Request.new("GET", "/callback?code=missing-state"), session)
    end
    error_code(Slack::Auth::ErrorCode::InvalidState) do
      handler.authenticate_user(HTTP::Request.new("GET", "/callback?state=unknown&code=invalid-state"), session)
    end

    missing_code_state = URI.parse(handler.redirect_url(session)).query_params["state"]
    missing_code_callback = HTTP::Request.new("GET", "/callback?#{URI::Params.encode({"state" => missing_code_state})}")
    error_code(Slack::Auth::ErrorCode::InvalidResponse) do
      handler.authenticate_user(missing_code_callback, session)
    end
    error_code(Slack::Auth::ErrorCode::InvalidState) do
      handler.authenticate_user(missing_code_callback, session)
    end

    valid_state = URI.parse(handler.redirect_url(session)).query_params["state"]
    callback_query = URI::Params.encode({"state" => valid_state, "code" => "synthetic+code&value"})
    callback = HTTP::Request.new("GET", "/callback?#{callback_query}")
    error_code(Slack::Auth::ErrorCode::InvalidState) do
      handler.authenticate_user(callback, Slack::Auth::Secret.new("wrong-browser-session"))
    end

    installation = handler.authenticate_user(callback, session)
    installation.team.try(&.id).should eq("TTEAM")
    server.wait

    incoming = received.receive
    incoming[:method].should eq("POST")
    incoming[:resource].should eq("/oauth/token")
    incoming[:content_type].should eq("application/x-www-form-urlencoded")
    form = URI::Params.parse(incoming[:body])
    form["client_id"].should eq("synthetic-client")
    form["client_secret"].should eq("synthetic-secret")
    form["code"].should eq("synthetic+code&value")
    form["redirect_uri"].should eq("https://app.example.test/install/callback?tenant=one")

    error_code(Slack::Auth::ErrorCode::InvalidState) do
      handler.authenticate_user(callback, session)
    end
  ensure
    server.try(&.close)
  end

  it "keeps malformed TLS response and cleanup failures typed and redacted" do
    server = AuthSupport::OneShotServer.new do |socket|
      tls = OpenSSL::SSL::Socket::Server.new(socket, tls_context, sync_close: false)
      AuthSupport.read_request(tls)
      socket << "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
      socket.flush
    end
    options = Slack::Auth::TransportOptions.new(ca_file: CA_FILE)

    error_code(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
      transport(options).execute(request("https://127.0.0.1:#{server.port}/malformed-tls"))
    end
    server.wait
  ensure
    server.try(&.close)
  end

  it "routes plaintext loopback requests through an explicit HTTP proxy" do
    received = Channel(HTTP::Request).new(1)
    proxy = AuthSupport::OneShotServer.new do |socket|
      incoming = AuthSupport.read_request(socket)
      received.send(incoming)
      AuthSupport.respond(socket, 200, "proxied")
    end
    proxy_uri = URI.parse("http://proxy-user:proxy-pass@127.0.0.1:#{proxy.port}")
    options = Slack::Auth::TransportOptions.new(proxy_uri: proxy_uri)

    response = transport(options).execute(request("http://127.0.0.1:9/api/proxied?x=a%2Bb"))
    response.body.should eq("proxied")
    incoming = received.receive
    incoming.resource.should eq("http://127.0.0.1:9/api/proxied?x=a%2Bb")
    incoming.headers["Proxy-Authorization"].should eq("Basic cHJveHktdXNlcjpwcm94eS1wYXNz")
    incoming.headers["Authorization"].should eq("Bearer synthetic-token")
    proxy.wait
  ensure
    proxy.try(&.close)
  end

  it "uses CONNECT for HTTPS and does not send proxy authorization through the tunnel" do
    connect_request = Channel(HTTP::Request).new(1)
    tunneled_request = Channel(HTTP::Request).new(1)
    proxy = AuthSupport::OneShotServer.new do |socket|
      connect = AuthSupport.read_request(socket)
      connect_request.send(connect)
      socket << "HTTP/1.1 200 Connection Established\r\n\r\n"
      socket.flush

      tls = OpenSSL::SSL::Socket::Server.new(socket, tls_context, sync_close: false)
      tunneled = AuthSupport.read_request(tls)
      tunneled_request.send(tunneled)
      AuthSupport.respond(tls, 200, "tunneled")
      tls.close
    end
    proxy_uri = URI.parse("http://proxy-user:proxy-pass@127.0.0.1:#{proxy.port}")
    options = Slack::Auth::TransportOptions.new(proxy_uri: proxy_uri, ca_file: CA_FILE)

    response = transport(options).execute(request("https://127.0.0.1/api/token"))
    response.body.should eq("tunneled")
    connect = connect_request.receive
    connect.method.should eq("CONNECT")
    connect.resource.should eq("127.0.0.1:443")
    connect.headers["Proxy-Authorization"].should eq("Basic cHJveHktdXNlcjpwcm94eS1wYXNz")
    connect.headers["Authorization"]?.should be_nil
    tunneled = tunneled_request.receive
    tunneled.resource.should eq("/api/token")
    tunneled.headers["Proxy-Authorization"]?.should be_nil
    tunneled.headers["Authorization"].should eq("Bearer synthetic-token")
    proxy.wait
  ensure
    proxy.try(&.close)
  end

  it "rejects invalid destination hosts before direct or proxy connections" do
    listener = TCPServer.new("127.0.0.1", 0)
    port = listener.local_address.port
    [nil, URI.parse("http://127.0.0.1:#{port}")].each do |proxy|
      client = transport(Slack::Auth::TransportOptions.new(proxy_uri: proxy, connect_timeout: 25.milliseconds))
      AuthSupport::INVALID_HOSTS.each do |host|
        uri = URI.new(scheme: "https", host: host, port: port, path: "/canary-secret")
        error_code(Slack::Auth::ErrorCode::InvalidConfiguration) do
          client.execute(Slack::Auth::TransportRequest.new("POST", uri, body: "synthetic-token"))
        end
      end
      ["bad host", "127.0.0.1%00canary-secret", "bad%GGhost", "[::1]suffix"].each do |host|
        error_code(Slack::Auth::ErrorCode::InvalidConfiguration) do
          client.execute(request("https://#{host}:#{port}/canary-secret"))
        end
      end
    end
    listener.read_timeout = 25.milliseconds
    expect_raises(IO::TimeoutError) { listener.accept }
  ensure
    listener.try(&.close)
  end

  it "rejects invalid proxy hosts before connections and preserves valid proxy authorities" do
    listener = TCPServer.new("127.0.0.1", 0)
    port = listener.local_address.port
    AuthSupport::INVALID_HOSTS.each do |host|
      proxy = URI.new(scheme: "http", host: host, port: port, user: "user", password: "canary-secret")
      error_code(Slack::Auth::ErrorCode::InvalidConfiguration) do
        transport(Slack::Auth::TransportOptions.new(proxy_uri: proxy))
          .execute(request("http://127.0.0.1:#{port}/canary-secret"))
      end
    end
    ["bad host", "127.0.0.1%00canary-secret", "bad%GGhost", "[::1]suffix"].each do |host|
      error_code(Slack::Auth::ErrorCode::InvalidConfiguration) do
        transport(Slack::Auth::TransportOptions.new(proxy_uri: URI.parse("http://#{host}:#{port}")))
          .execute(request("http://127.0.0.1:#{port}/canary-secret"))
      end
    end
    listener.read_timeout = 25.milliseconds
    expect_raises(IO::TimeoutError) { listener.accept }

    AuthSupport::VALID_HOSTS.each do |host|
      proxy = Slack::Auth::ProxyConfiguration.new(URI.parse("http://user:pass@#{host}:8080/"))
      proxy.host.should eq(host)
      proxy.port.should eq(8080)
      proxy.authorization.should eq("Basic dXNlcjpwYXNz")
    end
  ensure
    listener.try(&.close)
  end

  it "rejects invalid timeout, CA, proxy, URI, and method settings safely" do
    invalid_options = [
      Slack::Auth::TransportOptions.new(connect_timeout: Time::Span::ZERO),
      Slack::Auth::TransportOptions.new(read_timeout: -1.second),
      Slack::Auth::TransportOptions.new(write_timeout: Time::Span::ZERO),
      Slack::Auth::TransportOptions.new(ca_file: "canary-secret-missing.pem"),
      Slack::Auth::TransportOptions.new(proxy_uri: URI.parse("https://canary-secret.example")),
      Slack::Auth::TransportOptions.new(proxy_uri: URI.parse("http://user@canary-secret.example")),
    ]
    invalid_options.each do |options|
      error_code(Slack::Auth::ErrorCode::InvalidConfiguration) { transport(options) }
    end

    invalid_requests = [
      request("http://canary-secret.example/api"),
      request("https://user:canary-secret@example.test/api"),
      request("https://example.test/api#canary-secret"),
      request("ftp://example.test/api"),
      request("https:///api"),
      request("https://example.test/api", "BAD METHOD"),
      Slack::Auth::TransportRequest.new("GET",
        URI.new(scheme: "http", host: "127.0.0.1", port: 1, path: "/canary-secret path")),
      Slack::Auth::TransportRequest.new("GET",
        URI.new(scheme: "http", host: "127.0.0.1", port: 1, path: "/api", query: "value=one\r\ncanary-secret")),
      Slack::Auth::TransportRequest.new("GET",
        URI.new(scheme: "http", host: "127.0.0.1", port: 1, path: "/canary-secret%2")),
      Slack::Auth::TransportRequest.new("GET",
        URI.new(scheme: "http", host: "127.0.0.1", port: 1, path: "/api", query: "value=%GGcanary-secret")),
    ]
    invalid_requests.each do |invalid_request|
      error_code(Slack::Auth::ErrorCode::InvalidConfiguration) { transport.execute(invalid_request) }
    end
  end
end
