require "spec"
require "lucky_env"
require "../src/slack"
require "vcr"

VCR.configure do |settings|
  settings.filter_sensitive_data["Authorization"] = "Bearer <TOKEN>"
end

LuckyEnv.load(".env.test")

# .env is not included in source control, but can be used locally to override
# ENV vars used for API calls (Slack Team auth tokens, etc).
LuckyEnv.load(".env") if File.exists?(".env")
