# One to ten cards in a horizontally scrolling row. Slack shows carousels in
# messages and Home tabs only, so modal unions exclude it.
struct Slack::UI::Checked::Blocks::Carousel
  include Slack::UI::Checked::ValueValidation

  ELEMENTS_MAX_SIZE = 10

  @elements : Array(Card)
  getter block_id : String?

  def initialize(elements : Enumerable(T), @block_id : String? = nil) forall T
    @elements = [] of Card
    elements.each { |card| append_card(card) }
    validate!
  end

  def type : String
    "carousel"
  end

  def elements : Array(Card)
    @elements.dup
  end

  # Card block IDs are checked within the carousel. Slack does not document
  # whether they must also differ from the surface's top-level block IDs.
  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @elements.empty?
      issues << ValidationIssue.new("carousel.elements.empty", "elements", "A carousel must contain at least one card.")
    elsif @elements.size > ELEMENTS_MAX_SIZE
      issues << ValidationIssue.new("carousel.elements.too_many", "elements", "A carousel cannot contain more than #{ELEMENTS_MAX_SIZE} cards.")
    end
    block_ids = Set(String).new
    @elements.each_with_index do |card, index|
      card.validate.each { |issue| issues << issue.at("elements[#{index}]") }
      block_id = card.block_id
      next unless block_id
      next if block_ids.add?(block_id)

      issues << ValidationIssue.new("carousel.block_id.duplicate", "elements[#{index}].block_id", "Block IDs must be unique within a carousel.")
    end
    length_issue(issues, @block_id, 255, "carousel.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "elements", @elements
    end
  end

  private def append_card(card : Card) : Nil
    @elements << card
  end
end
