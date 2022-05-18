class Slack::Api::AppsManifestUpdate < Slack::Api::Base
  properties_with_initializer app_id : String

  # Eventually, manifests should be converted into a strongly typed object
  # specifying allowable values, validations, etc.
  #
  # For now, this is a bit of a "power user" feature and manifest formats can be
  # learned about at https://api.slack.com/reference/manifests.
  properties_with_initializer manifest : JSON::Any

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def request_url : String
    "https://slack.com/api/apps.manifest.update"
  end

  def result : HTTP::Client::Response
    @result ||= ApiClient.new(api: self).post(body: to_json)
  end

  def call : Slack::Models::Apps::ManifestUpdate
    ResponseHandler(Models::Apps::ManifestUpdate).from_json(result.body)
  end
end
