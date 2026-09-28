# One item in the `chunks` array of `chat.startStream`, `chat.appendStream`, or `chat.stopStream`.
alias Slack::Api::Streaming::Chunk = Slack::Api::Streaming::MarkdownTextChunk |
                                     Slack::Api::Streaming::TaskUpdateChunk |
                                     Slack::Api::Streaming::PlanUpdateChunk |
                                     Slack::Api::Streaming::BlocksChunk
