--!nocheck
--!nolint

-- tests done using busted: https://lunarmodules.github.io/busted/
-- this file runs as a standalone, so just install busted and run this file using lua5.2

local APInt = require("./APInt")
require 'busted.runner'()

local BASE = APInt.BASE

-- according to https://www.lua.org/manual/5.2/manual.html#2.4

describe("Operations", function()
    test("Creates a new value", function()
        assert.are.same({1}, APInt(1))
        assert.are.same({-1}, APInt(-1))
        assert.are.same({0, 1}, APInt({0, 1}))
        assert.are.same({1, 2, 3, -4}, APInt({1, 2, 3, -4}))
        assert.are.same({1}, APInt(APInt(1)))

        assert.are.same({12345}, APInt("12345"))
        assert.are.same({-54321}, APInt("-54321"))
        assert.are.same({0}, APInt("0"))
        assert.are.same({0, 1}, APInt(string.format("%.f", BASE)))
        assert.are.same({0, -1}, APInt("-" .. string.format("%.f", BASE)))
        local big_number_str = "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000"
        assert.are.same(big_number_str, tostring(APInt(big_number_str)))
        assert.are.same("-" .. big_number_str, tostring(APInt("-" .. big_number_str)))


        assert.has_error(function() APInt(BASE) end)
        assert.has_error(function() APInt({BASE, BASE}) end)
        assert.has_error(function() APInt({1, -2, 3, 4}) end)
        assert.has_error(function() APInt("not a number") end)
        assert.has_error(function() APInt("123-456") end)
        assert.has_error(function() APInt("") end)
    end)

    test("Addition", function()
        assert.are.same({4}, APInt(2) + APInt(2)) -- quick math
        assert.are.same({4503599627370494, 1}, APInt(BASE - 1) + APInt(BASE - 1))
        assert.are.same({0, 4503599627370494, 1}, APInt({0, BASE - 1}) + APInt({0, BASE - 1}))
        assert.are.same({1}, APInt(5) + APInt(-4))
        assert.are.same({-1}, APInt(5) + APInt(-6))
        assert.are.same({0, 1}, APInt(BASE / 2) + APInt(BASE / 2))
    end)

    test("Subtraction", function()
        assert.are.same({1}, APInt(2) - APInt(1))
        assert.are.same({0, 1}, APInt({0, 0, 1}) - APInt({0, BASE - 1}))
        assert.are.same({3 - (BASE - 1)}, APInt({3}) - APInt({BASE - 1}))
        assert.are.same({9}, APInt(5) - APInt(-4))
        assert.are.same({-1}, APInt(5) + APInt(-6))
    end)

    test("Multiplication (oh god)", function()
        assert.are.same({4}, APInt(2) * APInt(2))
        assert.are.same({-6}, APInt(-2) * APInt(3))
        assert.are.same({0}, APInt(420) * APInt(0))
        assert.are.same({0, 1}, APInt(math.sqrt(BASE)) * APInt(math.sqrt(BASE)))
        assert.are.same({0, -1}, APInt(-math.sqrt(BASE)) * APInt(math.sqrt(BASE)))

        local function factorial(x)
            x = APInt(x)
            local result = APInt(1)
            while true do
                if x <= APInt(1) then
                    return result
                end
                result = result * x
                x = x - APInt(1)
            end
        end

        assert.are.same({120}, factorial(APInt(5)))
        assert.are.same({958209396572160, 540}, factorial(APInt(20)))
    end)

    test("Division (oh god even more)", function()
        assert.are.same({2}, APInt(4) / APInt(2))
        assert.are.same({-3}, APInt(-6) / APInt(2))
        assert.are.same({2}, APInt(7) / APInt(3))
        assert.are.same({2}, APInt(-12) / APInt(-5))
        assert.are.same({0}, APInt(0) / APInt(420))
        assert.are.same(APInt(math.sqrt(BASE)), APInt({0, 1}) / APInt(math.sqrt(BASE)))
        assert.are.same(APInt({664333360460499, 3982308273631934, 3061069592710197}), APInt({2310042140305905, 3779025547483650, 2759084521790143, 1333207883151640, 2871280155256532, 2361179593819894}) / APInt({4380989235077369, 1317378481282125, 3473886240354038}))
        assert.has_error(function() return APInt(10) / APInt(0) end)
    end)

    test("Modulo", function()
        assert.are.same({1}, APInt(10) % APInt(3))
        assert.are.same({2}, APInt(-10) % APInt(3))
        assert.are.same({9}, APInt(-1) % APInt(10))
        assert.are.same({6}, APInt({0, 1}) % APInt(10))
        assert.are.same({40000}, APInt({2107998818533376, 11344}) % APInt(100000))
    end)

    test("Power", function()
        assert.are.same({16}, APInt(2) ^ APInt(4))
        assert.are.same({0, 2}, APInt(2) ^ APInt(53))
        assert.are.same({0}, APInt(10) ^ APInt(-1))
        assert.are.same({1}, APInt(1) ^ APInt(-10))
    end)

    test("Unary minus", function()
        assert.are.same({-16}, -APInt(16))
        assert.are.same({2}, -APInt(-2))
        assert.are.same({0}, -APInt(0))
    end)

    -- no concatenation operator

    -- no length operator (it returns the amount of digit of the number in base BASE)

    test("Equal", function()
        assert.is_true(APInt(1) == APInt(1))
        assert.is_true(APInt(1000) == APInt(1000))
        assert.is_true(APInt(2) + APInt(2) ~= APInt(5))
        assert.is_true(APInt({1, 2, 3}) == APInt({1, 2, 3}))
        assert.is_true(APInt({1, 3, 3}) ~= APInt({1, 2, 3}))
    end)

    test("Less than", function()
        assert.is_true(APInt(1) < APInt(2))
        assert.is_true(APInt({0}) < APInt({0, 1}))
        assert.is_true(APInt({3, 2, 1}) < APInt({1, 2, 3}))
    end)

    test("To string", function()
        assert.are.same("1234", tostring(APInt(1234)))
        assert.are.same(string.format("%.f", APInt.BASE), tostring(APInt({0, 1})))
        assert.are.same("-1234", tostring(-APInt(1234)))
        assert.are.same("0", tostring(-APInt(0)))

        local function fibonacci(x)
            local a = APInt(0)
            local b = APInt(1)
            for i = 1, x do
                local temp = b
                b = b + a
                a = temp
            end
            return a
        end

        assert.are.same("354224848179261915075", tostring(fibonacci(100)))

        local function factorial(x)
            x = APInt(x)
            local result = APInt(1)
            while true do
                if x <= APInt(1) then
                    return result
                end
                result = result * x
                x = x - APInt(1)
            end
        end

        assert.are.same("93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000", tostring(factorial(100)))
    end)
end)

