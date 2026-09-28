# The channel and timestamp of a streamed message that `Client#start_stream` started.
#
# Each method makes one Web API call through *client*. The stream does not buffer
# text, start fibers, or stop itself; call `stop` when the answer is complete.
#
# ```
# stream = client.start_stream(Slack::Api::ChatStartStream.new(channel: "D123", markdown_text: "Checking"))
# stream.append(client, markdown_text: " the report...")
# stream.stop(client, session_status: Slack::Api::Streaming::SessionStatus::Closed)
# ```
struct Slack::Api::MessageStream
  getter channel : String
  getter ts : String

  def initialize(@channel : String, @ts : String)
  end

  # Adds markdown text to the message.
  def append(client : Client, *, markdown_text : String) : Models::Chat::StreamMessage
    client.call(ChatAppendStream.new(channel: @channel, ts: @ts, markdown_text: markdown_text))
  end

  # Adds chunks to the message.
  def append(client : Client, *, chunks : Enumerable) : Models::Chat::StreamMessage
    client.call(ChatAppendStream.new(channel: @channel, ts: @ts, chunks: chunks))
  end

  # Finishes the message with optional markdown text, final *blocks*, and *session_status*.
  def stop(client : Client, *, markdown_text : String? = nil, blocks : Enumerable? = nil,
           session_status : Streaming::SessionStatus? = nil) : Models::Chat::StreamMessage
    client.call(ChatStopStream.new(channel: @channel, ts: @ts, markdown_text: markdown_text,
      blocks: blocks, session_status: session_status))
  end

  # Finishes the message with chunks, optional final *blocks*, and *session_status*.
  def stop(client : Client, *, chunks : Enumerable, blocks : Enumerable? = nil,
           session_status : Streaming::SessionStatus? = nil) : Models::Chat::StreamMessage
    client.call(ChatStopStream.new(channel: @channel, ts: @ts, chunks: chunks,
      blocks: blocks, session_status: session_status))
  end
end
