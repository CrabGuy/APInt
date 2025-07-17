local MODE = "STRICT"

-- use enums to make everything more clear when refactoring

--[[ local enum = function(keys)
    local Enum = {}
    for _, value in ipairs(keys) do
        Enum[value] = {} 
    end
    return Enum
end ]]

local BigInt = {}
BigInt.__index = BigInt
local POWER = 52
local BASE = 2^POWER -- MAX 2^53
BigInt.BASE = BASE
local PRELOADED = {}


assert(POWER % 2 == 0, "POWER must be an even number for multiplication to work properly")

local function slice(array, i, j)
    return {unpack(array, i, j)}
end

local function fill(array, desired_length)
    local new_table = {}
    for i = 1, math.max(desired_length, #array) do
        new_table[i] = ((array[i] == nil) and 0) or array[i]
    end
    return new_table
end

local function join(first, second)
    local result = {}

    for i, v in pairs(first) do
        table.insert(result, v)
    end
    
    for i, v in pairs(second) do
        table.insert(result, v)
    end

    return result
end

local function safe_add(a, b)
    if BASE - a <= b then
        return (- BASE + a) + b, 1
    end
    return a + b, 0
end

local function format(x)
    if not BigInt.__is_big_int(x) then
        return string.format("%.f", x)
    end

    local digits = {}
    for i, v in pairs(x.digits) do
        table.insert(digits, string.format("%.f", v))
    end

    local text = table.concat(digits, ", ")
    return x.sign == 1 and text or ("-" .. text)
end

local function test_print(x)
    print("{".. format(x).. "}")
end

local function typecheck(f)
    return function(...)
        local arguments = {...}
        for i, v in pairs(arguments) do
            if not BigInt.__is_big_int(v) then
                if MODE == "STRICT" then
                    error("Argument for operation was not BIGNUM")
                else
                    print("Argument for operation was not a BIGNUM, converted")
                    arguments[i] = BigInt.new(v)
                end
            end
        end
        return f(unpack(arguments))
    end
end

function BigInt.__is_big_int(x)
    return type(x) == "table" and getmetatable(x) == BigInt
end

function BigInt.new(x)
    if PRELOADED[x] then
        return PRELOADED[x]
    end

    if BigInt.__is_big_int(x) then
        return x
    end

    assert(type(x) == "number" or type(x) == "table", "Argument of new must be an integer or a BigInt table rappresentation")
    
    if type(x) == "number" then
        assert(x % 1 == 0, "Argument of x must be a whole number")
        assert((-BASE < x) and (x < BASE), "Argument must be between " .. string.format("%.f", -BASE) .. " and " .. string.format("%.f", BASE))
    end

    local digits = x --table
    if type(x) == "number" then
        digits = {x}
    end
    for i, v in pairs(digits) do
        assert(-BASE < v and v < BASE, "Every elements of the digits table needs to be between " .. string.format("%.f", -BASE) .. " and " .. string.format("%.f", BASE))
    end

    local self = {}
    self.digits = digits
    self.sign = ((self.digits[1] < 0) and -1) or 1
    self.digits[1] = math.abs(self.digits[1])
    
    return setmetatable(self, BigInt)
end

-- Preloading some numbers like python does
for i = -5, 256 do
    PRELOADED[i] = BigInt.new(i)
end




local function __sign(x)
    return x.sign
end

local function __amount_digits(x)
    return #x.digits
end

local function __abs(x)
    return BigInt.new(x.digits)
end

local function __add(a, b)
    if __sign(a) ~= __sign(b) then
        return ((__sign(a) == 1) and __abs(a) - __abs(b)) or __abs(b) - __abs(a)
    end

    local digits = {}
    local carry = 0

    local i = 1
    while (i <= __amount_digits(a)) or (i <= __amount_digits(b)) do
        local a0 = a.digits[i] or 0
        local b0 = b.digits[i] or 0
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

    digits[1] = digits[1] * __sign(a)

    return BigInt.new(digits)
end

local function __max(a, b)
    return ((a > b) and a) or b
end

local function __min(a, b)
    return ((a < b) and a) or b
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
        local subtraction = bigger.digits[i] - (smaller.digits[i] or 0) - carry
        carry = 0
        if subtraction < 0 then
            subtraction = BASE + subtraction
            carry = 1
        end
        table.insert(digits, subtraction)
        i = i + 1
    end

    local result = BigInt.new(__remove_trailing_zeros(digits))
    return ((bigger == __abs(a)) and result) or -result
end

local function __eq(a, b)
    if type(a) ~= type(b) then
        return false
    end

    if (__sign(a) ~= __sign(b)) or (__amount_digits(a) ~= __amount_digits(b)) then
        return false
    end

    for i = 1, __amount_digits(a) do
        if a.digits[i] ~= b.digits[i] then
            return false
        end
    end

    return true
end

local function __lt(a, b)
    if __sign(a) ~= __sign(b) then
        return __sign(a) == -1
    end

    if __amount_digits(a) ~= __amount_digits(b) then
        return __amount_digits(a) < __amount_digits(b)
    end

    if __eq(a, b) then
        return false
    end

    for i = __amount_digits(a), 1, -1 do
        if a.digits[i] ~= b.digits[i] then
            if not (a.digits[i] < b.digits[i]) then
                return false
            else
                break
            end
        end
    end

    return true
end

local function __shr(a, b)
    b = ((b == nil) and BigInt.new(1)) or b

    if b ~= BigInt.new(1) then
        local result = a
        local i = BigInt.new(1)
        while i <= b do
            result = __shr(result, BigInt.new(1))
            i = i + BigInt.new(1)
        end
        return result * BigInt.new(__sign(a)) * BigInt.new(__sign(b))
    end

    local digits = {}
    local carry = 0
    for i = #a.digits, 1, -1 do
        local result = math.floor(a.digits[i] / 2)
        if carry == 1 then
            result = result + BASE/2
        end
        carry = 0
        carry = a.digits[i] % 2
        digits[i] = result
    end

    digits[1] = digits[1] * __sign(a)
    return BigInt.new(__remove_trailing_zeros(digits)) * BigInt.new(__sign(a)) * BigInt.new(__sign(b))
end

local function __shl(a, b)
    assert(b % 1 == 0, "b must be a whole number")
    b = ((b == nil) and BigInt.new(1)) or b

    if b ~= BigInt.new(1) then
        local result = a
        local i = BigInt.new(1)
        while i <= b do
            result = __shl(result, BigInt.new(1))
            i = i + BigInt.new(1)
        end
        return result
    end

    local digits = {}
    local carry = 0
    for i = 1, #a.digits do
        local old_carry = carry
        digits[i] = a.digits[i]
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

    digits[1] = digits[1] * __sign(a)
    return BigInt.new(digits)
end

local function bisection_division(a, b)
    local left = BigInt.new(0)
    local right = __abs(a)

    while __abs(right - left) > BigInt.new(1) do
        local middle = __shr(right - left, BigInt.new(1)) + left
        local result = (middle * __abs(b)) - __abs(a)

        if result <= BigInt.new(0) then
            left = middle
        end
        
        if result >= BigInt.new(0) then
            right = middle
        end
        
        if result == BigInt.new(0) then
            break
        end
    end

    if right * __abs(b) == __abs(a) then
        return right, 0
    end

    return left, __abs(a) - left * __abs(b)
end

local function long_division(a, b)
    local Q = BigInt.new(0)
    local R = a

    while R >= b do
        local quotient_digit = bisection_division(R, b)
        R = R - quotient_digit * b
        Q = Q + quotient_digit
    end

    return Q, R
end


local function __div(a, b)
    assert(b ~= BigInt.new(0), "Division by 0")
    local same_sign = __sign(a) == __sign(b)
    local q, r = long_division(a, b)

    return ((same_sign and q) or -q), r
end

local function __mod(a, b)
    local _, result = __div(a, b)
    return result
end

local function karatsuba_mul(a, b)
    local bigger = __max(a, b)
    local smaller = __min(a, b)

    if __amount_digits(bigger) <= 1 then
        if bigger.digits[1] <= math.sqrt(BASE) then
            if bigger.digits[1] == smaller.digits[1] and bigger.digits[1] == math.sqrt(BASE) then
                return BigInt.new({0, 1})
            end
            return BigInt.new(bigger.digits[1] * smaller.digits[1])
        end
        a = a.digits[1]
        b = b.digits[1]

        local m = POWER / 2
        local B = 2

        local Bm = B^m

        local a0 = a % Bm
        local a1 = math.floor(a / Bm)

        local b0 = b % Bm
        local b1 = math.floor(b / Bm)

        local z0 = a0 * b0
        local z2 = a1 * b1
        local z3 = BigInt.new(a0 + a1) * BigInt.new(b0 + b1)
        local z1 = z3 - BigInt.new(z2) - BigInt.new(z0)
        local result = (BigInt.new(z0) + (z1 * BigInt.new(Bm))) + BigInt.new({0, z2})
        return BigInt.new(__remove_trailing_zeros(result.digits))
    end
    local half = math.ceil(__amount_digits(bigger) / 2)
    local a_digits = bigger.digits
    local b_digits = smaller.digits

    local a0 = BigInt.new(slice(a_digits, 1, half))
    local a1 = BigInt.new(slice(a_digits, half + 1, #a_digits))
    local b0 = BigInt.new(slice(b_digits, 1, math.min(half, #b_digits)))
    local b1 = BigInt.new(fill(slice(b_digits, math.min(half, #b_digits) + 1, #b_digits), 1)) -- if b1 is empty => {0}

    local z0 = a0 * b0
    local z2 = a1 * b1
    local z3 = (a0 + a1) * (b0 + b1)
    local z1 = z3 - z0 - z2
    
    local z0_digits = z0.digits
    local z1_digits = join(fill({}, half), z1.digits)
    local z2_digits = join(fill({}, half * 2), z2.digits)

    z0 = BigInt.new(z0_digits)
    z1 = BigInt.new(z1_digits)
    z2 = BigInt.new(z2_digits)

    return BigInt.new(__remove_trailing_zeros((z0 + z1 + z2).digits))
end

-- cretino impara come si fanno le moltiplicazioni da scuola elementare che l'algoritmo sta sulla luna
local function textbook_mul(a, b)
    local SPLIT_BASE = math.sqrt(BASE)
    local a_digits = a.digits
    local b_digits = b.digits

    local result_digits = {}
    local max_pos = #a_digits + #b_digits - 1
    for i = 1, max_pos + 1 do
        result_digits[i] = 0
    end


    for i = 1, #a_digits do
        local carry = 0
        for j = 1, #b_digits do
            local pos = i + j - 1
            local a0 = a_digits[i] % SPLIT_BASE
            local a1 = math.floor(a_digits[i] / SPLIT_BASE)

            local b0 = b_digits[i] % SPLIT_BASE
            local b1 = math.floor(b_digits[i] / SPLIT_BASE)

            local c0 = a0 * b0
            local c2_carry = 0
            local c1, remainder = safe_add(a0 * b1, a1 * b0)
            if remainder then
                c2_carry = 1
            end

            if c1 >= SPLIT_BASE then
                c2_carry = c2_carry + math.floor(c1 / SPLIT_BASE)
                c1 = c1 % SPLIT_BASE
            end

            local c2 = a1 * b1 + c2_carry
            carry = c2

            local current = c0 + c1 * SPLIT_BASE
            result_digits[pos] = current
        end

        -- this is 99% not correct
        local pos = i + #b_digits
        while carry > 0 do
            local sum = result_digits[pos] + carry
            if BASE - carry <= result_digits[pos] then
                sum = - BASE + result_digits[pos] + carry
            end
            result_digits[pos] = sum
            carry = math.floor(sum / BASE)
            pos = pos + 1
        end
    end
    
    __remove_trailing_zeros(result_digits)

    if #result_digits == 0 then
        result_digits = {0}
    end

    return BigInt.new(result_digits)
end

local KARATSUBA_DIGITS_THRESHOLD = 1

local function __mul(a, b)
    if __sign(a) ~= __sign(b) then
        return -(__mul(__abs(a), __abs(b)))
    end

    if a == BigInt.new(0) or b == BigInt.new(0) then
        return BigInt.new(0)
    end

    if (__amount_digits(a) > KARATSUBA_DIGITS_THRESHOLD) or (__amount_digits(b) > KARATSUBA_DIGITS_THRESHOLD) then
        return karatsuba_mul(a, b)
    end

    return textbook_mul(a, b) -- da cambiare in textbook_mul
end

local function __tostring(x)
    if __amount_digits(x) == 1 then
        return string.format("%.f", __sign(x) * x.digits[1])
    end
    local sign = __sign(x)

    local text = ""
    local remainder = BigInt.new(0)
    while x ~= BigInt.new(0) do
        x, remainder = __div(x, BigInt.new(10^math.floor(math.log10(BASE))))
        text = tostring(remainder) .. text
    end

    if sign == -1 then
        text = "-" .. text
    end

    return text
end

local function __unm(x)
    local digits = {unpack(x.digits)}
    digits[1] = -digits[1] * __sign(x)
    return BigInt.new(digits)
end

local function __le(a, b)
    return __lt(a, b) or __eq(a, b)
end

BigInt.__add = typecheck(__add)
BigInt.__sub = typecheck(__sub)
BigInt.__mod = typecheck(__mod)
BigInt.__div = typecheck(__div)
BigInt.__mul = typecheck(__mul)
BigInt.__tostring = typecheck(__tostring)
BigInt.__unm = typecheck(__unm)
BigInt.__lt = typecheck(__lt)
BigInt.__eq = typecheck(__eq)
BigInt.__le = typecheck(__le)


return BigInt