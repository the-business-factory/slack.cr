# A cell in a received `table` or `data_table` row. A cell type that this
# library does not read decodes as `UnknownBlock`.
alias Slack::Interactions::ReceivedBlocks::TableCell = Slack::Interactions::ReceivedBlocks::RawText |
                                                       Slack::Interactions::ReceivedBlocks::RawNumber |
                                                       Slack::Interactions::RichText::Block |
                                                       Slack::Interactions::ReceivedBlocks::UnknownBlock
