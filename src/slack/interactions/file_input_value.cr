struct Slack::Interactions::FileInputValue
  getter raw : JSON::Any
  @files : Array(UploadedFile)?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "file_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "file_input"
      raise TypeMismatch.new("#{path}.type", "file_input", actual || "absent or null")
    end
    selection = object["files"]?
    @files = if selection && !selection.raw.nil?
               items = selection.as_a? || raise TypeMismatch.new("#{path}.files", "array or null", selection.raw.class.to_s)
               items.map_with_index { |item, index| UploadedFile.new(item, "#{path}.files[#{index}]") }
             end
  end

  def type : String
    "file_input"
  end

  def files_presence : ValuePresence
    ValuePresence.of(@raw["files"]?)
  end

  def files : Array(UploadedFile)?
    @files.try(&.dup)
  end
end
