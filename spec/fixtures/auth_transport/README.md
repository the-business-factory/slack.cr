`http-deflate.bin` contains `{"ok":true}` in the zlib format used by HTTP
`Content-Encoding: deflate`. Generate it independently of the Crystal decoder:

```sh
python3 -c 'import pathlib, zlib; pathlib.Path("spec/fixtures/auth_transport/http-deflate.bin").write_bytes(zlib.compress(b"{\"ok\":true}"))'
```
