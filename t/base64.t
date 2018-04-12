use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

add_block_preprocessor(sub {
    my ($block) = @_;
    my $name = $block->name;

    if (!defined $block->error_log) {
        $block->set_value("no_error_log", "[error]");
    }

    if (!defined $block->request) {
        $block->set_value("request", 'GET /base');
    }

    my $http_config = $block->http_config // "";
    $http_config .= <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;$pwd/t/lib/?.lua;;";
    lua_package_cpath "$pwd/?.so;;";
    init_by_lua_block {
        require "resty.core"
    }
_EOC_
    $block->set_value("http_config", $http_config);

    if (defined $block->lua) {
        my $lua = $block->lua;
        my $config = <<_EOC_;
        location = /base {
            content_by_lua_block {
                local base_encoding = require "resty.base_encoding"
                $lua
            }
        }
_EOC_
        $block->set_value("config", $config);
    }

    $block;
});

check_accum_error_log();
no_long_string();
run_tests();

__DATA__

=== TEST 1: encode base64 (string)
--- lua
local s = base_encoding.encode_base64("hello")
ngx.say(s)
--- response_body
aGVsbG8=



=== TEST 2: encode base64 (nil)
--- lua
local s = base_encoding.encode_base64(nil)
ngx.say(s)
--- response_body eval: "\n"



=== TEST 3: encode base64 (number)
--- lua
local s = base_encoding.encode_base64(3.14)
ngx.say(s)
--- response_body
My4xNA==



=== TEST 4: encode base64 (boolean)
--- lua
local s = base_encoding.encode_base64(true)
ngx.say(s)
--- response_body
dHJ1ZQ==



=== TEST 5: encode base64 (number) without padding (explicitly specified)
--- lua
local s = base_encoding.encode_base64(3.14, true)
ngx.say(s)
--- response_body
My4xNA



=== TEST 6: encode base64 (number) with padding (explicitly specified)
--- lua
local s = base_encoding.encode_base64(3.14, false)
ngx.say(s)
--- response_body
My4xNA==



=== TEST 7: decode base64
--- lua
local s = base_encoding.decode_base64("aGVsbG8=")
ngx.say(s)
s = base_encoding.decode_base64("aGVsbG8")
ngx.say(s)
--- response_body
hello
hello



=== TEST 8: decode base64 (nil)
--- lua
local s = base_encoding.decode_base64("")
ngx.say(s)
--- response_body eval: "\n"



=== TEST 9: decode base64 (number)
--- lua
local s = base_encoding.decode_base64("My4xNA==")
ngx.say(s)
s = base_encoding.decode_base64("My4xNA==")
ngx.say(s)
--- response_body
3.14
3.14



=== TEST 10: decode base64 (boolean)
--- lua
local s = base_encoding.decode_base64("dHJ1ZQ==")
ngx.say(s)
s = base_encoding.decode_base64("dHJ1ZQ")
ngx.say(s)
--- response_body
true
true



=== TEST 11: decode base64 (invalid)
--- lua
local s = base_encoding.decode_base64("dHJ1 Q")
ngx.say(s or "nil")
local s = base_encoding.decode_base64("d==")
ngx.say(s or "nil")
local s = base_encoding.decode_base64("dHJ1Z===")
ngx.say(s or "nil")
--- response_body
nil
nil
nil



=== TEST 12: encode_base64url
--- lua
local encode_base64url = base_encoding.encode_base64url
-- RFC 4648 test vectors
ngx.say("encode_base64url(\"\") = \"", encode_base64url(""), "\"")
ngx.say("encode_base64url(\"f\") = \"", encode_base64url("f"), "\"")
ngx.say("encode_base64url(\"fo\") = \"", encode_base64url("fo"), "\"")
ngx.say("encode_base64url(\"foo\") = \"", encode_base64url("foo"), "\"")
ngx.say("encode_base64url(\"foob\") = \"", encode_base64url("foob"), "\"")
ngx.say("encode_base64url(\"fooba\") = \"", encode_base64url("fooba"), "\"")
ngx.say("encode_base64url(\"foobar\") = \"", encode_base64url("foobar"), "\"")
ngx.say("encode_base64url(\"\\xff\") = \"", encode_base64url("\xff"), "\"")
ngx.say("encode_base64url(\"a\\0b\") = \"", encode_base64url("a\0b"), "\"")
--- response_body
encode_base64url("") = ""
encode_base64url("f") = "Zg"
encode_base64url("fo") = "Zm8"
encode_base64url("foo") = "Zm9v"
encode_base64url("foob") = "Zm9vYg"
encode_base64url("fooba") = "Zm9vYmE"
encode_base64url("foobar") = "Zm9vYmFy"
encode_base64url("\xff") = "_w"
encode_base64url("a\0b") = "YQBi"



