local BigInt = require("./BigInt")

local last_time = os.clock()

local function time_since_last_call(label)
    local current_time = os.clock()
    local elapsed = current_time - last_time
    last_time = current_time
    print(string.format("[TIMER] %s: %.6f seconds", label or "Elapsed time", elapsed))
    return elapsed
end

local format = BigInt.format
local test_print = BigInt.test_print

local function factorial_big_int(x)
    x = BigInt.new(x)
    local result = BigInt.new(1)
    while true do
        if x <= BigInt.new(1) then
            return result
        end
        result = result * x
        x = x - BigInt.new(1)
    end
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

local test_division = test_operation("div", function(a, b) return a / b end, function(a, b) return math.floor(a / b) end)
local test_multiplication = test_operation("mul", function(a, b) return a * b end, function(a, b) return a * b end)

local function random_test(amount, constructor)
    for i = 1, amount do
        test_division(math.random(1, BigInt.BASE - 1), math.random(1, BigInt.BASE - 1))
        --local result = constructor() / constructor(math.random(1, BigInt.BASE - 1))
    end
end

--[[ local x = 1000

time_since_last_call("Start BigInt")
random_test(x, BigInt.new)
time_since_last_call("Finish BigInt") ]]


local a = factorial_big_int(BigInt.new(1000))
local b = factorial_big_int(BigInt.new(999))

time_since_last_call("Start Division")
test_print(a / b)
time_since_last_call("End")

--[[ time_since_last_call("Start BigNum")
random_test(x, BigNum.new)
time_since_last_call("Finish BigNum") ]]

--[[ time_since_last_call("Start BigInt")
random_test(AMOUNT, BigInt.new)
time_since_last_call("Finish BigInt")

time_since_last_call("Start BigNum")
random_test(AMOUNT, BigNum.new)
time_since_last_call("Finish BigNum") ]]



--test_print(factorial(BigInt.new(120)))

--[[ local a = factorial(BigInt.new(50))
local b = BigInt.new(5)

local q = a / b
local r = a % b
print("q", format(q), "r", format(r))

print(a)
 ]]

--[[ time_since_last_call("Tests")
for i = 1, 1000 do
    local x = math.random(1, 30)
    print(string.format("factorial(%d)", x))
    factorial(BigInt.new(x))
end
time_since_last_call("Tests") ]]

-- [4, 4503599627370492]
