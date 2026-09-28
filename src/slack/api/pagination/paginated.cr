require "uri"
require "../../ui/validation_issue"

module Slack::Api
  # A request that reads one page of a cursor-paginated list.
  # See https://docs.slack.dev/apis/web-api/pagination.
  #
  # An including request declares `@cursor : String?` and `@limit : Int32?`,
  # adds `page_fields` to its form, and returns `page_issues` from `validate`.
  # `Client#each_page` follows `response_metadata.next_cursor` with `with_cursor`.
  module Paginated
    # The pagination limit maximum. Some methods document a lower maximum;
    # Slack checks those.
    MAX_LIMIT = 1000

    abstract def cursor : String?
    abstract def limit : Int32?

    # Returns a copy of this request that reads the page at *cursor*.
    def with_cursor(cursor : String?) : self
      copy = dup
      copy.cursor = cursor
      copy
    end

    protected def cursor=(@cursor : String?) : String?
    end

    private def page_fields(form : URI::Params) : Nil
      cursor.try { |value| form.add "cursor", value }
      limit.try { |value| form.add "limit", value.to_s }
    end

    private def page_issues : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if (value = limit) && !(1..MAX_LIMIT).includes?(value)
        issues << UI::ValidationIssue.new(
          "pagination.limit.out_of_range", "limit", "Limit must be between 1 and #{MAX_LIMIT}.")
      end
      issues
    end
  end
end
