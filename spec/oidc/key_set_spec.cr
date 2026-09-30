require "../spec_helper"
require "../support/oidc/fixtures"

module KeySetSpecSupport
  extend self

  # The fixture RSA key as a JWK hash, to change one field at a time.
  def rsa_jwk : Hash(String, JSON::Any)
    JSON.parse(OIDCFixtures.jwks)["keys"].as_a.find! { |jwk| jwk["kty"] == "RSA" }.as_h.dup
  end

  def document(*jwks : Hash(String, JSON::Any)) : String
    document(jwks.to_a)
  end

  def document(jwks : Array(Hash(String, JSON::Any))) : String
    {"keys" => jwks}.to_json
  end

  def with_field(name : String, value : String?) : Hash(String, JSON::Any)
    jwk = rsa_jwk
    value.nil? ? jwk.delete(name) : (jwk[name] = JSON::Any.new(value))
    jwk
  end
end

describe Slack::OIDC::KeySet do
  it "reads the RSA key by kid and skips the EC key" do
    key_set = Slack::OIDC::KeySet.parse(OIDCFixtures.jwks)

    key_set.size.should eq 1
    key = key_set["synthetic-kid"]?.should_not be_nil
    key.exponent.should eq Bytes[0x01, 0x00, 0x01]
    key.modulus.size.should eq 256
    key_set["synthetic-ec-kid"]?.should be_nil
  end

  it "skips RSA keys that cannot verify RS256" do
    usable = KeySetSpecSupport.with_field("kid", "usable")
    unusable = [
      KeySetSpecSupport.with_field("use", "enc"),
      KeySetSpecSupport.with_field("alg", "RS512"),
      KeySetSpecSupport.with_field("kid", " "),
      KeySetSpecSupport.with_field("e", "AQAB="),
      KeySetSpecSupport.with_field("n", Slack::OIDC::Base64URL.encode(Bytes.new(128, 0xff_u8))),
    ]

    key_set = Slack::OIDC::KeySet.parse(KeySetSpecSupport.document([usable] + unusable))

    key_set.size.should eq 1
    key_set["usable"]?.should_not be_nil
  end

  it "accepts a key without the optional use and alg members" do
    jwk = KeySetSpecSupport.with_field("use", nil)
    jwk.delete("alg")

    Slack::OIDC::KeySet.parse(KeySetSpecSupport.document(jwk))["synthetic-kid"]?.should_not be_nil
  end

  it "rejects documents that have no usable key" do
    [
      %({"not_keys":[]}),
      %([]),
      %({"keys":{}}),
      %({"keys":[]}),
      "not json",
      KeySetSpecSupport.document(JSON.parse(OIDCFixtures.jwks)["keys"][0].as_h),
      KeySetSpecSupport.document(KeySetSpecSupport.with_field("n", nil)),
      KeySetSpecSupport.document(KeySetSpecSupport.rsa_jwk, KeySetSpecSupport.rsa_jwk),
    ].each do |document|
      OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidResponse) do
        Slack::OIDC::KeySet.parse(document)
      end
    end
  end
end
