--!nocheck
--!nolint

local BigInt = require("./BigInt")
require 'busted.runner'()

local BASE = BigInt.BASE

-- according to https://www.lua.org/manual/5.2/manual.html#2.4

describe("Operations", function()
    test("Creates a new value", function()
        assert.are.same({1}, BigInt(1))

        assert.are.same({-1}, BigInt(-1))

        assert.are.same({0, 1}, BigInt({0, 1}))

        assert.are.same({1, 2, 3, -4}, BigInt({1, 2, 3, -4}))

        assert.are.same({1}, BigInt(BigInt(1)))

        assert.has_error(function() BigInt(BASE) end)

        assert.has_error(function() BigInt({BASE, BASE}) end)

        assert.has_error(function() BigInt({1, -2, 3, 4}) end)
    end)

    test("Addition", function()
        assert.are.same({4}, BigInt(2) + BigInt(2)) -- quick math

        assert.are.same({4503599627370494, 1}, BigInt(BASE - 1) + BigInt(BASE - 1))

        assert.are.same({0, 4503599627370494, 1}, BigInt({0, BASE - 1}) + BigInt({0, BASE - 1}))

        assert.are.same({1}, BigInt(5) + BigInt(-4))

        assert.are.same({-1}, BigInt(5) + BigInt(-6))

        assert.are.same({0, 1}, BigInt(BASE / 2) + BigInt(BASE / 2))
    end)

    test("Subtraction", function()
        assert.are.same({1}, BigInt(2) - BigInt(1))

        assert.are.same({0, 1}, BigInt({0, 0, 1}) - BigInt({0, BASE - 1}))

        assert.are.same({3 - (BASE - 1)}, BigInt({3}) - BigInt({BASE - 1}))

        assert.are.same({9}, BigInt(5) - BigInt(-4))

        assert.are.same({-1}, BigInt(5) + BigInt(-6))
    end)

    test("Multiplication (oh god)", function()
        assert.are.same({4}, BigInt(2) * BigInt(2))

        assert.are.same({-6}, BigInt(-2) * BigInt(3))

        assert.are.same({0}, BigInt(420) * BigInt(0))

        assert.are.same({0, 1}, BigInt(math.sqrt(BASE)) * BigInt(math.sqrt(BASE)))

        assert.are.same({0, -1}, BigInt(-math.sqrt(BASE)) * BigInt(math.sqrt(BASE)))


        local function factorial(x)
            x = BigInt(x)
            local result = BigInt(1)
            while true do
                if x <= BigInt(1) then
                    return result
                end
                result = result * x
                x = x - BigInt(1)
            end
        end

        assert.are.same({120}, factorial(BigInt(5)))

        assert.are.same({958209396572160, 540}, factorial(BigInt(20)))
    end)

    test("Division (oh god even more)", function()
        assert.are.same({2}, BigInt(4) / BigInt(2))

        assert.are.same({-3}, BigInt(-6) / BigInt(2))

        assert.are.same({2}, BigInt(7) / BigInt(3))

        assert.are.same({2}, BigInt(-12) / BigInt(-5))

        assert.are.same({0}, BigInt(0) / BigInt(420))

        assert.are.same(BigInt(math.sqrt(BASE)), BigInt({0, 1}) / BigInt(math.sqrt(BASE)))

        assert.are.same(BigInt({664333360460499, 3982308273631934, 3061069592710197}), BigInt({2310042140305905, 3779025547483650, 2759084521790143, 1333207883151640, 2871280155256532, 2361179593819894}) / BigInt({4380989235077369, 1317378481282125, 3473886240354038}))

        assert.has_error(function() return BigInt(10) / BigInt(0) end)
    end)

    test("Modulo", function()
        assert.are.same({1}, BigInt(10) % BigInt(3))

        assert.are.same({2}, BigInt(-10) % BigInt(3))

        assert.are.same({9}, BigInt(-1) % BigInt(10))

        assert.are.same({6}, BigInt({0, 1}) % BigInt(10))

        assert.are.same({40000}, BigInt({2107998818533376, 11344}) % BigInt(100000))
    end)

    test("Power", function()
        assert.are.same({16}, BigInt(2) ^ BigInt(4))

        assert.are.same({0, 2}, BigInt(2) ^ BigInt(53))

        assert.are.same({0}, BigInt(10) ^ BigInt(-1))

        assert.are.same({1}, BigInt(1) ^ BigInt(-10))
    end)

    test("Unary minus", function()
        assert.are.same({-16}, -BigInt(16))
        
        assert.are.same({2}, -BigInt(-2))

        assert.are.same({0}, -BigInt(0))
    end)

    -- no concatenation operator

    -- no length operator (it returns the amount of digit of the number in base BASE)

    test("Equal", function()
        assert.is_true(BigInt(1) == BigInt(1))

        assert.is_true(BigInt(1000) == BigInt(1000))

        assert.is_true(BigInt(2) + BigInt(2) ~= BigInt(5))

        assert.is_true(BigInt({1, 2, 3}) == BigInt({1, 2, 3}))

        assert.is_true(BigInt({1, 3, 3}) ~= BigInt({1, 2, 3}))
    end)

    test("Less than", function()
        assert.is_true(BigInt(1) < BigInt(2))

        assert.is_true(BigInt({0}) < BigInt({0, 1}))

        assert.is_true(BigInt({3, 2, 1}) < BigInt({1, 2, 3}))
    end)

    test("To string", function()
        assert.are.same("1234", tostring(BigInt(1234)))

        assert.are.same(string.format("%.f", BigInt.BASE), tostring(BigInt({0, 1})))

        assert.are.same("-1234", tostring(-BigInt(1234)))

        assert.are.same("0", tostring(-BigInt(0)))

        local function fibonacci(x)
            local a = BigInt(0)
            local b = BigInt(1)
            for i = 1, x do
                local temp = b
                b = b + a
                a = temp
            end
            return a
        end

        assert.are.same("354224848179261915075", tostring(fibonacci(100)))
    end)

    -- "less or equal" gets inferred from "not greater"

    -- no index

    -- no new_index

    -- no call
end)

local function get_random_number(digits_amount)
    local x = {}
    for i = 1, digits_amount do
        table.insert(x, math.random(1, BASE - 1))
    end
    return x
end

local TEST_AMOUNT = 1000

for i = 1, TEST_AMOUNT do
    local a = get_random_number(math.random(5, 10))
    local b = get_random_number(math.random(1, 5))

    local result = BigInt(a) / BigInt(b)
end