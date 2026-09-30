# :nodoc:
# Encodes one RSA public key as a DER SubjectPublicKeyInfo (RFC 5280 and
# RFC 8017 appendix A.1.1), the input of OpenSSL's `d2i_PUBKEY`:
#
# SEQUENCE { SEQUENCE { OID rsaEncryption, NULL }, BIT STRING { SEQUENCE { INTEGER n, INTEGER e } } }
module Slack::OIDC::RSAPublicKeyDER
  RSA_ALGORITHM = Bytes[0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]

  def self.encode(modulus : Bytes, exponent : Bytes) : Bytes
    rsa_key = tlv(0x30_u8, concat(integer(modulus), integer(exponent)))
    # The BIT STRING content starts with the count of unused bits, zero.
    bit_string = tlv(0x03_u8, concat(Bytes[0x00], rsa_key))
    tlv(0x30_u8, concat(RSA_ALGORITHM, bit_string))
  end

  # An unsigned big-endian INTEGER: no redundant leading zeros, and a zero
  # byte in front when the high bit is set, so the value stays positive.
  def self.integer(value : Bytes) : Bytes
    start = 0
    while start < value.size - 1 && value[start] == 0
      start += 1
    end
    digits = value.size.zero? ? Bytes[0x00] : value[start..]
    digits = concat(Bytes[0x00], digits) if digits[0] >= 0x80
    tlv(0x02_u8, digits)
  end

  private def self.tlv(tag : UInt8, content : Bytes) : Bytes
    concat(Bytes[tag], length(content.size), content)
  end

  # DER length: one byte below 128, else 0x80 plus the count of length bytes.
  private def self.length(size : Int32) : Bytes
    return Bytes[size.to_u8] if size < 0x80

    digits = [] of UInt8
    remaining = size
    while remaining > 0
      digits.unshift((remaining & 0xff).to_u8)
      remaining >>= 8
    end
    concat(Bytes[0x80_u8 | digits.size.to_u8], Slice.new(digits.to_unsafe, digits.size))
  end

  private def self.concat(*parts : Bytes) : Bytes
    io = IO::Memory.new
    parts.each { |part| io.write(part) }
    io.to_slice
  end
end