=== TEST 13: decode_base64url
--- lua
local decode_base64url = base_encoding.decode_base64url

local function to_hex(str)
    return (str:gsub('.', function(c)
        return string.format('%02x', string.byte(c))
    end))
end

-- RFC 4648 test vectors
ngx.say("decode_base64url(\"\") = \"", decode_base64url(""), "\"")
ngx.say("decode_base64url(\"Zg\") = \"", decode_base64url("Zg"), "\"")
ngx.say("decode_base64url(\"Zm8\") = \"", decode_base64url("Zm8"), "\"")
ngx.say("decode_base64url(\"Zm9v\") = \"", decode_base64url("Zm9v"), "\"")
ngx.say("decode_base64url(\"Zm9vYg\") = \"", decode_base64url("Zm9vYg"), "\"")
ngx.say("decode_base64url(\"Zm9vYmE\") = \"", decode_base64url("Zm9vYmE"), "\"")
ngx.say("decode_base64url(\"Zm9vYmFy\") = \"", decode_base64url("Zm9vYmFy"), "\"")
ngx.say("decode_base64url(\"_w\") = \"\\x", to_hex(decode_base64url("_w")), "\"")
ngx.say("decode_base64url(\"YQBi\") = \"\\x", to_hex(decode_base64url("YQBi")), "\"")
--- response_body
decode_base64url("") = ""
decode_base64url("Zg") = "f"
decode_base64url("Zm8") = "fo"
decode_base64url("Zm9v") = "foo"
decode_base64url("Zm9vYg") = "foob"
decode_base64url("Zm9vYmE") = "fooba"
decode_base64url("Zm9vYmFy") = "foobar"
decode_base64url("_w") = "\xff"
decode_base64url("YQBi") = "\x610062"



=== TEST 14: decode_base64url with invalid input
--- lua
local decode_base64url = base_encoding.decode_base64url
local res, err = decode_base64url("     ")
ngx.say("decode_base64url returned: ", res, ", ", err)
--- response_body
decode_base64url returned: nil, invalid input



=== TEST 15: random tests
--- timeout: 5s
--- lua
local start = ngx.now()
while true do
    for _ = 1, 1000 do
        local size = math.random(1, 20)
        local buf = table.new(size, 0)
        for i = 1, size do
            buf[i] = math.random(33, 126)
        end

        local raw = string.char(unpack(buf))
        local encoded = base_encoding.encode_base64(raw)
        if base_encoding.decode_base64(encoded) ~= raw then
            ngx.say("failed case: ", raw)
            return
        end

        local encoded = base_encoding.encode_base64(raw, true)
        if base_encoding.decode_base64(encoded) ~= raw then
            ngx.say("failed case without padding: ", raw)
            return
        end

        local encoded = base_encoding.encode_base64url(raw)
        if base_encoding.decode_base64url(encoded) ~= raw then
            ngx.say("failed case in url variant: ", raw)
            return
        end
    end

    ngx.update_time()
    if ngx.now() - start > 3 then
        break
    end
end
ngx.say("ok")
--- response_body
ok



=== TEST 16: base64 (invalid args)
--- lua
local d = 123
local res = base_encoding.encode_base64(d)
ngx.say(tonumber(base_encoding.decode_base64(res)) == d)
local ok, err = pcall(base_encoding.decode_base64, d)
if not ok then
    ngx.say(err)
end
--- response_body
true
string argument only



=== TEST 17: base64url (invalid args)
--- lua
local d = 456
local ok, err = base_encoding.encode_base64url(d)
if not ok then
    ngx.say(err)
end

local ok, err = base_encoding.decode_base64url(d)
if not ok then
    ngx.say(err)
end
--- response_body
must provide a string
must provide a string
