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

=== TEST 1: encode base32
--- lua
local data = {
    -- RFC 4648 examples
    "f",
    "fo",
    "foo",
    "foob",
    "fooba",
    "foobar",
    "",
    -- Wikipedia examples, converted to base32
    "sure.",
    "sure",
    "sur",
    "su",
    "leasure.",
    "easure.",
    "asure.",
    "sure.",
    -- Long test
    "Twas brillig, and the slithy toves",
}
for _, d in ipairs(data) do
    local s = base_encoding.encode_base32(d)
    ngx.say(s)
end
--- response_body
MY======
MZXQ====
MZXW6===
MZXW6YQ=
MZXW6YTB
MZXW6YTBOI======

ON2XEZJO
ON2XEZI=
ON2XE===
ON2Q====
NRSWC43VOJSS4===
MVQXG5LSMUXA====
MFZXK4TFFY======
ON2XEZJO
KR3WC4ZAMJZGS3DMNFTSYIDBNZSCA5DIMUQHG3DJORUHSIDUN53GK4Y=



=== TEST 2: encode base32 (no padding)
--- lua
local data = {
    "f",
    "fo",
    "foo",
    "foob",
    "fooba",
    "foobar",
    "sure.",
    "sure",
    "sur",
    "su",
    "leasure.",
    "easure.",
    "asure.",
    "sure.",
    "Twas brillig, and the slithy toves",
}
for _, d in ipairs(data) do
    local s = base_encoding.encode_base32(d, true)
    ngx.say(s)
end
--- response_body
MY
MZXQ
MZXW6
MZXW6YQ
MZXW6YTB
MZXW6YTBOI
ON2XEZJO
ON2XEZI
ON2XE
ON2Q
NRSWC43VOJSS4
MVQXG5LSMUXA
MFZXK4TFFY
ON2XEZJO
KR3WC4ZAMJZGS3DMNFTSYIDBNZSCA5DIMUQHG3DJORUHSIDUN53GK4Y



=== TEST 3: decode base32
--- lua
local data = {
    'MY======',
    'MZXQ====',
    'MZXW6===',
    'MZXW6YQ=',
    'MZXW6YTB',
    'MZXW6YTBOI======',
    '',
    'ON2XEZJO',
    'ON2XEZI=',
    'ON2XE===',
    'ON2Q====',
    'NRSWC43VOJSS4===',
    'MVQXG5LSMUXA====',
    'MFZXK4TFFY======',
    'ON2XEZJO',
    'KR3WC4ZAMJZGS3DMNFTSYIDBNZSCA5DIMUQHG3DJORUHSIDUN53GK4Y=',
}
for _, d in ipairs(data) do
    local s = base_encoding.decode_base32(d)
    ngx.say(s)
end
--- response_body
f
fo
foo
foob
fooba
foobar

sure.
sure
sur
su
leasure.
easure.
asure.
sure.
Twas brillig, and the slithy toves



=== TEST 4: decode base32 (no padding)
--- lua
local data = {
    'MY',
    'MZXQ',
    'MZXW6',
    'MZXW6YQ',
    'MZXW6YTB',
    'MZXW6YTBOI',
    '',
    'ON2XEZJO',
    'ON2XEZI',
    'ON2XE',
    'ON2Q',
    'NRSWC43VOJSS4',
    'MVQXG5LSMUXA',
    'MFZXK4TFFY',
    'ON2XEZJO',
    'KR3WC4ZAMJZGS3DMNFTSYIDBNZSCA5DIMUQHG3DJORUHSIDUN53GK4Y=',
}
for _, d in ipairs(data) do
    local s = base_encoding.decode_base32(d)
    ngx.say(s)
end
--- response_body
f
fo
foo
foob
fooba
foobar

sure.
sure
sur
su
leasure.
easure.
asure.
sure.
Twas brillig, and the slithy toves



=== TEST 5: decode base32 (invalid input)
--- lua
local data = {
    '========',
    'a===',
    's1u',
    'NRSWC48VOJSS4',
    'AAAAAA==',
    "AAA=====",
    "A=======",
    "AAAAA==",
    "A=",
    "AA=",
    "AA==",
    "AA===",
    "AAAA=",
    "AAAA==",
    "AAAAA=",
    "!!!!",
    "x===",
    "AA=A====",
    "AAA=AAAA",
    "MMMMMMMMM",
    "MMMMMM",
}

for _, d in ipairs(data) do
    local ok, err = base_encoding.decode_base32(d)
    ngx.say("decode: ", d, ": ", ok or err)
end
--- response_body
decode: ========: invalid input
decode: a===: invalid input
decode: s1u: invalid input
decode: NRSWC48VOJSS4: invalid input
decode: AAAAAA==: invalid input
decode: AAA=====: invalid input
decode: A=======: invalid input
decode: AAAAA==: invalid input
decode: A=: invalid input
decode: AA=: invalid input
decode: AA==: invalid input
decode: AA===: invalid input
decode: AAAA=: invalid input
decode: AAAA==: invalid input
decode: AAAAA=: invalid input
decode: !!!!: invalid input
decode: x===: invalid input
decode: AA=A====: invalid input
decode: AAA=AAAA: invalid input
decode: MMMMMMMMM: invalid input
decode: MMMMMM: invalid input



=== TEST 6: random tests, base32
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
        local encoded = base_encoding.encode_base32(raw)
        if base_encoding.decode_base32(encoded) ~= raw then
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



=== TEST 7: encode base32hex
--- lua
local data = {
    -- RFC 4648 examples
    "f",
    "fo",
    "foo",
    "foob",
    "fooba",
    "foobar",
    "",
    -- Wikipedia examples, converted to base32
    "sure.",
    "sure",
    "sur",
    "su",
    "leasure.",
    "easure.",
    "asure.",
    "sure.",
    -- Long test
    "Twas brillig, and the slithy toves",
}
for _, d in ipairs(data) do
    local s = base_encoding.encode_base32hex(d)
    ngx.say(s)
