`http-deflate.bin` contains `{"ok":true}` in the zlib format used by HTTP
`Content-Encoding: deflate`. Generate it independently of the Crystal decoder:

```sh
python3 -c 'import pathlib, zlib; pathlib.Path("spec/fixtures/auth_transport/http-deflate.bin").write_bytes(zlib.compress(b"{\"ok\":true}"))'
```

`ipv6-server.pem` is a self-signed certificate for the synthetic `::1` TLS
endpoint. The IPv6 CONNECT test explicitly trusts this certificate. It uses the
existing synthetic `server-key.pem`; neither file is a production credential.
Regenerate the certificate from the repository root:

```sh
openssl req -new -x509 -key spec/fixtures/auth_transport/server-key.pem \
  -out spec/fixtures/auth_transport/ipv6-server.pem -days 3650 \
  -subj '/CN=slack.cr synthetic IPv6 loopback' \
  -addext 'subjectAltName=IP:::1' -addext 'basicConstraints=critical,CA:FALSE'
```
