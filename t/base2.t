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

=== TEST 1: encode base2
--- lua
local data = {
    "1",
    "2",
    "3",
    "123",
    "",
    "AC",
    "DC",
    "ACDC",
}
for _, d in ipairs(data) do
    local s = base_encoding.encode_base2(d)
    ngx.say(s)
end
--- response_body
00110001
00110010
00110011
001100010011001000110011

0100000101000011
0100010001000011
01000001010000110100010001000011



=== TEST 2: decode base2
--- lua
local data = {
    "1",
    "2",
    "3",
    "123",
    "",
    "AC",
    "DC",
    "ACDC",
}
for _, d in ipairs(data) do
    local encoded = base_encoding.encode_base2(d)
    if base_encoding.decode_base2(encoded) ~= d then
        ngx.say("failed case: ", d)
        return
    end
end
ngx.say('ok')
--- response_body
ok



=== TEST 3: decode base2 (invalid input)
--- lua
local data = {
    "0110",
    "0102",
    "0000000010",
}

for _, d in ipairs(data) do
    local ok, err = base_encoding.decode_base2(d)
    ngx.say("decode: ", d, ": ", ok or err)
end
--- response_body
decode: 0110: invalid input
decode: 0102: invalid input
decode: 0000000010: invalid input



=== TEST 4: random tests
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
        local encoded = base_encoding.encode_base2(raw)
        if base_encoding.decode_base2(encoded) ~= raw then
            ngx.say("failed case: ", raw)
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



=== TEST 5: base2 (invalid args)
--- lua
local d = 123
local res = base_encoding.encode_base2(d)
ngx.say(tonumber(base_encoding.decode_base2(res)) == d)
local ok, err = pcall(base_encoding.decode_base2, d)
if not ok then
    ngx.say(err)
end
--- response_body
true
string argument only
