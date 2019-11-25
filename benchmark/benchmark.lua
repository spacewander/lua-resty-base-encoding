#!/usr/bin/env resty
local basexx = require "basexx"
local be = require "resty.base_encoding"
local ffi = require "ffi"
require "table.clone"
local b64 = require "ngx.base64"

local function ch2v(str, i)
    local ch = string.byte(str, i, i)
    if 48 <= ch and ch <= 57 then -- 0-9
        return ch - 48
    elseif 65 <= ch and ch <= 70 then -- A-F
        return ch - 55
    elseif 97 <= ch and ch <= 102 then -- a-f
        return ch - 87
    else
        error("invalid char num " .. ch)
    end
end

local function v2ch(v)
    if 0 <= v and v <= 9 then
        return 48 + v
    end
    return 87 + v
end

local function decode_base16(str)
    local buf = ffi.new("char[?]", #str / 2)
    for i = 1, #str/2 do
        buf[i-1] = ch2v(str, i*2-1) * 16 + ch2v(str, i*2)
    end
    return ffi.string(buf, #str / 2)
end

local function encode_base16(str)
    local buf = ffi.new("char[?]", #str * 2)
    for i = 1, #str do
        local v = string.byte(str, i, i)
        local b = v % 16
        local a = (v - b) / 16
        buf[i*2-2] = v2ch(a)
        buf[i*2-1] = v2ch(b)
    end
    return ffi.string(buf, #str * 2)
end


local function short_input(cases, chars)
    local size = 64
    local turns = chars / size
    for _ = 1, turns do
        local buf = table.new(size, 0)
        for i = 1, size do
            buf[i] = math.random(0, 127)
        end

        table.insert(cases, string.char(unpack(buf)))
    end
end

local function long_input(cases, chars)
    local size = 1024 * 1024
    local turns = chars / size
    for _ = 1, turns do
        local buf = ffi.new("char[?]", size)
        for i = 1, size do
            buf[i-1] = math.random(0, 127)
        end

        table.insert(cases, ffi.string(buf, size))
    end
end

local be_name = "lua-resty-base-encoding"
local bx_name = "basexx"
local bc_name = "lua-resty-core"
local groups = {
    {title = "test base2",
    players = {
        { name = be_name, encode = be.encode_base2, decode = be.decode_base2, },
        { name = bx_name, encode = basexx.to_bit, decode = basexx.from_bit, },
    }},
    {title = "test base16",
    players = {
        { name = be_name, encode = be.encode_base16, decode = be.decode_base16, },
        { name = bx_name, encode = basexx.to_hex, decode = basexx.from_hex, },
        { name = "FFI", encode = encode_base16, decode = decode_base16, },
    }},
    {title = "test base32",
    players = {
        { name = be_name, encode = be.encode_base32, decode = be.decode_base32, },
        { name = bx_name, encode = basexx.to_base32, decode = basexx.from_base32, },
    }},
    {title = "test base85",
    players = {
        { name = be_name, encode = be.encode_base85, decode = be.decode_base85, },
        { name = bx_name, encode = basexx.to_z85, decode = basexx.from_z85, },
    }},
    {title = "test base64",
    players = {
        { name = be_name, encode = be.encode_base64, decode = be.decode_base64, },
        { name = bc_name, encode = ngx.encode_base64, decode = ngx.decode_base64, },
    }},
    {title = "test base64url",
    players = {
        { name = be_name, encode = be.encode_base64url, decode = be.decode_base64url, },
        { name = bc_name, encode = b64.encode_base64url, decode = b64.decode_base64url, },
    }},
}
local function run_player(title, is_short, player)
    local raws = {}
    local chs
    local encode = player.encode
    local decode = player.decode
    if is_short then
        chs = 64 * 1e4
        short_input(raws, chs)
    else
        chs = 1024 * 1024
        long_input(raws, chs)
    end
    local encodeds = table.clone(raws)

    ngx.say("\n", title, " ", is_short and 'short' or 'long',  " ", player.name)
    ngx.update_time()
    local start = ngx.now()
    for i, raw in ipairs(raws) do
        encodeds[i] = encode(raw)
    end
    ngx.update_time()
    ngx.say("encode ", chs / (ngx.now() - start) / 1024 / 1024)

    ngx.update_time()
    local start = ngx.now()
    for i, encoded in ipairs(encodeds) do
        raws[i] = decode(encoded)
    end
    ngx.update_time()
    ngx.say("decode ", chs / (ngx.now() - start) / 1024 / 1024)
end

for _, group in ipairs(groups) do
    local title = group.title

    for _, player in ipairs(group.players) do
        run_player(title, true, player)
        run_player(title, false, player)
    end
end
