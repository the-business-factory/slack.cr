require "spec"
require "lucky_env"
require "../src/slack"
require "vcr"

VCR.configure do |settings|
  settings.filter_sensitive_data["Authorization"] = "Bearer <TOKEN>"
end

LuckyEnv.load(".env.test")

# Never send live HTTP requests when a cassette is absent or no longer matches.
class HTTP::Client
  private def orig_exec_internal_single(request, implicit_compression = false) : HTTP::Client::Response?
    raise "Missing VCR recording for #{request.method} #{request.resource} in #{VCR.cassette_name.inspect}"
  end
end
