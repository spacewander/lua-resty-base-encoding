# Name

lua-resty-base-encoding - Faster alternative to base64 encoding and provides missing base encoding for OpenResty application

All encoding are implemented in optimized C code with LuaJIT FFI binding.

Most of the inner encoding implementations are from Nick Galbreath's [stringencoders](https://github.com/client9/stringencoders).
The base32 encoding is implemented by myself, but also inspired from his art work.

Build status: [![Travis](https://travis-ci.org/spacewander/lua-resty-base-encoding.svg?branch=master)](https://travis-ci.org/spacewander/lua-resty-base-encoding)

Table of Contents
=================

* [Name](#name)
* [MUST READ](#must-read)
* [Synopsis](#synopsis)
* [Installation](#installation)
* [Benchmark](#benchmark)
* [Methods](#methods)
    * [encode_base2](#encode_base2)
    * [decode_base2](#decode_base2)
    * [encode_base16](#encode_base16)
    * [decode_base16](#decode_base16)
    * [encode_base32](#encode_base32)
    * [decode_base32](#decode_base32)
    * [encode_base32hex](#encode_base32hex)
    * [decode_base32hex](#decode_base32hex)
    * [encode_base64](#encode_base64)
    * [decode_base64](#decode_base64)
    * [encode_base64url](#encode_base64url)
    * [decode_base64url](#decode_base64url)
    * [encode_base85](#encode_base85)
    * [decode_base85](#decode_base85)

## MUST READ

* The base64 encoding algorithm is ENDIAN DEPENDENT. The default version only works
  with little endian. To compile the big endian version, run `make CEXTRAFLAGS="-DWORDS_BIGENDIAN"` instead.
* The base64 encoding algorithm assumes input string is ALIGNED, so it could be used only on x86(x64) and modern ARM architecture.

## Synopsis

```lua
local base_encoding = require "resty.base_encoding"
local raw = "0123456789"

-- base32
local encoded = base_encoding.encode_base32(raw)
-- Or without '=' padding: local encoded = base_encoding.encode_base32(raw, true)
base_encoding.decode_base32(encoded) -- 0123456789

-- base64/base64_url (drop-in alternative to official API from lua-resty-core)
base_encoding.encode_base64(raw)
base_encoding.decode_base64(encoded)
base_encoding.encode_base64url(raw)
base_encoding.decode_base64url(encoded)
```

For more examples, read the `t/base*.t` files.

## Installation

Run `make`. Then copy the `librestybaseencoding.so` to one of your `lua_package_cpath`.
Yes, this library uses a trick to load the shared object from cpath instead of system shared library path.
Finally, add the `$pwd/lib` to your `lua_package_path`.

[Back to TOC](#table-of-contents)

## Benchmark

In short, it is quite faster than pure Lua alternatives, and a little faster than other C/FFI implementation.
Go to [Benchmark](benchmark/readme.md) page for the details.

[Back to TOC](#table-of-contents)

## Methods

### encode_base2
`syntax: encoded = encode_base2(raw)`

Encode given string into base2 format(aka. bin format). Note that the input is string.
Therefore, the `encode_base2` result of `1` is `00110001`, because the ascii value of `1` is 49, and
the binary format of 49 is `00110001`. And don't forget that the output of `encode_base2` is a string
instead of a binary number.

[Back to TOC](#table-of-contents)

### decode_base2
`syntax: raw, err = decode_base2(encoded)`

Decode base2 format string into its raw value.
If the given string is not valid base2 encoded, the `raw` will be `nil` and `err` will be `"invalid input"`.
Any character in the input string which is not `1` will be considered as `0`. For example, `aa11aaa1` is equal
to `00110001`. There is no RFC requires we should treat character not in `0` and `1` as invalid input, and
check if a character is '0' or not will slow the performance down by 50%.

[Back to TOC](#table-of-contents)

### encode_base16
`syntax: encoded = encode_base16(raw[, out_in_lowercase])`

Encode given string into base16 format(aka. hex/hexadecimal format).
This method may be named `to_hex` or `encodeHex` in other languages.
The default output letters are in `[0-9A-F]`. If you specify the `out_in_lowercase` to `true`, the output will be in `[0-9a-f]`.

[Back to TOC](#table-of-contents)

### decode_base16
`syntax: raw, err = decode_base16(encoded)`

Decode base16 format(aka. hex/hexadecimal format) string into its raw value.
This method may be named `from_hex` or `decodeHex` in other languages.
If the given string is not valid base16 encoded, the `raw` will be `nil` and `err` will be `"invalid input"`.
Letters in `[0-9a-fA-F]` are considered valid.

[Back to TOC](#table-of-contents)

### encode_base32
`syntax: encoded = encode_base32(raw[, no_padding])`

Encode given string into base32 format with/without padding '='. The default value of `no_padding` is false.

[Back to TOC](#table-of-contents)

### decode_base32
`syntax: raw, err = decode_base32(encoded)`

Decode base32 format string into its raw value. If the given string is not valid base32 encoded, the `raw` will be `nil` and `err` will be `"invalid input"`.

[Back to TOC](#table-of-contents)

### encode_base32hex
`syntax: encoded = encode_base32hex(raw[, no_padding])`

Encode given string into base32hex format with/without padding '='. The default value of `no_padding` is false.
For more info of base32hex format, see https://tools.ietf.org/html/rfc4648#section-7.

[Back to TOC](#table-of-contents)

### decode_base32hex
`syntax: raw, err = decode_base32(encoded)`

Decode base32hex format string into its raw value. If the given string is not valid base32hex encoded, the `raw` will be `nil` and `err` will be `"invalid input"`.
For more info of base32hex format, see https://tools.ietf.org/html/rfc4648#section-7.

[Back to TOC](#table-of-contents)

### encode_base64
### decode_base64
### encode_base64url
### decode_base64url

Drop-in alternative to the official implementation in lua-resty-core. Read their official documentation instead.
The encode method is 40% faster, and the decode method is 200% faster. Note that the implementation is endian and architecture dependent.
Read the 'Must Read' section for more info.

[Back to TOC](#table-of-contents)

### encode_base85
`syntax: encoded = encode_base85(raw)`

Encode given string into base85 format with/without padding '='.
Note that there is not a standard but too many variants of so-called base85.
This module's implementation should be compatiable with Go's encoding/ascii85
module (not in the level of API argument, but in the level of encode/decode rules).

[Back to TOC](#table-of-contents)

### decode_base85
`syntax: raw, err = decode_base85(encoded)`

Decode base85 format string into its raw value. If the given string is not valid base85 encoded, the `raw` will be `nil` and `err` will be `"invalid input"`.

[Back to TOC](#table-of-contents)

