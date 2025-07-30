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
    local result = {}
    for i = i, j do
        table.insert(result, array[i])
    end
    return result
end

local function pad(array, amount)
    local result = {}
    for i = 1, amount do
        table.insert(result, 0)
    end

    for i, v in pairs(array) do
        table.insert(result, v)
    end

    return result
end

function BigInt.format(x)
    local is_number = type(x) == "number"
    local is_big_int = type(x) == "table" and BigInt.__is_big_int(x)

    if is_number then
        return string.format("%.f", x)
    end

    assert(is_big_int, "Format argument is not a number")

    local digits = {}
    for i, v in pairs(x.digits) do
        table.insert(digits, string.format("%.f", v))
    end

    local text = table.concat(digits, ", ")
    return x.sign == 1 and text or ("-" .. text)
end

function BigInt.test_print(x)
    print("{".. BigInt.format(x).. "}")
end

local function typecheck(f)
    return function(...)
        local arguments = {...}
        for i, v in pairs(arguments) do
            if not BigInt.__is_big_int(v) then
                if MODE == "STRICT" then
                    error("Argument for operation was not BIGINT")
                else
                    print("Argument for operation was not a BIGINT, converted")
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

function BigInt.new(x, sign)
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
    self.sign = sign or 1
    
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

    return BigInt.new(digits, __sign(a))
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
    return ((__abs(a) > __abs(b)) and result) or -(result)
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

local function __lsl(a, b)
    if b ~= BigInt.new(1) then
        local result = a
        local i = BigInt.new(1)
        while i <= b do
            result = __lsl(result, BigInt.new(1))
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

    return BigInt.new(__remove_trailing_zeros(digits)) * BigInt.new(__sign(a)) * BigInt.new(__sign(b))
end

local function __lsr(a, b)
    b = ((b == nil) and BigInt.new(1)) or b

    if b ~= BigInt.new(1) then
        local result = a
        local i = BigInt.new(1)
        while i <= b do
            result = __lsr(result, BigInt.new(1))
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

    return BigInt.new(digits, __sign(a))
end

local function bisection_division(a, b)
    local left = BigInt.new(0)
    local right = __abs(a)

    while __abs(right - left) > BigInt.new(1) do
        local middle = __lsl(right - left, BigInt.new(1)) + left
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

local function goldschmidt_division(a, b)
    while __amount_digits(b) > 1 do
        b = __lsl(b, BigInt.new(1))
        a = __lsl(a, BigInt.new(1))
    end
    return bisection_division(a, b)
end

local function __div(a, b)
    assert(b ~= BigInt.new(0), "Division by 0")
    local sign = __sign(a) * __sign(b)

    if __amount_digits(a) == 1 and __amount_digits(b) == 1 then
        local result = math.floor(a.digits[1] / b.digits[1])
        return BigInt.new(result, sign)
    end

    local q, r = goldschmidt_division(a, b)

    return BigInt.new(q.digits, sign), r
end

local function __mod(a, b)
    local _, result = __div(a, b)
    return result
end

local function textbook_mul(a, b)
    local SPLIT_BASE = 2^26
    local BASE = BigInt.BASE
    local a_digits = a.digits
    local b_digits = b.digits
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
        return BigInt.new(0)
    end

    return BigInt.new(result)
end

local KARATSUBA_DIGITS_THRESHOLD = math.huge

local function karatsuba_mul(a, b)
    local bigger = __max(a, b)
    local smaller = __min(a, b)

    if __amount_digits(bigger) <= KARATSUBA_DIGITS_THRESHOLD then
        return textbook_mul(a, b)
    end

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

    local b1_digits = slice(b_digits, math.min(half, #b_digits) + 1, #b_digits)
    if #b1_digits == 0 then
        b1_digits = {0}
    end
    local b1 = BigInt.new(b1_digits)

    local z0 = a0 * b0
    local z2 = a1 * b1
    local z3 = (a0 + a1) * (b0 + b1)
    local z1 = z3 - z0 - z2

    local z0_digits = z0.digits
    local z1_digits = pad(z1.digits, half)
    local z2_digits = pad(z2.digits, half)

    z0 = BigInt.new(z0_digits)
    z1 = BigInt.new(z1_digits)
    z2 = BigInt.new(z2_digits)

    return BigInt.new(__remove_trailing_zeros((z0 + z1 + z2).digits))
end

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

    return textbook_mul(a, b)
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
    return BigInt.new({unpack(x.digits)}, -1 * __sign(x))
end

local function __le(a, b)
    return __lt(a, b) or __eq(a, b)
end

local function __pow(a, b)
    local result = BigInt.new(1)
    local i = BigInt.new(1)
    while i <= b do
        i = i + BigInt.new(1)
        result = result * b
    end
    return result
end

BigInt.__add = typecheck(__add)
BigInt.__sub = typecheck(__sub)
BigInt.__mod = typecheck(__mod)
BigInt.__div = typecheck(__div)
BigInt.__mul = typecheck(__mul)
BigInt.__tostring = typecheck(__tostring)
BigInt.__unm = typecheck(__unm)
BigInt.__lt = typecheck(__lt)
BigInt.__eq = __eq
BigInt.__le = typecheck(__le)
BigInt.__pow = typecheck(__pow)
BigInt.__lsl = typecheck(__lsl)
BigInt.__lsr = typecheck(__lsr)


return BigInt