require "base64"

# :nodoc:
# Strict base64url (RFC 7515 section 2): the alphabet `A-Za-z0-9-_` without
# padding. `Base64.decode` also accepts `+`, `/`, `=`, and whitespace, so
# JWS segments are checked here first.
module Slack::OIDC::Base64URL
  ALPHABET = /\A[A-Za-z0-9_-]*\z/

  # Returns nil for any other byte, for an impossible length, and for an
  # encoding that is not canonical (unused bits set in the last character).
  def self.decode(text : String) : Bytes?
    return unless ALPHABET.matches?(text) && text.bytesize % 4 != 1

    bytes = Base64.decode(text)
    encode(bytes) == text ? bytes : nil
  end

  def self.encode(bytes : Bytes) : String
    Base64.urlsafe_encode(bytes, padding: false)
  end
end
