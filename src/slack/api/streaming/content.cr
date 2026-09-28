# :nodoc:
# The `markdown_text` or `chunks` content of one streaming request.
# Request constructors choose one kind, so a request cannot send both.
struct Slack::Api::Streaming::Content
  MARKDOWN_TEXT_MAX_SIZE = 12_000

  @value : (String | Array(Chunk))?

  def initialize
    @value = nil
  end

  def initialize(markdown_text : String)
    @value = markdown_text
  end

  def initialize(chunks : Enumerable(T)) forall T
    copied = [] of Chunk
    chunks.each { |chunk| append(copied, chunk) }
    @value = copied
  end

  def validate(prefix : String) : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    case value = @value
    in String
      if value.empty?
        issues << Slack::UI::ValidationIssue.new("#{prefix}.markdown_text.empty", "markdown_text", "Markdown text must not be empty.")
      elsif value.size > MARKDOWN_TEXT_MAX_SIZE
        issues << Slack::UI::ValidationIssue.new("#{prefix}.markdown_text.too_long", "markdown_text",
          "Markdown text cannot be longer than #{MARKDOWN_TEXT_MAX_SIZE} characters.")
      end
    in Array(Chunk)
      if value.empty?
        issues << Slack::UI::ValidationIssue.new("#{prefix}.chunks.empty", "chunks", "Chunks must not be empty.")
      end
    in Nil
    end
    issues
  end

  def fields(json : JSON::Builder) : Nil
    case value = @value
    in String       then json.field "markdown_text", value
    in Array(Chunk) then json.field "chunks", value
    in Nil
    end
  end

  private def append(chunks : Array(Chunk), chunk : Chunk) : Nil
    chunks << chunk
  end
end
