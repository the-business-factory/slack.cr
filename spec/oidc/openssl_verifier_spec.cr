require "../spec_helper"
require "../support/oidc/fixtures"

module OpenSSLVerifierSpecSupport
  extend self

  def key : Slack::OIDC::SigningKey
    Slack::OIDC::KeySet.parse(OIDCFixtures.jwks)["synthetic-kid"]?.should_not be_nil
  end

  # The signing input and signature of the OpenSSL-signed fixture token.
  def vector : Tuple(Bytes, Bytes)
    header, payload, signature = OIDCFixtures.token.split('.')
    {"#{header}.#{payload}".to_slice, Slack::OIDC::Base64URL.decode(signature).should_not(be_nil)}
  end

  def verify(signing_input : Bytes, signature : Bytes) : Bool
    Slack::OIDC::OpenSSLVerifier.new.verify(key, signing_input, signature)
  end
end

describe Slack::OIDC::OpenSSLVerifier do
  it "accepts a signature that the OpenSSL CLI made" do
    signing_input, signature = OpenSSLVerifierSpecSupport.vector

    OpenSSLVerifierSpecSupport.verify(signing_input, signature).should be_true
  end

  it "rejects a changed, shortened, or misplaced signature" do
    signing_input, signature = OpenSSLVerifierSpecSupport.vector
    flipped = signature.dup
    flipped[10] ^= 0x01_u8
    other_input = OIDCFixtures.token("wrong_nonce").split('.')[0, 2].join('.').to_slice

    OpenSSLVerifierSpecSupport.verify(signing_input, flipped).should be_false
    OpenSSLVerifierSpecSupport.verify(signing_input, signature[0, signature.size - 1]).should be_false
    OpenSSLVerifierSpecSupport.verify(signing_input, Bytes.empty).should be_false
    OpenSSLVerifierSpecSupport.verify(other_input, signature).should be_false
  end

  it "rejects the signature under another key" do
    signing_input, signature = OpenSSLVerifierSpecSupport.vector
    key = OpenSSLVerifierSpecSupport.key
    modulus = key.modulus.dup
    modulus[-1] ^= 0x02_u8
    other_key = Slack::OIDC::SigningKey.new("other", modulus, key.exponent)

    Slack::OIDC::OpenSSLVerifier.new.verify(other_key, signing_input, signature).should be_false
  end
end

describe Slack::OIDC::RSAPublicKeyDER do
  it "encodes the key exactly as the OpenSSL CLI does" do
    key = OpenSSLVerifierSpecSupport.key

    Slack::OIDC::RSAPublicKeyDER.encode(key.modulus, key.exponent)
      .should eq File.read("spec/fixtures/oidc/public_key.der").to_slice
  end

  it "encodes integers in the shortest positive form" do
    Slack::OIDC::RSAPublicKeyDER.integer(Bytes[0x03]).should eq Bytes[0x02, 0x01, 0x03]
    Slack::OIDC::RSAPublicKeyDER.integer(Bytes[0x00, 0x00, 0x03]).should eq Bytes[0x02, 0x01, 0x03]
    Slack::OIDC::RSAPublicKeyDER.integer(Bytes[0x80, 0x01]).should eq Bytes[0x02, 0x03, 0x00, 0x80, 0x01]
    Slack::OIDC::RSAPublicKeyDER.integer(Bytes[0x00]).should eq Bytes[0x02, 0x01, 0x00]
  end

  it "uses long-form lengths above 127 bytes" do
    Slack::OIDC::RSAPublicKeyDER.integer(Bytes.new(200, 0x7f_u8))[0, 3].should eq Bytes[0x02, 0x81, 0xc8]
    Slack::OIDC::RSAPublicKeyDER.integer(Bytes.new(256, 0x7f_u8))[0, 4].should eq Bytes[0x02, 0x82, 0x01, 0x00]
  end
end

describe Slack::OIDC::Base64URL do
  it "round-trips bytes without padding" do
    bytes = Bytes[0xfb, 0xff, 0xbf, 0x00, 0x01]

    Slack::OIDC::Base64URL.encode(bytes).should eq "-_-_AAE"
    Slack::OIDC::Base64URL.decode("-_-_AAE").should eq bytes
  end

  it "rejects the standard alphabet, padding, whitespace, and impossible lengths" do
    ["+_-_AAE", "/_-_AAE", "-_-_AAE=", "-_-_ AAE", "-_-_\nAAE", "AAAAA"].each do |text|
      Slack::OIDC::Base64URL.decode(text).should be_nil
    end
  end

  it "rejects a non-canonical last character" do
    Slack::OIDC::Base64URL.decode("QQ").should eq "A".to_slice
    Slack::OIDC::Base64URL.decode("QR").should be_nil
  end
end
