# The first frame on a new Socket Mode connection. Slack sends it when the
# connection is ready to deliver envelopes.
struct Slack::SocketMode::Hello
  # The number of open connections for the app, this one included. Slack
  # allows up to 10.
  getter num_connections : Int32
  # Approximate seconds until Slack asks the app to refresh this connection,
  # from `debug_info`. Slack labels it debug information, so it can be absent.
  getter approximate_connection_time : Int32?
  # The app that owns the connection, from `connection_info`.
  getter app_id : String

  def initialize(@num_connections : Int32, @approximate_connection_time : Int32?, @app_id : String)
  end
end
