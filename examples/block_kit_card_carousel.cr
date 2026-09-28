# Run with: crystal run examples/block_kit_card_carousel.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/card_carousel_example"

OfflineCardCarouselExample.run
