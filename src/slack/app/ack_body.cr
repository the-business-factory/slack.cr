# The typed bodies that a listener can send as its acknowledgment. Each
# context accepts only the bodies that Slack documents for its payload.
alias Slack::App::AckBody = Slack::Commands::Response |
                            Slack::Interactions::ModalErrors |
                            Slack::Interactions::ModalPush |
                            Slack::Interactions::ModalUpdate |
                            Slack::Interactions::ModalClear |
                            Slack::Interactions::BlockSuggestionResponse
