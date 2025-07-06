local BigInt = {}
BigInt.__index = BigInt
local BASE = 2^51 -- MAX 2^53
local PRELOADED = {}

local function is_big_int(x)
    return type(x) == "table" and getmetatable(x) == BigInt
end

local function typecheck(f)
    return function(...)
        local arguments = {...}
        for i, v in pairs(arguments) do
            if not is_big_int(v) then
                print("Argument for operation was not a BIGNUM, converted")
                arguments[i] = BigInt.new(v)
            end
        end
        return f(unpack(arguments))
    end
end

function BigInt.new(x)
    if PRELOADED[x] then
        return PRELOADED[x]
    end

    if is_big_int(x) then
        return x
    end

    assert(type(x) == "number" or type(x) == "table", "Argument of new must be an integer or a BigInt table rappresentation")
    
    if type(x) == "number" then
        assert(x % 1 == 0, "Argument of x must be a whole number")
        assert(-BASE < x and x < BASE, "Argument must be between " .. tostring(-BASE) .. " and " .. tostring(BASE))
    end

    local digits = x --table
    if type(x) == "number" then
        digits = {x}
    end
    for i, v in pairs(digits) do
        assert(-BASE < v and v < BASE, "Every elements of the digits table needs to be between " .. tostring(-BASE) .. " and " .. tostring(BASE))
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

local function format(x)
    if not is_big_int(x) then
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
    print(format(x))
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
        local sum = (a.digits[i] or 0) + (b.digits[i] or 0) + carry
        carry = 0
        table.insert(digits, sum % BASE)
        if sum > BASE then
            carry = 1
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
    for j = #digits, 1, -1 do
        if digits[j] == 0 then
            table.remove(digits, j)
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
    b = ((b == nil) and 1) or b

    if b ~= 1 then
        local result = a
        local i = BigInt.new(1)
        while i <= b do
            result = __shr(result, 1)
            i = i + 1
        end
        return result
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
    return BigInt.new(__remove_trailing_zeros(digits))
end

local function __div(a, b)
    assert(b ~= BigInt.new(0), "Division by 0")
    local same_sign = __sign(a) == __sign(b)
    local left = BigInt.new(0)
    local right = __abs(a)

    while __abs(right - left) > BigInt.new(1) do
        local middle = __shr(right - left, 1) + left
        local result = middle * __abs(b) - __abs(a)
        --print(string.format("left: {%s}, right: {%s}, middle: {%s}, result: {%s}", format(left), format(right), format(middle), format(result)))

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
        return (same_sign and right or -right), 0
    end

    return (same_sign and left or -left), __abs(a) - left * __abs(b)
end

local function __mod(a, b)
    local _, result = __div(a, b)
    return result
end

local function __mul(a, b)
    local result = __abs(a)
    local i = BigInt.new(1)
    while i < b do
        result = result + __abs(a)
        --test_print(result)
        i = i + BigInt.new(1)
    end

    return __sign(a) == __sign(b) and result or -result
end

local function __tostring(x)
    if __amount_digits(x) == 1 then
        return string.format("%.f", __sign(x) * x.digits[1])
    end
    local sign = __sign(x)

    local text = ""
    local remainder = 0
    while x ~= BigInt.new(0) do
        x, remainder = __div(x, BigInt.new(10))
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

local function test_operation(name, custom, default)
    return function(a, b)
        local own = custom(BigInt.new(a), BigInt.new(b))
        local library = default(a, b)
        assert(custom == library, string.format("\na: %d, b: %d\n%s(a, b) = {%s}, correct_%s(a, b) = %s", a, b, name, format(own), name, format(library)))
    end
end

local function test_division(a, b)
    local custom = __div(BigInt.new(a), BigInt.new(b))
    local library = BigInt.new(math.floor(a / b))
    assert(custom == library, string.format("\na: %d, b: %d\ndiv(a, b) = %s, a/b = %s", a, b, tostring(custom), tostring(library)))
end


--[[ for MAX = 1, BASE - 2 do
    local a = math.floor(math.random() * MAX) + 1
    local b = math.floor(math.random() * MAX) + 1
    print(a, b)
    test_division(a, b)
end ]]

--print(BigInt.new(BASE - 2) * BigInt.new(100))

local function fibonacci(x)
    local a = BigInt.new(0)
    local b = BigInt.new(1)
    for i = 1, x do
        local temp = b
        b = b + a
        a = temp
    end
    return a
end

-- print(fibonacci(200))
-- 280571172992510140037611932413038677189525