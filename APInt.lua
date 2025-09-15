local APInt = {}
local APInt_metatable = {}
APInt.__index = APInt

local math_abs = math.abs
local math_floor = math.floor
local math_log10 = math.log10
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local string_format = string.format
local string_sub = string.sub
local string_match = string.match
local tonumber = tonumber
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local unpack = unpack or table.unpack -- Luau/5.2 compatibility

local POWER = 52
local BASE = 2^POWER
APInt.BASE = BASE
APInt.MODE = "NOT-STRICT"
local PRELOADED = {}

for i = -5, 256 do
    PRELOADED[i] = setmetatable({i}, APInt_metatable)
end

local supported_versions = { "Lua 5.2", "Luau" }
local supported = false
for _, version in pairs(supported_versions) do
    if version == _VERSION then
        supported = true
        break
    end
end
if not supported then
    warn("You are using an unsupported version of Lua for this library. If it's 5.2+, it should still work.")
end

assert(POWER % 2 == 0, "POWER must be an even number for multiplication to work properly")

local function invert(array)
    local n = #array
    local new = {}
    for i = 1, n do
        new[i] = array[n - i + 1]
    end
    return new
end

local function pad(array, amount)
    if amount <= 0 then return array end

    local array_n = #array
    local result = {}
    for i = 1, amount + array_n do
        if i <= amount then
            result[i] = 0
        else
            result[i] = array[i - amount]
        end
    end
    return result
end

