require "http"
require "log"

# Serves the two OAuth installation routes with a `Slack::AuthHandler`.
#
# `GET install_path` redirects the browser to Slack. `GET callback_path`
# exchanges the code and redirects to the path that *on_installed* returns, or
# to the path that *on_failed* returns when the handler rejects the callback.
# Other paths and methods go to the next handler.
#
# The application supplies the trusted session binding for each request and
# persists the returned installation in *on_installed*. When *session_binding*
# returns `nil`, both routes answer 400 and do not call the handler. See
# `documentation/authentication.md`.
#
# ```
# routes = Slack::App::InstallRoutes.new(handler,
#   session_binding: ->(context : HTTP::Server::Context) : Slack::Auth::Secret? {
#     MySessions.id(context).try { |id| Slack::Auth::Secret.new(id) }
#   },
#   on_installed: ->(response : Slack::AuthResponse) : String {
#     store.store(response.installation_key, response.installation_patch(clock), nil)
#     "/installed"
#   },
#   on_failed: ->(error : Exception) : String { "/install/failed" })
# HTTP::Server.new([routes, Slack::App::HttpReceiver.new(app, verifier)])
# ```
class Slack::App::InstallRoutes
  include HTTP::Handler

  Log = ::Log.for("slack.app.install")

  alias SessionBinding = Proc(HTTP::Server::Context, Slack::Auth::Secret?)
  alias Installed = Proc(Slack::AuthResponse, String)
  alias Failed = Proc(Exception, String)

  def initialize(@handler : Slack::AuthHandler, *, @session_binding : SessionBinding,
                 @on_installed : Installed, @on_failed : Failed,
                 @install_path : String = "/slack/install", @callback_path : String = "/slack/oauth_redirect")
  end

  def call(context : HTTP::Server::Context) : Nil
    request = context.request
    return call_next(context) unless request.method == "GET" && {@install_path, @callback_path}.includes?(request.path)

    binding = @session_binding.call(context)
    return context.response.status = :bad_request unless binding

    location = request.path == @install_path ? @handler.redirect_url(binding) : callback_target(request, binding)
    context.response.headers["Location"] = location
    context.response.status = :found
  end

  private def callback_target(request : HTTP::Request, binding : Slack::Auth::Secret) : String
    response = begin
      @handler.authenticate_user(request, binding)
    rescue error : Slack::Auth::ContractError | Slack::Auth::ResponseError
      # The request, state, and code must not reach the log.
      Log.warn { "Installation failed: #{error.class}" }
      return @on_failed.call(error)
    end
    @on_installed.call(response)
  end
end
