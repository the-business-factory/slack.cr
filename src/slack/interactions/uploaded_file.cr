# A received file from file_input state. Download URLs need a token with files:read.
struct Slack::Interactions::UploadedFile
  getter raw : JSON::Any
  getter id : String
  getter name : String?
  getter title : String?
  getter mimetype : String?
  getter filetype : String?
  getter url_private : String?
  getter url_private_download : String?
  # The file size in bytes.
  getter size : Int64?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "file object", "null")
    @id = PayloadAccess.string(object["id"]?, "#{path}.id")
    @name = PayloadAccess.string?(object["name"]?, "#{path}.name")
    @title = PayloadAccess.string?(object["title"]?, "#{path}.title")
    @mimetype = PayloadAccess.string?(object["mimetype"]?, "#{path}.mimetype")
    @filetype = PayloadAccess.string?(object["filetype"]?, "#{path}.filetype")
    @url_private = PayloadAccess.string?(object["url_private"]?, "#{path}.url_private")
    @url_private_download = PayloadAccess.string?(object["url_private_download"]?, "#{path}.url_private_download")
    @size = PayloadAccess.int64?(object["size"]?, "#{path}.size")
  end
end