local function __sign(x)
    return (x[#x] >= 0 and 1) or -1
end

function APInt.format(x)
    local is_number = type(x) == "number"
    if is_number then
        return string_format("%.f", x)
    end

    assert(APInt.__is_big_int(x), "Format argument is not a number or APInt")

    local digits = {}
    for i, v in ipairs(x) do
        digits[i] = string_format("%.f", v)
    end

    return table_concat(digits, ", ")
end

function APInt.table_print(x)
    print("{" .. APInt.format(x) .. "}")
end

local function typecheck(f)
    return function(...)
        local arguments = {...}
        for i, v in ipairs(arguments) do
            if not APInt.__is_big_int(v) then
                if APInt.MODE == "STRICT" then
                    error("Argument for operation was not APInt")
                else
                    if APInt.MODE == "WARNING" then
                        print("Argument for operation was not a APInt, converted")
                    end
                    arguments[i] = APInt.new(v)
                end
            end
        end
        return f(unpack(arguments))
    end
end

function APInt.__is_big_int(x)
    return type(x) == "table" and getmetatable(x) == APInt_metatable
end

local function __amount_digits(x)
    return #x
end

local function __abs(x)
    if x[#x] == 0 then
        return PRELOADED[0]
    end
    local clone = {unpack(x)}
    clone[#clone] = math_abs(clone[#clone])
    return APInt.new(clone)
end

local function __remove_trailing_zeros(digits)
    local n = #digits
    while n > 1 and digits[n] == 0 do
        n = n - 1
    end
    if n == #digits then
        return digits
    end
    if n == 0 then
        return {0}
    end
    local new_digits = {}
    for i = 1, n do
        new_digits[i] = digits[i]
    end
    return new_digits
end

local function __max(a, b)
    return (a > b and a) or b
end

local function __min(a, b)
    return (a < b and a) or b
end

local function __add(a, b)
    if __sign(a) ~= __sign(b) then
        return ((__sign(a) == 1) and (__abs(a) - __abs(b))) or (__abs(b) - __abs(a))
    end

    local a_n, b_n = #a, #b
    local max_len = (a_n > b_n and a_n) or b_n
    local digits = {}
    local carry = 0

    for i = 1, max_len do
        local a0 = a[i] or 0
        local b0 = b[i] or 0
        local sum = a0 + b0 + carry
        if sum >= BASE then
            digits[i] = sum - BASE
            carry = 1
        else
            digits[i] = sum
            carry = 0
        end
    end

    if carry ~= 0 then
        digits[max_len + 1] = carry
    end

    return APInt.new(digits, __sign(a))
end

local function __sub(a, b)
    if __sign(a) ~= __sign(b) then
        return __add(a, -b)
    end
    if (__sign(a) == -1) then -- Implies __sign(b) == -1
        return __sub(-b, -a)
    end

    local a_abs, b_abs = __abs(a), __abs(b)
    local bigger, smaller
    local result_sign = 1
    if a_abs < b_abs then
        bigger, smaller = b_abs, a_abs
        result_sign = -1
    else
        bigger, smaller = a_abs, b_abs
    end

    local bigger_n = #bigger
    local digits = {}
    local carry = 0

    for i = 1, bigger_n do
        local subtraction = bigger[i] - (smaller[i] or 0) - carry
        if subtraction < 0 then
            subtraction = subtraction + BASE
            carry = 1
        else
            carry = 0
        end
        digits[i] = subtraction
    end
    
    local result = APInt.new(__remove_trailing_zeros(digits))
    return result_sign == 1 and result or -result
end

-- https://en.wikipedia.org/wiki/Multiplication_algorithm
-- with a small difference in how i calculate the intermediate products to not overflow the base
local function textbook_mul(a, b)
    local SPLIT_BASE = 2^(POWER / 2)
    local a_digits, b_digits = a, b
    local a_n, b_n = #a_digits, #b_digits
    local len = a_n + b_n
    local result = {}
    for i = 1, len do result[i] = 0 end

    for i = 1, a_n do
        local carry_row = 0
        for j = 1, b_n do
            local pos = i + j - 1

            -- splitting to not overflow

            local a_i = a_digits[i]
            local a_hi = math_floor(a_i / SPLIT_BASE)
            local a_lo = a_i % SPLIT_BASE

            local b_j = b_digits[j]
            local b_hi = math_floor(b_j / SPLIT_BASE)
            local b_lo = b_j % SPLIT_BASE

            local term1 = a_hi * b_hi
            local term2 = a_hi * b_lo
            local term3 = a_lo * b_hi
            local term4 = a_lo * b_lo

            local term23 = term2 + term3
            local term23_hi = math_floor(term23 / SPLIT_BASE)
            local term23_lo = term23 % SPLIT_BASE

            local low = term4 + term23_lo * SPLIT_BASE
            local carry1 = math_floor(low / BASE)
            local digit_part = low % BASE
            local total_carry = term1 + term23_hi + carry1

            local temp = result[pos] + digit_part + carry_row
            carry_row = math_floor(temp / BASE)
            result[pos] = temp % BASE
            carry_row = carry_row + total_carry
        end

        local pos = i + b_n
        while carry_row > 0 do
            local temp = result[pos] + carry_row
            carry_row = math_floor(temp / BASE)
            result[pos] = temp % BASE
            pos = pos + 1
        end
    end
    
    return APInt.new(__remove_trailing_zeros(result))
end

local function __mul(a, b)
    if a == PRELOADED[0] or b == PRELOADED[0] then
        return PRELOADED[0]
    end

    local result = textbook_mul(__abs(a), __abs(b))
    local sign = __sign(a) * __sign(b)

    return sign == -1 and -result or result
end

-- a variation of the long division algorithm https://en.wikipedia.org/wiki/Long_division
-- (restoring long division https://www.geeksforgeeks.org/computer-organization-architecture/restoring-division-algorithm-unsigned-integer/)
local function fast_long_division(a, b)
    if a < b then
        return PRELOADED[0], a
    end

    local remainder = a
    local divisor = b
    local quotient_digits = {}
    
    local shift = #remainder - #divisor
    local shifted_divisor = APInt.new(pad(divisor, shift))
    if shifted_divisor > remainder then
        shift = shift - 1
        shifted_divisor = APInt.new(pad(divisor, shift))
    end
    
    local BASE_MINUS_1 = BASE - 1

    while shift >= 0 do
        local q_hat = 0
        if remainder >= shifted_divisor then
            local rem_len = #remainder
            local b_len = #divisor
            local rem_top_val
            if rem_len > shift + b_len then
                rem_top_val = remainder[rem_len] * BASE + (remainder[rem_len - 1] or 0)
            else
                rem_top_val = remainder[rem_len] or 0
            end
            local div_top_val = divisor[b_len]
            
            local q_est = 0
            if div_top_val ~= 0 then
                q_est = math_floor(rem_top_val / div_top_val)
            end
            
            q_hat = (q_est < BASE_MINUS_1 and q_est) or BASE_MINUS_1

            local product = shifted_divisor * APInt.new(q_hat)
            while product > remainder do
                q_hat = q_hat - 1
                product = product - shifted_divisor
            end
            
            if q_hat > 0 then
                remainder = remainder - product
            end
        end
        
        table_insert(quotient_digits, q_hat)
        shift = shift - 1
        
        if shift >= 0 then
            local digits = {unpack(shifted_divisor)}
            table_remove(digits, 1)
            shifted_divisor = APInt.new(digits)
        end
    end
    
    return APInt.new(__remove_trailing_zeros(invert(quotient_digits))), remainder
end

local function __div(a, b)
    assert(b ~= PRELOADED[0], "Division by 0")
    local sign = __sign(a) * __sign(b)
    local abs_a, abs_b = __abs(a), __abs(b)
    local q, r = fast_long_division(abs_a, abs_b)
    return q * APInt.new(sign), r
end

local function __mod(a, b)
    assert(b ~= PRELOADED[0], "Modulo by 0")
    local _, modulo = __div(a, b)
    if __sign(a) == -1 and modulo ~= PRELOADED[0] then
        modulo = __abs(b) - modulo
    end
    return modulo
end

-- lazy, probably for bigger number a fast exponentiation algorithm could be faster 
local function __pow(a, b)
    if b < PRELOADED[0] then
        assert(a ~= PRELOADED[0], "Negative power of 0")
        return (a == PRELOADED[1] and PRELOADED[1]) or PRELOADED[0]
    end
    if b == PRELOADED[0] then return PRELOADED[1] end
    if b == PRELOADED[1] then return a end

    local result = PRELOADED[1]
    local i = PRELOADED[0]
    while i < b do
        result = result * a
        i = i + PRELOADED[1]
    end
    return result
end

local function __eq(a, b)
    if type(a) ~= type(b) then return false end
    local a_n = #a
    if a_n ~= #b or __sign(a) ~= __sign(b) then return false end
    for i = 1, a_n do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function __lt(a, b)
    local sign_a, sign_b = __sign(a), __sign(b)
    if sign_a ~= sign_b then return sign_a < sign_b end
    
    local a_n, b_n = #a, #b
    if a_n ~= b_n then
        return (a_n < b_n and sign_a == 1) or (a_n > b_n and sign_a == -1)
    end

    for i = a_n, 1, -1 do
        if a[i] ~= b[i] then
            return (a[i] < b[i] and sign_a == 1) or (a[i] > b[i] and sign_a == -1)
        end
    end
    return false
end

local function __unm(x)
    if x[#x] == 0 then return PRELOADED[0] end
    local clone = {unpack(x)}
    clone[#clone] = -clone[#clone]
    return APInt.new(clone)
end

local TOSTRING_DIVISOR_DIGITS = math_floor(math_log10(BASE))
local TOSTRING_DIVISOR = nil
local PADDING_FORMAT = "%0" .. TOSTRING_DIVISOR_DIGITS .. "d"

local function __tostring(x)
    if not TOSTRING_DIVISOR then
        TOSTRING_DIVISOR = APInt.new(10^TOSTRING_DIVISOR_DIGITS)
    end

    if __eq(x, PRELOADED[0]) then return "0" end

    local work_val = __abs(x)
    local sign = (__sign(x) == -1) and "-" or ""
    local parts = {}
    
    while work_val > PRELOADED[0] do
        local quotient, remainder = __div(work_val, TOSTRING_DIVISOR)
        local remainder_val = (remainder[1] or 0)
        table_insert(parts, 1, remainder_val)
        work_val = quotient
    end
    
    local first = parts[1]
    local str = sign .. first
    for i = 2, #parts do
        str = str .. string_format(PADDING_FORMAT, parts[i])
    end

    return str
end

function APInt.from_string(s)
    assert(type(s) == "string", "Argument to from_string must be a string")
    
    local sign = 1
    if string_sub(s, 1, 1) == "-" then
        sign = -1
        s = string_sub(s, 2)
    end
    assert(string_match(s, "^[0-9]+$"), "Invalid number string format")
    
    if not TOSTRING_DIVISOR then
        TOSTRING_DIVISOR = APInt.new(10^TOSTRING_DIVISOR_DIGITS)
    end

    local result = PRELOADED[0]
    local len = #s
    local first_chunk_len = len % TOSTRING_DIVISOR_DIGITS
    if first_chunk_len == 0 and len > 0 then
        first_chunk_len = TOSTRING_DIVISOR_DIGITS
    end

    local current_pos = 1
    if first_chunk_len > 0 then
        local first_chunk_str = string_sub(s, 1, first_chunk_len)
        result = APInt.new(tonumber(first_chunk_str))
        current_pos = first_chunk_len + 1
    end

    while current_pos <= len do
        local chunk_str = string_sub(s, current_pos, current_pos + TOSTRING_DIVISOR_DIGITS - 1)
        result = result * TOSTRING_DIVISOR + APInt.new(tonumber(chunk_str))
        current_pos = current_pos + TOSTRING_DIVISOR_DIGITS
    end
    
    return sign == -1 and -result or result
end

function APInt.new(x, sign)
    if APInt.__is_big_int(x) then
        if sign and __sign(x) ~= sign then
            return -x
        end
        return x
    end
    
    if type(x) == "string" then
        assert(sign == nil, "Cannot provide a sign argument when creating from a string")
        return APInt.from_string(x)
    end
    
    if type(x) == "number" and PRELOADED[x] then
        return PRELOADED[x]
    end

    assert(type(x) == "number" or type(x) == "table", "Argument of new must be an integer, string, or a APInt table representation")

    local digits
    if type(x) == "number" then
        assert(x % 1 == 0, "The number passed must be a whole number")
        assert((-BASE < x) and (x < BASE), "Number is out of single-digit range")
        digits = {x}
    else -- type(x) == "table"
        local last = x[#x]
        if last then
             assert(-BASE < last and last < BASE, "Last element of digits table is out of range")
        end
        for i = 1, #x - 1 do
            local v = x[i]
            assert(0 <= v and v < BASE, "Elements of digits table are out of range")
        end
        digits = x
    end

    if sign and digits[#digits] then
        digits[#digits] = math_abs(digits[#digits]) * sign
    end
    
    return setmetatable(digits, APInt_metatable)
end


APInt_metatable.__index = APInt
APInt_metatable.__add = typecheck(__add)
APInt_metatable.__sub = typecheck(__sub)
APInt_metatable.__mod = typecheck(__mod)
APInt_metatable.__div = typecheck(__div)
APInt_metatable.__mul = typecheck(__mul)
APInt_metatable.__pow = typecheck(__pow)
APInt_metatable.__tostring = __tostring
APInt_metatable.__unm = typecheck(__unm)
APInt_metatable.__lt = typecheck(__lt)
APInt_metatable.__eq = __eq

local call_proxy = {
    __call = function(_, x, sign)
        return APInt.new(x, sign)
    end
}
setmetatable(APInt, call_proxy)

return APInt