end
--- response_body
CO======
CPNG====
CPNMU===
CPNMUOG=
CPNMUOJ1
CPNMUOJ1E8======

EDQN4P9E
EDQN4P8=
EDQN4===
EDQG====
DHIM2SRLE9IIS===
CLGN6TBICKN0====
C5PNASJ55O======
EDQN4P9E
AHRM2SP0C9P6IR3CD5JIO831DPI20T38CKG76R39EHK7I83KDTR6ASO=



=== TEST 8: encode base32hex (no padding)
--- lua
local data = {
    "f",
    "fo",
    "foo",
    "foob",
    "fooba",
    "foobar",
    "",
    "sure.",
    "sure",
    "sur",
    "su",
    "leasure.",
    "easure.",
    "asure.",
    "sure.",
    "Twas brillig, and the slithy toves",
}
for _, d in ipairs(data) do
    local s = base_encoding.encode_base32hex(d, true)
    ngx.say(s)
end
--- response_body
CO
CPNG
CPNMU
CPNMUOG
CPNMUOJ1
CPNMUOJ1E8

EDQN4P9E
EDQN4P8
EDQN4
EDQG
DHIM2SRLE9IIS
CLGN6TBICKN0
C5PNASJ55O
EDQN4P9E
AHRM2SP0C9P6IR3CD5JIO831DPI20T38CKG76R39EHK7I83KDTR6ASO



=== TEST 9: decode base32hex
--- lua
local data = {
    'CO======',
    'CPNG====',
    'CPNMU===',
    'CPNMUOG=',
    'CPNMUOJ1',
    'CPNMUOJ1E8======',
    '',
    'EDQN4P9E',
    'EDQN4P8=',
    'EDQN4===',
    'EDQG====',
    'DHIM2SRLE9IIS===',
    'CLGN6TBICKN0====',
    'C5PNASJ55O======',
    'EDQN4P9E',
    'AHRM2SP0C9P6IR3CD5JIO831DPI20T38CKG76R39EHK7I83KDTR6ASO=',
}
for _, d in ipairs(data) do
    local s = base_encoding.decode_base32hex(d)
    ngx.say(s)
end
--- response_body
f
fo
foo
foob
fooba
foobar

sure.
sure
sur
su
leasure.
easure.
asure.
sure.
Twas brillig, and the slithy toves



=== TEST 10: decode base32hex (no padding)
--- lua
local data = {
    'CO',
    'CPNG',
    'CPNMU',
    'CPNMUOG',
    'CPNMUOJ1',
    'CPNMUOJ1E8',
    '',
    'EDQN4P9E',
    'EDQN4P8',
    'EDQN4',
    'EDQG',
    'DHIM2SRLE9IIS',
    'CLGN6TBICKN0',
    'C5PNASJ55O',
    'EDQN4P9E',
    'AHRM2SP0C9P6IR3CD5JIO831DPI20T38CKG76R39EHK7I83KDTR6ASO',
}
for _, d in ipairs(data) do
    local s = base_encoding.decode_base32hex(d)
    ngx.say(s)
end
--- response_body
f
fo
foo
foob
fooba
foobar

sure.
sure
sur
su
leasure.
easure.
asure.
sure.
Twas brillig, and the slithy toves



=== TEST 11: decode base32hex (invalid input)
--- lua
local data = {
    '========',
    'a===',
    's1u',
    'NRSWC48VOJSS4',
    'AAAAAA==',
    "AAA=====",
    "A=======",
    "AAAAA==",
    "A=",
    "AA=",
    "AA==",
    "AA===",
    "AAAA=",
    "AAAA==",
    "AAAAA=",
    "!!!!",
    "x===",
    "AA=A====",
    "AAA=AAAA",
    "MMMMMMMMM",
    "MMMMMM",
}

for _, d in ipairs(data) do
    local ok, err = base_encoding.decode_base32hex(d)
    ngx.say("decode: ", d, ": ", ok or err)
end
--- response_body
decode: ========: invalid input
decode: a===: invalid input
decode: s1u: invalid input
decode: NRSWC48VOJSS4: invalid input
decode: AAAAAA==: invalid input
decode: AAA=====: invalid input
decode: A=======: invalid input
decode: AAAAA==: invalid input
decode: A=: invalid input
decode: AA=: invalid input
decode: AA==: invalid input
decode: AA===: invalid input
decode: AAAA=: invalid input
decode: AAAA==: invalid input
decode: AAAAA=: invalid input
decode: !!!!: invalid input
decode: x===: invalid input
decode: AA=A====: invalid input
decode: AAA=AAAA: invalid input
decode: MMMMMMMMM: invalid input
decode: MMMMMM: invalid input



=== TEST 12: random tests, base32hex
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
        local encoded = base_encoding.encode_base32hex(raw)
        if base_encoding.decode_base32hex(encoded) ~= raw then
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



=== TEST 13: base32 (invalid args)
--- lua
local d = 123
local res = base_encoding.encode_base32(d)
ngx.say(tonumber(base_encoding.decode_base32(res)) == d)
local ok, err = pcall(base_encoding.decode_base32, d)
if not ok then
    ngx.say(err)
end
--- response_body
true
string argument only



=== TEST 14: base32hex (invalid args)
--- lua
local d = 456
local res = base_encoding.encode_base32hex(d)
ngx.say(tonumber(base_encoding.decode_base32hex(res)) == d)
local ok, err = pcall(base_encoding.decode_base32hex, d)
if not ok then
    ngx.say(err)
end
--- response_body
true
string argument only
