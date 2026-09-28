# X-axis categories, in display order, and optional axis titles. Slack
# requires categories of up to 20 characters and axis titles of up to 50.
# Because each series needs one point for each category and at most 20
# points, a chart has at most 20 categories. At least one category, nonempty
# categories, and unique categories are library policy; a duplicate category
# would make point labels ambiguous.
struct Slack::UI::Checked::DataVisualization::AxisConfig
  include Slack::UI::Checked::ValueValidation

  CATEGORIES_MAX_SIZE = 20
  CATEGORY_MAX_SIZE   = 20
  LABEL_MAX_SIZE      = 50

  @categories : Array(String)
  getter x_label : String?
  getter y_label : String?

  def initialize(categories : Enumerable(T), @x_label : String? = nil, @y_label : String? = nil) forall T
    @categories = [] of String
    categories.each { |category| append_category(category) }
    validate!
  end

  def categories : Array(String)
    @categories.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @categories.empty?
      issues << ValidationIssue.new("axis_config.categories.empty", "categories", "Axis config must contain at least one category.")
    elsif @categories.size > CATEGORIES_MAX_SIZE
      issues << ValidationIssue.new("axis_config.categories.too_many", "categories", "Axis config cannot contain more than #{CATEGORIES_MAX_SIZE} categories.")
    end
    seen = Set(String).new
    @categories.each_with_index do |category, index|
      category_issues(issues, category, "categories[#{index}]", seen)
    end
    length_issue(issues, @x_label, LABEL_MAX_SIZE, "axis_config.x_label.too_long", "x_label")
    length_issue(issues, @y_label, LABEL_MAX_SIZE, "axis_config.y_label.too_long", "y_label")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "categories", @categories
      json.field "x_label", @x_label if @x_label
      json.field "y_label", @y_label if @y_label
    end
  end

  private def category_issues(issues : Array(ValidationIssue), category : String, path : String, seen : Set(String)) : Nil
    if category.empty?
      issues << ValidationIssue.new("axis_config.category.empty", path, "Category must not be empty.")
    elsif !seen.add?(category)
      issues << ValidationIssue.new("axis_config.category.duplicate", path, "Categories must be unique within a chart.")
    end
    length_issue(issues, category, CATEGORY_MAX_SIZE, "axis_config.category.too_long", path)
  end

  private def append_category(category : String) : Nil
    @categories << category
  end
end
