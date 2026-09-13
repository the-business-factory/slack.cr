module AuthSupport
  INVALID_HOSTS = [
    "", "bad host", "bad\thost", "bad\r\nhost", "127.0.0.1\0canary-secret",
    "bad\u{1f}host", "bad\u{7f}host", "bad%", "bad%2", "bad%GGhost",
    "bad%20host", ".example", "example..test", "-example.test", "example-.test",
    "bad_host", "host/path", "host?query", "host#fragment", "user@host",
    "#{"a" * 64}.test", "#{"a." * 127}aa", "256.1.2.3", "127.1", "2130706433",
    "127.00.0.1", "1.2.3.4.5", "[127.0.0.1]", "[::1", "::1]", "[[::1]]",
    "[::1]suffix", "[gggg::1]", "[1::2::3]", "[1:2:3:4:5:6:7:8:9]", "[::ffff:256.1.2.3]",
  ] + (0..32).map { |code| "bad#{code.chr}host" }

  VALID_HOSTS = %w[localhost custom-host api.gov.example EXAMPLE.test. xn--bcher-kva.example
    192.0.2.1 127.0.0.1 [::1] [2001:db8::1234] [::ffff:192.0.2.1]]
end
