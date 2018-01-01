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
