local BigInt = require("./BigInt")

local last_time = os.clock()

local function time_since_last_call(label)
    local current_time = os.clock()
    local elapsed = current_time - last_time
    last_time = current_time
    print(string.format("[TIMER] %s: %.6f seconds", label or "Elapsed time", elapsed))
    return elapsed
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

local function test_operation(name, custom, default)
    return function(a, b)
        local own = custom(BigInt.new(a), BigInt.new(b))
        local library = default(a, b)
        assert(own.digits[1] == library, string.format("\na: %d, b: %d\n%s(a, b) = {%s}, correct_%s(a, b) = %s", a, b, name, format(own), name, format(library)))
    end
end

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

local function factorial(x)
    if x <= BigInt.new(1) then
        return BigInt.new(1)
    end
    return factorial(x - BigInt.new(1)) * x
end

local test_division = test_operation("div", function(a, b) return a / b end, function(a, b) return math.floor(a / b) end)
local test_multiplication = test_operation("mul", function(a, b) return a * b end, function(a, b) return a * b end)


--[[ time_since_last_call("Start")
test_print(factorial(BigInt.new(400)))
time_since_last_call("Finish") ]]

--test_print(BigInt.new((2 ^ 52) - 2) * BigInt.new((2 ^ 52) - 2))

--[[ local a = factorial(BigInt.new(50))
local b = BigInt.new(5)

local q = a / b
local r = a % b
print("q", format(q), "r", format(r))

print(a)
 ]]

time_since_last_call("Tests")
for i = 1, 1000 do
    local x = math.random(1, 30)
    print(string.format("factorial(%d)", x))
    factorial(BigInt.new(x))
end
time_since_last_call("Tests")

-- [4, 4503599627370492]