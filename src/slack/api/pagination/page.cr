module Slack::Api
  # One page of a cursor-paginated response: the response model and the cursor
  # of the next page. `next_cursor` is nil on the last page.
  struct Page(M)
    getter model : M
    getter next_cursor : String?

    def initialize(@model : M, @next_cursor : String?)
    end
  end
end
