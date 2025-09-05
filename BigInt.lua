-- use enums to make everything more clear when refactoring

--[[ local enum = function(keys)
    local Enum = {}
    for _, value in ipairs(keys) do
        Enum[value] = {} 
    end
    return Enum
end ]]

local BigInt = {}
local BigInt_metatable = {}
BigInt.__index = BigInt
local POWER = 52
local BASE = 2^POWER -- MAX 2^53
BigInt.BASE = BASE
BigInt.MODE = "STRICT"
local PRELOADED = {}


assert(POWER % 2 == 0, "POWER must be an even number for multiplication to work properly")

local function slice(array, i, j)
    local result = {}
    for i = i, j do
        table.insert(result, array[i])
    end
    return result
end

local function invert(array)
    local new = {}

    for i = #array, 1, -1 do
        table.insert(new, array[i])
    end

    return new
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

-- make it so the sign is stored in the last digit so its O(1)
local function __sign(x)
    return (x[#x] >= 0 and 1) or -1
end

function BigInt.format(x)
    local is_number = type(x) == "number"
    local is_big_int = type(x) == "table" and BigInt.__is_big_int(x)

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

function BigInt.test_print(x)
    print("{".. BigInt.format(x).. "}")
end

local function typecheck(f)
    return function(...)
        local arguments = {...}
        for i, v in pairs(arguments) do
            if not BigInt.__is_big_int(v) then
                if BigInt.MODE == "STRICT" then
                    error("Argument for operation was not BIGINT")
                else
                    if BigInt.MODE == "WARNING" then
                        print("Argument for operation was not a BIGINT, converted")
                    end
                    arguments[i] = BigInt.new(v)
                end
            end
        end
        return f(unpack(arguments))
    end
end

function BigInt.__is_big_int(x)
    return type(x) == "table" and getmetatable(x) == BigInt_metatable
end

local function __amount_digits(x)
    return #x
end

local function __abs(x)
    local clone = {unpack(x)}
    if x[#x] == 0 then
        return BigInt.new(0)
    end
    clone[#clone] = math.abs(clone[#clone])

    return BigInt.new(clone)
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
        local subtraction = bigger[i] - (smaller[i] or 0) - carry
        carry = 0
        if subtraction < 0 then
            subtraction = BASE + subtraction
            carry = 1
        end
        table.insert(digits, subtraction)
        i = i + 1
    end

    local result = BigInt.new(__remove_trailing_zeros(digits))
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

    if __amount_digits(a) ~= __amount_digits(b) then
        return __amount_digits(a) < __amount_digits(b)
    end

    if __eq(a, b) then
        return false
    end

    for i = __amount_digits(a), 1, -1 do
        if a[i] ~= b[i] then
            if not (a[i] < b[i]) then
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
    for i = #a, 1, -1 do
        local result = math.floor(a[i] / 2)
        if carry == 1 then
            result = result + BASE/2
        end
        carry = 0
        carry = a[i] % 2
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

    return BigInt.new(digits, __sign(a))
end

local function two_digit_division(a, b)
    if __amount_digits(a) == 1 and __amount_digits(b) == 1 then
        return a / b
    end

    assert(__amount_digits(a) == 2 and __amount_digits(b) == 1, "Invalid input for two digit division")


    local second = a[2] / b[1]
    second = math.floor(second)
    local first = math.floor(a[1] / b[1] + (BASE / b[1]) * a[2])

    if a[2] >= b[1] then
        first = two_digit_division({a[1], a[2] - second * b[1]}, b)[1]
    end

    local result_digits = __remove_trailing_zeros({first, second})
    return BigInt.new(result_digits)
end

-- there is a problem with the long division
local function long_division(a, b)
    assert(__amount_digits(b) == 1, "Amount of digits of b is greater than 1")
    local quotient_digits = {} 

    local current_a = nil
    local index = #a - 1
    local remainder = 0

    if a[#a] < b[1] then
        current_a = BigInt.new({a[#a - 1], a[#a]})
        quotient_digits = {two_digit_division(current_a, b)[1]}
        remainder = (current_a - BigInt.new(quotient_digits))[1]
        index = index - 1
    else
        quotient_digits = {math.floor(a[#a] / b[1])}
        remainder = a[#a] - quotient_digits[1] * b[1]
    end

    while index >= 1 do
        current_a = BigInt.new(__remove_trailing_zeros({a[index], remainder}))
        local result = two_digit_division(current_a, b)
        table.insert(quotient_digits, result[1])
        remainder = (current_a - b * result)[1]

        index = index - 1
    end

    local correct_format = invert(quotient_digits)

    local quotient = BigInt.new(correct_format)
    local total_remainder = a - b * quotient

    return quotient, total_remainder
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

    local q, r = long_division(a, b)
    return q, r
end

local function __div(a, b)
    assert(b ~= BigInt.new(0), "Division by 0")
    local sign = __sign(a) * __sign(b)

    if __amount_digits(a) == 1 and __amount_digits(b) == 1 then
        local result = math.floor(a[1] / b[1])
        return BigInt.new(result), BigInt.new(a[1] - math.floor(a[1] / b[1]) * b[1])
    end

    local q, r = goldschmidt_division(a, b)

    return BigInt.new((sign == 1 and q) or -q), r
end

local function __mod(a, b)
    local _, result = __div(a, b)
    return result
end

local function textbook_mul(a, b)
    local SPLIT_BASE = 2^(POWER / 2)
    local BASE = BigInt.BASE
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
        if bigger[1] <= math.sqrt(BASE) then
            if bigger[1] == smaller[1] and bigger[1] == math.sqrt(BASE) then
                return BigInt.new({0, 1})
            end
            return BigInt.new(bigger[1] * smaller[1])
        end
        a = a[1]
        b = b[1]

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
        return BigInt.new(__remove_trailing_zeros(result))
    end

    local half = math.ceil(__amount_digits(bigger) / 2)
    local a_digits = bigger
    local b_digits = smaller

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

    local z0_digits = z0
    local z1_digits = pad(z1, half)
    local z2_digits = pad(z2, half)

    z0 = BigInt.new(z0_digits)
    z1 = BigInt.new(z1_digits)
    z2 = BigInt.new(z2_digits)

    return BigInt.new(__remove_trailing_zeros((z0 + z1 + z2)))
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

-- put the digits in a table and then concat
local function __tostring(x)
    if __amount_digits(x) == 1 then
        return string.format("%.f", x[1])
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
    local clone = {unpack(x)}
    if x[#x] == 0 then
        return BigInt.new(0)
    end

    clone[#clone] = clone[#clone] * -1

    return BigInt.new(clone)
end

-- lazy
local function __pow(a, b)
    if b < BigInt.new(0) then
        assert(a ~= BigInt.new(0), "Negative power of 0")
        return (a == BigInt.new(1) and BigInt.new(1)) or BigInt.new(0)
    end

    local result = BigInt.new(1)
    local i = BigInt.new(1)
    while i <= b do
        i = i + BigInt.new(1)
        result = result * a
    end
    return result
end

function BigInt.new(x)
    if PRELOADED[x] then
        return PRELOADED[x]
    end
    if BigInt.__is_big_int(x) then
        return x
    end

    assert(type(x) == "number" or type(x) == "table", "Argument of new must be an integer or a BigInt table rappresentation")

    local digits

    if type(x) == "number" then
        assert(x % 1 == 0, "The number passed must be a whole number")
        assert((-BASE < x) and (x < BASE), "Argument must be between " .. string.format("%.f", -BASE) .. " and " .. string.format("%.f", BASE))
        digits = {x}
    end
    if type(x) == "table" then
        local last = x[#x]
        assert(-BASE < last and last < BASE, "Last element of the digits table needs to be between " .. string.format("%.f", -BASE) .. " and " .. string.format("%.f", BASE))
        for i = 1, #x - 1 do
            local v = x[i]
            assert(0 <= v)
            assert(0 <= v and v < BASE, "Every element except the last of the digits table needs to be between 0 (inclusive) and " .. string.format("%.f", BASE))
        end
        digits = x
    end

    assert(digits ~= nil)
    return setmetatable(digits, BigInt_metatable) --read_only()
end

-- Preloading some numbers like python does
for i = -5, 256 do
    PRELOADED[i] = BigInt.new(i)
end

BigInt_metatable.__index = BigInt
BigInt_metatable.__add = typecheck(__add)
BigInt_metatable.__sub = typecheck(__sub)
BigInt_metatable.__mod = typecheck(__mod)
BigInt_metatable.__div = typecheck(__div)
BigInt_metatable.__mul = typecheck(__mul)
BigInt_metatable.__tostring = typecheck(__tostring)
BigInt_metatable.__unm = typecheck(__unm)
BigInt_metatable.__lt = typecheck(__lt)
BigInt_metatable.__eq = __eq
BigInt_metatable.__pow = typecheck(__pow)
BigInt_metatable.__lsl = typecheck(__lsl)
BigInt_metatable.__lsr = typecheck(__lsr)

local call_proxy = {
    __call = function(_, x)
        return BigInt.new(x)
    end
}

setmetatable(BigInt, call_proxy)

local function get_random_number(digits_amount)
    local x = {}
    for i = 1, digits_amount do
        table.insert(x, math.random(1, BASE - 1))
    end
    return x
end

local TEST_AMOUNT = 1000

--[[ for i = 1, TEST_AMOUNT do
    local a = get_random_number(math.random(5, 10))
    local b = get_random_number(math.random(1, 5))

    print("A")
    BigInt.test_print(a)
    print("B")
    BigInt.test_print(b)

    
    local result = BigInt(a) / BigInt(b)
end ]]

local a = BigInt({2310042140305905, 3779025547483650, 2759084521790143, 1333207883151640, 2871280155256532, 2361179593819894})
local b = BigInt({4380989235077369, 1317378481282125, 3473886240354038})

BigInt.test_print(a / b)
--BigInt.test_print( / BigInt({4380989235077369, 1317378481282125, 3473886240354038}))

return BigInt

-- 2310042140305905, 3779025547483650, 2759084521790143, 1333207883151640, 2871280155256532, 2361179593819894
-- 4380989235077369, 1317378481282125, 3473886240354038