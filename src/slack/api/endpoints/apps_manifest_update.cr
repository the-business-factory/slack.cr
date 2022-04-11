class Slack::Api::AppsManifestUpdate < Slack::Api::Base
  properties_with_initializer token : String, app_id : String

  # Eventually, manifests should be converted into a strongly typed object
  # specifying allowable values, validations, etc.
  #
  # For now, this is a bit of a "power user" feature and manifest formats can be
  # learned about at https://api.slack.com/reference/manifests.
  properties_with_initializer manifest : JSON::Any

  def content_type : ContentTypes
    ContentTypes::JSON
  end

  def base_url
    "https://slack.com/api/apps.manifest.update"
  end

  def call : Slack::Models::AppsManifestUpdateResponse
    result = HTTP::Client.post(url: base_url, headers: headers, body: to_json)
    Slack::Models::AppsManifestUpdateResponse.from_json(result.body)
  end
end
