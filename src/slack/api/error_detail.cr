module Slack::Api
  # One problem from the top-level `errors` array of a failed Web API response.
  # `apps.manifest.create`, `apps.manifest.update`, and `apps.manifest.validate`
  # report each manifest problem this way, with a JSON pointer into the manifest.
  struct ErrorDetail
    getter message : String
    getter pointer : String?

    def initialize(@message : String, @pointer : String? = nil)
    end
  end
end
