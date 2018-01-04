# Name

lua-resty-base-encoding - Faster alternative to base64 encoding and provides missing base32 encoding for OpenResty application

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
* [Methods](#methods)
    * [encode_base32](#encode_base32)
    * [decode_base32](#decode_base32)
    * [encode_base64](#encode_base64)
    * [decode_base64](#decode_base64)
    * [encode_base64url](#encode_base64url)
    * [decode_base64url](#decode_base64url)

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

## Methods

### encode_base32
`syntax: encoded = encode_base32(raw[, no_padding])`

Encode given string into base32 format with/without padding '='. The default value of `no_padding` is false.

[Back to TOC](#table-of-contents)

### decode_base32
`syntax: raw, err = decode_base32(encoded)`

Decode base32 format string into its raw value. If the given string is not valid base32 encoded, the `raw` will be `nil` and `err` will be `"invalid input"`.

[Back to TOC](#table-of-contents)

### encode_base64
### decode_base64
### encode_base64url
### decode_base64url

Drop-in alternative to the official implementation in lua-resty-core. Read their official documentation instead.
The encode method is 40% faster, and the decode method is 200% faster. Note that the implementation is endian and architecture dependent.
Read the 'Must Read' section for more info.

[Back to TOC](#table-of-contents)

