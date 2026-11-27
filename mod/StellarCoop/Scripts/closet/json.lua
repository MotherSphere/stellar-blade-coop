-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: a small JSON decoder written for this mod. Pure Lua 5.4.
--
-- Takes what creator packs actually carry: objects, arrays, strings with escapes (\uXXXX and surrogate pairs to
-- UTF-8), numbers, true/false/null, and // or /* */ comments and trailing commas, which hand-written packs often
-- have. null decodes to Json.null so a present-but-null key is not mistaken for a missing one.
-- decode(text) returns value, or nil and an error message with the line number. Never raises on bad input.
local Json = {}

Json.null = setmetatable({}, {__tostring = function() return 'null' end})

local function line_of(text, at)
    local line = 1
    for _ in text:sub(1, at):gmatch('\n') do line = line + 1 end
    return line
end

local function utf8_char(code)
    if code < 0x80 then return string.char(code) end
    return utf8.char(code)
end

local Parser = {}
Parser.__index = Parser

function Parser:fail(message)
    error({json_error = ('line %d: %s'):format(line_of(self.text, self.at), message)}, 0)
end

function Parser:skip()
    local text = self.text
    while true do
        local _, stop = text:find('^[ \t\r\n]+', self.at)
        if stop then self.at = stop + 1 end
        if text:sub(self.at, self.at + 1) == '//' then
            local nl = text:find('\n', self.at, true)
            self.at = nl and nl + 1 or #text + 1
        elseif text:sub(self.at, self.at + 1) == '/*' then
            local close = text:find('*/', self.at + 2, true)
            if not close then self:fail('unclosed comment') end
            self.at = close + 2
        else
            return
        end
    end
end

function Parser:peek()
    self:skip()
    return self.text:sub(self.at, self.at)
end

function Parser:string()
    local text, parts = self.text, {}
    self.at = self.at + 1 -- opening quote
    while true do
        local start = self.at
        local stop = text:find('["\\%c]', start)
        if not stop then self:fail('unclosed string') end
        parts[#parts + 1] = text:sub(start, stop - 1)
        local c = text:sub(stop, stop)
        if c == '"' then
            self.at = stop + 1
            return table.concat(parts)
        elseif c == '\\' then
            local e = text:sub(stop + 1, stop + 1)
            local simple = ({['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r',
                t = '\t'})[e]
            if simple then
                parts[#parts + 1] = simple
                self.at = stop + 2
            elseif e == 'u' then
                local hex = text:sub(stop + 2, stop + 5)
                if not hex:match('^%x%x%x%x$') then self:fail('bad \\u escape') end
                local code = tonumber(hex, 16)
                self.at = stop + 6
                if code >= 0xD800 and code <= 0xDBFF then
                    local low = text:match('^\\u(%x%x%x%x)', self.at)
                    local low_code = low and tonumber(low, 16)
                    if low_code and low_code >= 0xDC00 and low_code <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (low_code - 0xDC00)
                        self.at = self.at + 6
                    else
                        code = 0xFFFD
                    end
                elseif code >= 0xDC00 and code <= 0xDFFF then
                    code = 0xFFFD
                end
                parts[#parts + 1] = utf8_char(code)
            else
                self:fail('bad escape \\' .. e)
            end
        else
            self:fail('control character in string')
        end
    end
end

function Parser:number()
    local s = self.text:match('^-?%d+%.?%d*[eE]?[-+]?%d*', self.at)
    local n = s and tonumber(s)
    if not n then self:fail('bad number') end
    self.at = self.at + #s
    return n
end

function Parser:value(depth)
    if depth > 64 then self:fail('nested too deep') end
    local c = self:peek()
    if c == '{' then
        local object = {}
        self.at = self.at + 1
        if self:peek() == '}' then self.at = self.at + 1 return object end
        while true do
            if self:peek() ~= '"' then self:fail('expected a key') end
            local key = self:string()
            if self:peek() ~= ':' then self:fail('expected : after key "' .. key .. '"') end
            self.at = self.at + 1
            object[key] = self:value(depth + 1)
            c = self:peek()
            if c == ',' then
                self.at = self.at + 1
                if self:peek() == '}' then self.at = self.at + 1 return object end -- trailing comma
            elseif c == '}' then
                self.at = self.at + 1
                return object
            else
                self:fail('expected , or }')
            end
        end
    elseif c == '[' then
        local array = {}
        self.at = self.at + 1
        if self:peek() == ']' then self.at = self.at + 1 return array end
        while true do
            array[#array + 1] = self:value(depth + 1)
            c = self:peek()
            if c == ',' then
                self.at = self.at + 1
                if self:peek() == ']' then self.at = self.at + 1 return array end
            elseif c == ']' then
                self.at = self.at + 1
                return array
            else
                self:fail('expected , or ]')
            end
        end
    elseif c == '"' then
        return self:string()
    elseif c == '-' or c:match('%d') then
        return self:number()
    else
        for word, result in pairs({['true'] = true, ['false'] = false, null = Json.null}) do
            if self.text:sub(self.at, self.at + #word - 1) == word then
                self.at = self.at + #word
                return result
            end
        end
        self:fail(c == '' and 'unexpected end of text' or 'unexpected character ' .. c)
    end
end

function Json.decode(text)
    if type(text) ~= 'string' then return nil, 'not text' end
    if text:sub(1, 3) == '\239\187\191' then text = text:sub(4) end -- UTF-8 BOM
    local parser = setmetatable({text = text, at = 1}, Parser)
    local ok, result = pcall(function()
        local value = parser:value(0)
        if parser:peek() ~= '' then parser:fail('text after the value') end
        return value
    end)
    if ok then return result end
    if type(result) == 'table' and result.json_error then return nil, result.json_error end
    return nil, tostring(result)
end

return Json