local function get_random_number(digits_amount)
    local x = {}
    for i = 1, digits_amount do
        table.insert(x, math.random(1, BASE - 1))
    end
    return x
end

describe("Performance", function()
    local TEST_AMOUNT = 2000

    test("Addition performance", function()
        for i = 1, TEST_AMOUNT do
            local a = APInt(get_random_number(math.random(5, 10)))
            local b = APInt(get_random_number(math.random(5, 10)))
            local result = a + b
            assert.is_not_nil(result)
        end
    end)

    test("Subtraction performance", function()
        for i = 1, TEST_AMOUNT do
            local a = APInt(get_random_number(math.random(5, 10)))
            local b = APInt(get_random_number(math.random(5, 10)))
            local result = a - b
            assert.is_not_nil(result)
        end
    end)

    test("Multiplication performance", function()
        for i = 1, TEST_AMOUNT do
            local a = APInt(get_random_number(math.random(5, 10)))
            local b = APInt(get_random_number(math.random(1, 5)))
            local result = a * b
            assert.is_not_nil(result)
        end
    end)

    test("Division performance", function()
        for i = 1, TEST_AMOUNT do
            local a = APInt(get_random_number(math.random(5, 10)))
            local b = APInt(get_random_number(math.random(1, 5)))
            local result = a / b
            assert.is_not_nil(result)
        end
    end)
end)