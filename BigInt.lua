-- lua 5.2 because of the bit32 library

local BigInt = {}
BigInt.__index = BigInt
local BASE = 2^51 -- MAX 2^53
local PRELOADED = {}

-- per la divisione e forse il modulo puoi usare qualche metodo iterativo, basta che la condizione è che l'errore sia massimo uno

local function is_big_int(x)
    return type(x) == "table" and getmetatable(x) == BigInt
end

local function typecheck(f)
    -- make it so if the arguments are numbers it converts them to BigInt, so the type and operations propagate
    return function(...)
        local arguments = {...}
        for i, v in pairs(arguments) do
            assert(is_big_int(v), string.format("Operand number %d is not a BigInt", i))
        end
    end
end

function BigInt.new(x)
    if PRELOADED[x] then
        return PRELOADED[x]
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

    local self = {}
    self.digits = digits
    self.sign = (self.digits[1] == 0) and 1 or self.digits[1] / math.abs(self.digits[1])
    self.digits[1] = math.abs(self.digits[1])

    return setmetatable(self, BigInt)
end

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

local function __sub(a, b)
    if __sign(a) ~= __sign(b) then
        return __add(a, -b)
    end
    if __sign(a) == -1 then
        return __sub(b, a)
    end

    local bigger = __max(__abs(a), __abs(b))
    local smaller = __min(__abs(a), __abs(b))

    local digits = {}
    local carry = 0


    local i = 1
    while i <= __amount_digits(bigger) do
        local subtraction = bigger.digits[i] - smaller.digits[i] - carry
        carry = 0
        if subtraction < 0 then
            subtraction = BASE + subtraction
            carry = 1
        end
        table.insert(digits, subtraction)
        i = i + 1
    end

    local result = BigInt.new(digits)
    return ((bigger == a) and result) or -result
end

local function __lt(a, b)
    if __sign(a) ~= __sign(b) then
        return __sign(a) == -1
    end

    if __amount_digits(a) ~= __amount_digits(b) then
        return __amount_digits(a) < __amount_digits(b)
    end

    for i = 1, __amount_digits(a) do
        if a.digits[i] >= b.digits[i] then
            return false
        end
    end

    return true
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

local function __div(a, b)
    local result = BigInt.new(0)
    local increment = b
    while increment < a do
        result = result + BigInt.new(1)
        increment = increment + b
    end

    return result, (a - increment - b)
end

local function __mod(a, b)
    local _, result = __div(a, b)
    return result
end

local function __mul(a, b)
    local result = __abs(a)
    local i = BigInt.new(1)
    while i < b do
        result = result + a
        i = i + BigInt.new(1)
    end

    return __sign(a) == __sign(b) and result or -result
end

local function __tostring(x)
    if __amount_digits(x) == 1 then
        return string.format("%.f", x.digits[1])
    end
    --print("Working!")
    local text = tostring(__sign(x))
    local remainder = 0
    while x ~= 0 do
        x, remainder = __div(x, BigInt.new(10))
        text = text .. string.format("%.f", remainder)
    end

    return text
end
local function __unm(x)
    local digits = table.clone(x.digits)
    digits[1] = -digits[1] * __sign(x)
    return BigInt.new(x.digits)
end




BigInt.__add = __add
BigInt.__sub = __sub
BigInt.__mod = __mod
BigInt.__div = __div
BigInt.__mul = __mul
BigInt.__tostring = __tostring
BigInt.__unm = __unm
BigInt.__lt = __lt

print(BigInt.new(BASE - 1) + BigInt.new(2))