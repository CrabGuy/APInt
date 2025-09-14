local APInt = {}
local APInt_metatable = {}
APInt.__index = APInt
local POWER = 52
local BASE = 2^POWER -- MAX 2^53
APInt.BASE = BASE
APInt.MODE = "NOT-STRICT"
local PRELOADED = {}

local supported_versions = {
    "Lua 5.2",
    "Luau"
}

local supported = false
for _, version in pairs(supported_versions) do
    if version == _VERSION then
        supported = true
        break
    end
end

if not supported then
    warn("You are using an unsupported version of lua for this library, if its 5.2+ it should still work")
end

assert(POWER % 2 == 0, "POWER must be an even number for multiplication to work properly")

local function invert(array)
    local new = {}

    for i = #array, 1, -1 do
        table.insert(new, array[i])
    end

    return new
end

local function pad(array, amount)
    if amount <= 0 then return array end
    local result = {}
    for i = 1, amount do
        table.insert(result, 0)
    end

    for i = 1, #array do
        table.insert(result, array[i])
    end

    return result
end

local function __sign(x)
    return (x[#x] >= 0 and 1) or -1
end

function APInt.format(x)
    local is_number = type(x) == "number"
    local is_big_int = type(x) == "table" and APInt.__is_big_int(x)

    if is_number then
        return string.format("%.f", x)
    end

    assert(is_big_int, "Format argument is not a number")

    local digits = {}
    for i, v in pairs(x) do
        table.insert(digits, string.format("%.f", v))
    end

    local text = table.concat(digits, ", ")
    return text
end

function APInt.table_print(x)
    print("{".. APInt.format(x).. "}")
end

local function typecheck(f)
    return function(...)
        local arguments = {...}
        for i, v in pairs(arguments) do
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
    local clone = {unpack(x)}
    if x[#x] == 0 then
        return APInt.new(0)
    end
    clone[#clone] = math.abs(clone[#clone])

    return APInt.new(clone)
end

local function __add(a, b)
    if __sign(a) ~= __sign(b) then
        return ((__sign(a) == 1) and (__abs(a) - __abs(b))) or (__abs(b) - __abs(a))
    end

    local digits = {}
    local carry = 0

    local i = 1
    while (i <= __amount_digits(a)) or (i <= __amount_digits(b)) do
        local a0 = a[i] or 0
        local b0 = b[i] or 0
        if BASE - b0 <= a0 + carry then
            table.insert(digits, (b0 - BASE) + a0 + carry)
            carry = 1
        else
            table.insert(digits, a0 + b0 + carry)
            carry = 0
        end
        i = i + 1
    end

    if carry ~= 0 then
        table.insert(digits, carry)
    end

    return APInt.new(digits, __sign(a))
end

local function __max(a, b)
    return ((a > b) and a) or b
end

local function __min(a, b)
    if APInt.__is_big_int(a) then
        return (a < b and a) or b
    else
        return (a < b and a) or b
    end
end

local function __remove_trailing_zeros(digits)
    for i = #digits, 1, -1 do
        if digits[i] == 0 then
            table.remove(digits, i)
        else
            break
        end
    end
    if #digits == 0 then
        return {0}
    end
    return digits
end

local function __sub(a, b)
    if __sign(a) ~= __sign(b) then
        return __add(a, -b)
    end
    if (__sign(a) == -1) and (__sign(b) == -1) then
        return __sub(b, a)
    end

    local bigger = __max(__abs(a), __abs(b))
    local smaller = __min(__abs(a), __abs(b))


    local digits = {}
    local carry = 0

    local i = 1
    while i <= __amount_digits(bigger) do
        local subtraction = bigger[i] - (smaller[i] or 0) - carry
        carry = 0
        if subtraction < 0 then
            subtraction = BASE + subtraction
            carry = 1
        end
        table.insert(digits, subtraction)
        i = i + 1
    end

    local result = APInt.new(__remove_trailing_zeros(digits))
    return ((__abs(a) > __abs(b)) and result) or -result
end

local function __eq(a, b)
    if type(a) ~= type(b) then
        return false
    end

    if (__sign(a) ~= __sign(b)) or (__amount_digits(a) ~= __amount_digits(b)) then
        return false
    end

    for i = 1, __amount_digits(a) do
        if a[i] ~= b[i] then
            return false
        end
    end

    return true
end

local function __lt(a, b)
    if __sign(a) ~= __sign(b) then
        return __sign(a) == -1
    end
    
    local sign = __sign(a) -- Both have the same sign

    if __amount_digits(a) ~= __amount_digits(b) then
        return (__amount_digits(a) < __amount_digits(b) and sign == 1) or (__amount_digits(a) > __amount_digits(b) and sign == -1)
    end

    if __eq(a, b) then
        return false
    end

    for i = __amount_digits(a), 1, -1 do
        if a[i] ~= b[i] then
            return (a[i] < b[i] and sign == 1) or (a[i] > b[i] and sign == -1)
        end
    end

    return false
end

local function __lsl(a, b)
    if b ~= APInt.new(1) then
        local result = a
        local i = APInt.new(1)
        while i <= b do
            result = __lsl(result, APInt.new(1))
            i = i + APInt.new(1)
        end
        return result * APInt.new(__sign(a)) * APInt.new(__sign(b))
    end

    local digits = {}
    local carry = 0
    for i = #a, 1, -1 do
        local result = math.floor(a[i] / 2)
        if carry == 1 then
            result = result + BASE/2
        end
        carry = 0
        carry = a[i] % 2
        digits[i] = result
    end

    return APInt.new(__remove_trailing_zeros(digits)) * APInt.new(__sign(a)) * APInt.new(__sign(b))
end

local function __lsr(a, b)
    b = ((b == nil) and APInt.new(1)) or b

    if b ~= APInt.new(1) then
        local result = a
        local i = APInt.new(1)
        while i <= b do
            result = __lsr(result, APInt.new(1))
            i = i + APInt.new(1)
        end
        return result
    end

    local digits = {}
    local carry = 0
    for i = 1, #a do
        local old_carry = carry
        digits[i] = a[i]
        carry = 0
        if digits[i] > (BASE/2) then
            digits[i] = digits[i] % (BASE/2)
            carry = 1
        end
        digits[i] = digits[i] * 2 + old_carry
    end

    if carry ~= 0 then
        table.insert(digits, carry)
    end

    return APInt.new(digits, __sign(a))
end

local function fast_long_division(a, b)
    if a < b then
        return APInt.new(0), a
    end

    local remainder = APInt.new(a)
    local divisor = b
    local quotient_digits = {}
    
    local shift = __amount_digits(remainder) - __amount_digits(divisor)

    local shifted_divisor = APInt.new(pad(divisor, shift))
    if shifted_divisor > remainder then
        shift = shift - 1
        shifted_divisor = APInt.new(pad(divisor, shift))
    end

    while shift >= 0 do
        local q_hat = 0
        if remainder >= shifted_divisor then
            -- Estimate q_hat using Knuth's method
            -- https://skanthak.hier-im-netz.de/division.html
            local rem_len = __amount_digits(remainder)
            local b_len = __amount_digits(divisor)

            local rem_top_val
            if rem_len > shift + b_len then
                rem_top_val = remainder[rem_len] * BASE + (remainder[rem_len - 1] or 0)
            else
                rem_top_val = remainder[rem_len] or 0
            end
            
            local div_top_val = divisor[b_len]
            
            local q_est = 0
            if div_top_val ~= 0 then
                q_est = math.floor(rem_top_val / div_top_val)
            end
            
            q_hat = __min(q_est, BASE - 1)

            -- Correction step. The estimate can be off by 1 or 2.
            local product = shifted_divisor * APInt.new(q_hat)
            while product > remainder do
                q_hat = q_hat - 1
                product = shifted_divisor * APInt.new(q_hat)
            end
            
            if q_hat > 0 then
                remainder = remainder - product
            end
        end
        
        table.insert(quotient_digits, q_hat)

        shift = shift - 1
        if shift >= 0 then
            local digits = {unpack(shifted_divisor)}
            table.remove(digits, 1)
            shifted_divisor = APInt.new(digits)
        end
    end
    
    local final_quotient_digits = invert(quotient_digits)
    return APInt.new(__remove_trailing_zeros(final_quotient_digits)), remainder
end


local function __div(a, b)
    assert(b ~= APInt.new(0), "Division by 0")
    local sign = __sign(a) * __sign(b)

    local abs_a = __abs(a)
    local abs_b = __abs(b)

    local q, r = fast_long_division(abs_a, abs_b)

    return q * APInt.new(sign), r
end

local function __mod(a, b)
    local _, modulo = __div(a, b)

    if __sign(a) == -1 and modulo ~= APInt.new(0) then
        modulo = __abs(b) - modulo
    end

    return modulo
end

local function textbook_mul(a, b)
    local SPLIT_BASE = 2^(POWER / 2)
    local BASE = APInt.BASE
    local a_digits = a
    local b_digits = b
    local result = {}
    local len = #a_digits + #b_digits

    for i = 1, len do
        result[i] = 0
    end

    for i = 1, #a_digits do
        local carry_row = 0
        for j = 1, #b_digits do
            local pos = i + j - 1

            local a_i = a_digits[i]
            local a_hi = math.floor(a_i / SPLIT_BASE)
            local a_lo = a_i % SPLIT_BASE

            local b_j = b_digits[j]
            local b_hi = math.floor(b_j / SPLIT_BASE)
            local b_lo = b_j % SPLIT_BASE

            local term1 = a_hi * b_hi
            local term2 = a_hi * b_lo
            local term3 = a_lo * b_hi
            local term4 = a_lo * b_lo

            local term23 = term2 + term3
            local term23_hi = math.floor(term23 / SPLIT_BASE)
            local term23_lo = term23 % SPLIT_BASE


            local low = term4 + term23_lo * SPLIT_BASE
            local carry1 = math.floor(low / BASE)
            local digit_part = low % BASE

            local total_carry = term1 + term23_hi + carry1

            local temp = result[pos] + digit_part + carry_row
            carry_row = math.floor(temp / BASE)
            result[pos] = temp % BASE


            carry_row = carry_row + total_carry
        end


        local pos = i + #b_digits
        while carry_row ~= 0 do
            if pos > #result then
                table.insert(result, 0)
            end
            local temp = result[pos] + carry_row
            carry_row = math.floor(temp / BASE)
            result[pos] = temp % BASE
            pos = pos + 1
        end
    end

    result = __remove_trailing_zeros(result)

    if #result == 0 then
        return APInt.new(0)
    end

    return APInt.new(result)
end

local function __mul(a, b)
    if a == APInt.new(0) or b == APInt.new(0) then
        return APInt.new(0)
    end

    local sign = __sign(a) * __sign(b)
    local result = textbook_mul(__abs(a), __abs(b))

    if sign == -1 then
        return -result
    else
        return result
    end
end

local TOSTRING_DIVISOR_DIGITS = math.floor(math.log10(BASE))
local TOSTRING_DIVISOR = nil -- This will be initialized after APInt.new is available.
local PADDING_FORMAT = "%0" .. TOSTRING_DIVISOR_DIGITS .. ".f"

local function __tostring(x)
    if not TOSTRING_DIVISOR then
        TOSTRING_DIVISOR = APInt.new(10^TOSTRING_DIVISOR_DIGITS)
    end

    if __eq(x, APInt.new(0)) then
        return "0"
    end

    if __lt(__abs(x), TOSTRING_DIVISOR) then
        return string.format("%.f", x[#x])
    end

    local work_val = __abs(x)
    local sign = (__sign(x) == -1) and "-" or ""

    local parts = {}
    while __lt(APInt.new(0), work_val) do
        local quotient, remainder = __div(work_val, TOSTRING_DIVISOR)

        local remainder_val = remainder[1] or 0
        table.insert(parts, 1, string.format(PADDING_FORMAT, remainder_val))
        
        work_val = quotient
    end

    parts[1] = parts[1]:gsub("^0+", "")

    return sign .. table.concat(parts, "")
end

function APInt.from_string(s)
    assert(type(s) == "string", "Argument to from_string must be a string")

    local sign = 1
    if s:sub(1, 1) == "-" then
        sign = -1
        s = s:sub(2)
    end

    assert(s:match("^[0-9]+$"), "Invalid number string format")
    
    if not TOSTRING_DIVISOR then
        TOSTRING_DIVISOR = APInt.new(10^TOSTRING_DIVISOR_DIGITS)
    end

    local result = APInt.new(0)
    local current_pos = 1
    local len = #s

    local first_chunk_len = len % TOSTRING_DIVISOR_DIGITS
    if first_chunk_len == 0 and len > 0 then
        first_chunk_len = TOSTRING_DIVISOR_DIGITS
    end

    if first_chunk_len > 0 then
        local first_chunk_str = s:sub(current_pos, current_pos + first_chunk_len - 1)
        result = APInt.new(tonumber(first_chunk_str))
        current_pos = current_pos + first_chunk_len
    end

    while current_pos <= len do
        local chunk_str = s:sub(current_pos, current_pos + TOSTRING_DIVISOR_DIGITS - 1)
        result = result * TOSTRING_DIVISOR + APInt.new(tonumber(chunk_str))
        current_pos = current_pos + TOSTRING_DIVISOR_DIGITS
    end

    if sign == -1 then
        return -result
    else
        return result
    end
end

local function __unm(x)
    local clone = {unpack(x)}
    if x[#x] == 0 then
        return APInt.new(0)
    end

    clone[#clone] = clone[#clone] * -1

    return APInt.new(clone)
end

-- lazy, could implement a fast exponentiation algorithm
local function __pow(a, b)
    if b < APInt.new(0) then
        assert(a ~= APInt.new(0), "Negative power of 0")
        return (a == APInt.new(1) and APInt.new(1)) or APInt.new(0)
    end

    local result = APInt.new(1)
    local i = APInt.new(1)
    while i <= b do
        i = i + APInt.new(1)
        result = result * a
    end
    return result
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

    if PRELOADED[x] then
        return PRELOADED[x]
    end

    assert(type(x) == "number" or type(x) == "table", "Argument of new must be an integer, string, or a APInt table representation")

    local digits

    if type(x) == "number" then
        assert(x % 1 == 0, "The number passed must be a whole number")
        assert((-BASE < x) and (x < BASE), "Argument must be between " .. string.format("%.f", -BASE) .. " and " .. string.format("%.f", BASE))
        digits = {x}
    end
    if type(x) == "table" then
        local last = x[#x]
        if last then
             assert(-BASE < last and last < BASE, "Last element of the digits table needs to be between " .. string.format("%.f", -BASE) .. " and " .. string.format("%.f", BASE))
        end
        for i = 1, #x - 1 do
            local v = x[i]
            assert(0 <= v)
            assert(0 <= v and v < BASE, "Every element except the last of the digits table needs to be between 0 (inclusive) and " .. string.format("%.f", BASE))
        end
        digits = x
    end

    if sign and digits[#digits] then
        digits[#digits] = math.abs(digits[#digits]) * sign
    end

    assert(digits ~= nil)
    return setmetatable(digits, APInt_metatable) --read_only()
end

-- Preloading some numbers like python does
for i = -5, 256 do
    PRELOADED[i] = APInt.new(i)
end

APInt_metatable.__index = APInt
APInt_metatable.__add = typecheck(__add)
APInt_metatable.__sub = typecheck(__sub)
APInt_metatable.__mod = typecheck(__mod)
APInt_metatable.__div = typecheck(__div)
APInt_metatable.__mul = typecheck(__mul)
APInt_metatable.__tostring = __tostring
APInt_metatable.__unm = typecheck(__unm)
APInt_metatable.__lt = typecheck(__lt)
APInt_metatable.__eq = __eq
APInt_metatable.__pow = typecheck(__pow)
APInt_metatable.__lsl = typecheck(__lsl)
APInt_metatable.__lsr = typecheck(__lsr)

local call_proxy = {
    __call = function(_, x)
        return APInt.new(x)
    end
}

setmetatable(APInt, call_proxy)

return APInt