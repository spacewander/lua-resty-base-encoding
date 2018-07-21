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

=== TEST 1: encode base85
--- lua
local wikipedia_text = "Man is distinguished, not only by his reason,"
    .. " but by this singular passion from other animals, "
    .. "which is a lust of the mind, that by a perseverance of delight in "
    .. "the continued and indefatigable generation of knowledge, exceeds "
    .. "the short vehemence of any carnal pleasure."
local data = {
    "\0\0\0",
	-- Special case when shortening !!!!! to z.
    "\0\0\0\0",
    "\0\0\0\0\0",
    "",
    wikipedia_text,
}
for _, d in ipairs(data) do
    local s = base_encoding.encode_base85(d)
    ngx.say(s)
end
--- response_body
!!!!
z
z!!

9jqo^BlbD-BleB1DJ+*+F(f,q/0JhKF<GL>Cj@.4Gp$d7F!,L7@<6@)/0JDEF<G%<+EV:2F!,O<DJ+*.@<*K0@<6L(Df-\0Ec5e;DffZ(EZee.Bl.9pF"AGXBPCsi+DGm>@3BB/F*&OCAfu2/AKYi(DIb:@FD,*)+C]U=@3BN#EcYf8ATD3s@q?d$AftVqCh[NqF<G:8+EV:.+Cf>-FD5W8ARlolDIal(DId<j@<?3r@:F%a+D58'ATD4$Bl@l3De:,-DJs`8ARoFb/0JMK@qB4^F!,R<AKZ&-DfTqBG%G>uD.RTpAKYo'+CT/5+Cei#DII?(E,9)oF*2M7/c



=== TEST 2: decode base85
--- lua
local wikipedia_text = "Man is distinguished, not only by his reason,"
    .. " but by this singular passion from other animals, "
    .. "which is a lust of the mind, that by a perseverance of delight in "
    .. "the continued and indefatigable generation of knowledge, exceeds "
    .. "the short vehemence of any carnal pleasure."
local data = {
    wikipedia_text,
    "\0\0\0",
	-- Special case when shortening !!!!! to z.
    "\0\0\0\0",
    "\0\0\0\0\0",
    "",
}
for _, d in ipairs(data) do
    local encoded = base_encoding.encode_base85(d)
    local decoded = base_encoding.decode_base85(encoded)
    if decoded ~= d then
        ngx.say("failed case: ", d, " encoded: ", encoded, " decoded: ", decoded)
        return
    end
end
ngx.say('ok')
--- response_body
ok



=== TEST 3: random tests
--- timeout: 5s
--- lua
local start = ngx.now()
while true do
    for _ = 1, 1000 do
        local size = math.random(1, 1000)
        local buf = table.new(size, 0)
        for i = 1, size do
            buf[i] = math.random(0, 255)
        end

        local raw = string.char(unpack(buf))
        local encoded = base_encoding.encode_base85(raw)
        if base_encoding.decode_base85(encoded) ~= raw then
            ngx.say("failed case(base64 encoded): ",
                    base_encoding.encode_base64(raw), "\nraw: ", raw)
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



=== TEST 4: decode base85 (invalid input)
--- lua
local data = {
    "v",
    "!z!!!!!!!!!",
}

for _, d in ipairs(data) do
    local ok, err = base_encoding.decode_base2(d)
    ngx.say("decode: ", d, ": ", ok or err)
end
--- response_body
decode: v: invalid input
decode: !z!!!!!!!!!: invalid input



=== TEST 5: base85 (invalid args)
--- lua
local d = 123
local res = base_encoding.encode_base85(d)
ngx.say(tonumber(base_encoding.decode_base85(res)) == d)
local ok, err = pcall(base_encoding.decode_base85, d)
if not ok then
    ngx.say(err)
end
--- response_body
true
string argument only



=== TEST 6: decode base85 (skip whitespace and line break)
--- lua
local abcd = base_encoding.encode_base85("abcd")
local data = {
    string.rep(' ', 2048) .. abcd,
    abcd .. string.rep(' ', 2048),
    " " .. abcd .. "  ",
    "\n " .. abcd .. "\n",
}

for _, d in ipairs(data) do
    local decoded = base_encoding.decode_base85(d)
    if decoded ~= "abcd" then
        ngx.say("failed to decode ", d)
        return
    end
end
ngx.say('ok')
--- response_body
ok
