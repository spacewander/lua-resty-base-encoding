## Benchmark

We compare the performance with the alternatives below:
* [basexx](https://github.com/aiq/basexx), a pure Lua implementation, version 0.4.1: base2, base16, base32, base85
* [lua-resty-core](https://github.com/openresty/lua-resty-core), official library shipped by OpenResty 1.15.8.1: base64, base64url
* FFI implementation, the code snippet can be found in `./benchmark.lua`: base16
(The FFI one is used as an optimized pure LuaJIT replacement of the `string.gsub('..', ...)` hex encoding, which I have seen in the wild.)

The benchmark contains several groups of test cases:
1. encode/decode base2, VS. basexx
1. encode/decode base16, VS. basexx, customize FFI implementation
1. encode/decode base32, VS. basexx
1. encode/decode base64, VS. lua-resty-core
1. encode/decode base64url, VS. lua-resty-core
1. encode/decode base85, VS. basexx

Each group runs with the short input and the long one.
The short input is 10000 raw string contains 64 random character.
The long input is 1 raw string contains 1M random character.

You can run the benchmark with `resty -I .. -I ../lib ./benchmark.lua` (make sure basexx and OpenResty are installed).

Here is the result in my machine (the unit is MB/s):

```
                        be     basexx  FFI     lua-resty-core
base2-encode-short      61      0.62    -       -
base2-decode-short      305     0.86    -       -
base2-encode-long       83      0.7     -       -
base2-decode-long       500     0.9     -       -
base16-encode-short     122     1.64    41      -
base16-decode-short     305     1.64    47      -
base16-encode-long      333     1.75    63      -
base16-decode-long      500     1.79    71      -
base32-encode-short     31      0.44    -       -
base32-decode-short     305     0.18    -       -
base32-encode-long      500     0.41    -       -
base32-decode-long      500     0.2     -       -
base64-encode-short     122     -       -       122
base64-decode-short     610     -       -       153
base64-encode-long      500     -       -       333
base64-decode-long      500     -       -       500
base64url-encode-short  153     -       -       153
base64url-decode-short  610     -       -       305
base64url-encode-long   333     -       -       333
base64url-decode-long   1000    -       -       333
base85-encode-short     87      5.3     -       -
base85-decode-short     305     6.8     -       -
base85-encode-long      333     3.4     -       -
base85-decode-long      500     4.6     -       -
(`be` is the abbr. of lua-resty-base-encoding)
```

## Why faster?

The lua-resty-base-encoding is 100x faster than basexx because Lua lacks a way
to manipulate string in byte level. Unlike most of other programming languages,
there is no byte array in Lua.

The lua-resty-base-encoding is faster than FFI version and lua-resty-core, because
it doesn't decode/encode the string byte by byte.
