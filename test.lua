--!nocheck
--!nolint

local BigInt = require("./BigInt")
require 'busted.runner'()

local format = BigInt.format
local test_print = BigInt.test_print
local BASE = BigInt.BASE

local function factorial(x)
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

-- according to https://www.lua.org/manual/5.2/manual.html#2.4

describe("Operations", function()
    test("Creates a new value", function()
        assert.are.same({1}, BigInt.new(1))

        assert.are.same({-1}, BigInt.new(-1))

        assert.are.same({0, 1}, BigInt.new({0, 1}))

        assert.are.same({-1, 2, 3, 4}, BigInt.new({-1, 2, 3, 4}))

        assert.are.same({1}, BigInt.new(BigInt.new(1)))

        assert.has_error(function() BigInt.new(BASE) end)

        assert.has_error(function() BigInt.new({BASE, BASE}) end)

        assert.has_error(function() BigInt.new({1, -2, 3, 4}) end)
    end)

    test("Addition", function()
        assert.are.same({4}, BigInt.new(2) + BigInt.new(2)) -- quick math

        assert.are.same({4503599627370494, 1}, BigInt.new(BASE - 1) + BigInt.new(BASE - 1))

        assert.are.same({0, 4503599627370494, 1}, BigInt.new({0, BASE - 1}) + BigInt.new({0, BASE - 1}))

        assert.are.same({1}, BigInt.new(5) + BigInt.new(-4))

        assert.are.same({-1}, BigInt.new(5) + BigInt.new(-6))

        assert.are.same({0, 1}, BigInt.new(BASE / 2) + BigInt.new(BASE / 2))
    end)

    test("Subtraction", function()
        assert.are.same({1}, BigInt.new(2) - BigInt.new(1))

        assert.are.same({0, 1}, BigInt.new({0, 0, 1}) - BigInt.new({0, BASE - 1}))

        assert.are.same({3 - (BASE - 1)}, BigInt.new({3}) - BigInt.new({BASE - 1}))

        assert.are.same({9}, BigInt.new(5) - BigInt.new(-4))

        assert.are.same({-1}, BigInt.new(5) + BigInt.new(-6))
    end)

    test("Multiplication (oh god)", function()
        assert.are.same({4}, BigInt.new(2) * BigInt.new(2))

        assert.are.same({-6}, BigInt.new(-2) * BigInt.new(3))

        assert.are.same({0}, BigInt.new(420) * BigInt.new(0))

        assert.are.same({0, 1}, BigInt.new(math.sqrt(BASE)) * BigInt.new(math.sqrt(BASE)))

        assert.are.same({0, -1}, BigInt.new(-math.sqrt(BASE)) * BigInt.new(math.sqrt(BASE)))

        assert.are.same({120}, factorial(BigInt.new(5)))

        assert.are.same({958209396572160, 540}, factorial(BigInt.new(20)))
    end)

    test("Division (oh god even more)", function()
        assert.are.same({2}, BigInt.new(4) / BigInt.new(2))

        assert.are.same({-3}, BigInt.new(-6) / BigInt.new(2))

        assert.are.same({2}, BigInt.new(7) / BigInt.new(3))

        assert.are.same({2}, BigInt.new(-12) / BigInt.new(-5))

        assert.are.same({0}, BigInt.new(0) / BigInt.new(420))
        
        assert.are.same(BigInt.new(math.sqrt(BASE)), BigInt.new({0, 1}) / BigInt.new(math.sqrt(BASE)))
        
        assert.has_error(function() return BigInt.new(10) / BigInt.new(0) end)
    end)

    pending("Mod")
    pending("Pow")
    pending("Unm")
    -- no concat
    -- no len
    pending("Eq")
    pending("Lt")
    pending("Le")
    -- no index
    -- no new_index (should make it readonly tho)
    -- no call (should make the .new a call)
    pending("Lsl")
    pending("Lsr")
    pending("Tostring")
end)
