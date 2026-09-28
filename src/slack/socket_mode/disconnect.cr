# A frame that tells the app that Slack will close this connection.
struct Slack::SocketMode::Disconnect
  enum Reason
    # The connection closes in about 10 seconds.
    Warning
    # The connection closes soon; open a new one to continue.
    RefreshRequested
    # Socket Mode is off for the app; do not reconnect.
    LinkDisabled
    # A reason that Slack does not document; see `#reason_name`.
    Unknown
  end

  getter reason : Reason
  # The reason exactly as Slack sent it.
  getter reason_name : String
  # Slack diagnostics, such as the host. The shape is not documented.
  getter debug_info : JSON::Any?

  def initialize(@reason_name : String, @debug_info : JSON::Any? = nil)
    @reason = case @reason_name
              when "warning"           then Reason::Warning
              when "refresh_requested" then Reason::RefreshRequested
              when "link_disabled"     then Reason::LinkDisabled
              else                          Reason::Unknown
              end
  end
end
