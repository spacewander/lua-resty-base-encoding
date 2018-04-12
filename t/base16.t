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

=== TEST 1: encode base16
--- lua
local data = {
    "g",
    "",
    string.char(0xe3, 0xa1),
    string.char(0x0, 0x1, 0x2, 0x3, 0x4),
    string.char(0x18, 0x19, 0x1A, 0x1B, 0x1C),
    string.char(0xf0, 0xf1, 0xf2, 0xf3, 0xf4),
}
for _, d in ipairs(data) do
    local s = base_encoding.encode_base16(d)
    ngx.say(s)
end
--- response_body
67

E3A1
0001020304
18191A1B1C
F0F1F2F3F4



=== TEST 2: encode base16 (output in lowercase)
--- lua
local data = {
    string.char(0xe3, 0xa1),
    string.char(0x18, 0x19, 0x1A, 0x1B, 0x1C),
    string.char(0xf0, 0xf1, 0xf2, 0xf3, 0xf4),
}
local in_lowercase = true
for _, d in ipairs(data) do
    local s = base_encoding.encode_base16(d, in_lowercase)
    ngx.say(s)
end
--- response_body
e3a1
18191a1b1c
f0f1f2f3f4



=== TEST 3: decode base16
--- lua
local data = {
    "g",
    "",
    string.char(0xe3, 0xa1),
    string.char(0x0, 0x1, 0x2, 0x3, 0x4),
    string.char(0x18, 0x19, 0x1A, 0x1B, 0x1C),
    string.char(0xf0, 0xf1, 0xf2, 0xf3, 0xf4),
}
for _, d in ipairs(data) do
    local encoded = base_encoding.encode_base16(d)
    if base_encoding.decode_base16(encoded) ~= d then
        ngx.say("failed case: ", d)
        return
    end
end
ngx.say('ok')
--- response_body
ok



=== TEST 4: decode base16 (support both uppercase and lowercase input)
--- lua
local decoded = base_encoding.decode_base16("ABCDEF")
ngx.say(decoded == string.char(0xAB, 0xCD, 0xEF))
local decoded = base_encoding.decode_base16("abcdef")
ngx.say(decoded == string.char(0xAB, 0xCD, 0xEF))
--- response_body
true
true



=== TEST 5: decode base16 (invalid input)
--- lua
local data = {
    "a",
    "aaa",
    "agA0",
    "aaaR",
    "aaaaaR",
}

for _, d in ipairs(data) do
    local ok, err = base_encoding.decode_base16(d)
    ngx.say("decode: ", d, ": ", ok or err)
end
--- response_body
decode: a: invalid input
decode: aaa: invalid input
decode: agA0: invalid input
decode: aaaR: invalid input
decode: aaaaaR: invalid input



=== TEST 6: random tests
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
        local encoded = base_encoding.encode_base16(raw)
        if base_encoding.decode_base16(encoded) ~= raw then
            ngx.say("failed case: ", raw)
            return
        end

        local encoded = base_encoding.encode_base16(raw, true)
        if base_encoding.decode_base16(encoded) ~= raw then
            ngx.say("failed case with lowercase: ", raw)
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



=== TEST 7: base16 (invalid args)
--- lua
local d = 123
local res = base_encoding.encode_base16(d)
ngx.say(tonumber(base_encoding.decode_base16(res)) == d)
local ok, err = pcall(base_encoding.decode_base16, d)
if not ok then
    ngx.say(err)
end
--- response_body
true
string argument only
