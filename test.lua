--!nocheck
--!nolint

local luaunit = require('luaunit')
local APInt = require("./APInt")

local BASE = APInt.BASE

assert(BASE == 2^52, "Tests are written to have 2^52 as base")
--assert(false, "TRANSFORMING TOSTRING_DIVISOR INTO A STRING ERRORS")

TestOperations = {}

    function TestOperations:testCreatesNewValue()
        luaunit.assertEquals(APInt(1), {1})
        luaunit.assertEquals(APInt(-1), {-1})
        luaunit.assertEquals(APInt({0, 1}), {0, 1})
        luaunit.assertEquals(APInt({1, 2, 3, -4}), {1, 2, 3, -4})
        luaunit.assertEquals(APInt(APInt(1)), {1})

        luaunit.assertEquals(APInt("12345"), {12345})
        luaunit.assertEquals(APInt("-54321"), {-54321})
        luaunit.assertEquals(APInt("0"), {0})
        luaunit.assertEquals(APInt(string.format("%.f", BASE)), {0, 1})
        luaunit.assertEquals(APInt("-" .. string.format("%.f", BASE)), {0, -1})
        
        local big_number_str = "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000"
        luaunit.assertEquals(tostring(APInt(big_number_str)), big_number_str)
        luaunit.assertEquals(tostring(APInt("-" .. big_number_str)), "-" .. big_number_str)

        luaunit.assertError(function() APInt(BASE) end)
        luaunit.assertError(function() APInt({BASE, BASE}) end)
        luaunit.assertError(function() APInt({1, -2, 3, 4}) end)
        luaunit.assertError(function() APInt("not a number") end)
        luaunit.assertError(function() APInt("123-456") end)
        luaunit.assertError(function() APInt("") end)
    end

    function TestOperations:testAddition()
        luaunit.assertEquals(APInt(2) + APInt(2), {4}) -- quick maths
        luaunit.assertEquals(APInt(BASE - 1) + APInt(BASE - 1), {4503599627370494, 1})
        luaunit.assertEquals(APInt({0, BASE - 1}) + APInt({0, BASE - 1}), {0, 4503599627370494, 1})
        luaunit.assertEquals(APInt(5) + APInt(-4), {1})
        luaunit.assertEquals(APInt(5) + APInt(-6), {-1})
        luaunit.assertEquals(APInt(BASE / 2) + APInt(BASE / 2), {0, 1})
    end

    function TestOperations:testSubtraction()
        luaunit.assertEquals(APInt(2) - APInt(1), {1})
        luaunit.assertEquals(APInt({0, 0, 1}) - APInt({0, BASE - 1}), {0, 1})
        luaunit.assertEquals(APInt({3}) - APInt({BASE - 1}), {3 - (BASE - 1)})
        luaunit.assertEquals(APInt(5) - APInt(-4), {9})
        luaunit.assertEquals(APInt(5) + APInt(-6), {-1})
    end

    function TestOperations:testMultiplication()
        luaunit.assertEquals(APInt(2) * APInt(2), {4})
        luaunit.assertEquals(APInt(-2) * APInt(3), {-6})
        luaunit.assertEquals(APInt(420) * APInt(0), {0})
        luaunit.assertEquals(APInt(math.sqrt(BASE)) * APInt(math.sqrt(BASE)), {0, 1})
        luaunit.assertEquals(APInt(-math.sqrt(BASE)) * APInt(math.sqrt(BASE)), {0, -1})

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

        luaunit.assertEquals(factorial(APInt(5)), {120})
        luaunit.assertEquals(factorial(APInt(20)), {958209396572160, 540})
    end

    function TestOperations:testDivision()
        luaunit.assertEquals(APInt(4) / APInt(2), {2})
        luaunit.assertEquals(APInt(-6) / APInt(2), {-3})
        luaunit.assertEquals(APInt(7) / APInt(3), {2})
        luaunit.assertEquals(APInt(-12) / APInt(-5), {2})
        luaunit.assertEquals(APInt(0) / APInt(420), {0})
        luaunit.assertEquals(APInt({0, 1}) / APInt(math.sqrt(BASE)), APInt(math.sqrt(BASE)))
        
        local huge_num_1 = APInt({2310042140305905, 3779025547483650, 2759084521790143, 1333207883151640, 2871280155256532, 2361179593819894})
        local huge_num_2 = APInt({4380989235077369, 1317378481282125, 3473886240354038})
        local huge_result = APInt({664333360460499, 3982308273631934, 3061069592710197})
        
        luaunit.assertEquals(huge_num_1 / huge_num_2, huge_result)
        luaunit.assertError(function() return APInt(10) / APInt(0) end)
    end

    function TestOperations:testModulo()
        luaunit.assertEquals(APInt(10) % APInt(3), {1})
        luaunit.assertEquals(APInt(-10) % APInt(3), {2})
        luaunit.assertEquals(APInt(-1) % APInt(10), {9})
        luaunit.assertEquals(APInt({0, 1}) % APInt(10), {6})
        luaunit.assertEquals(APInt({2107998818533376, 11344}) % APInt(100000), {40000})
    end

    function TestOperations:testPower()
        luaunit.assertEquals(APInt(2) ^ APInt(4), {16})
        luaunit.assertEquals(APInt(2) ^ APInt(53), {0, 2})
        luaunit.assertEquals(APInt(10) ^ APInt(-1), {0})
        luaunit.assertEquals(APInt(1) ^ APInt(-10), {1})
        luaunit.assertEquals(APInt(4) ^ APInt(0), {1})
        luaunit.assertEquals(APInt(10) ^ APInt(100), APInt("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"))
    end

    function TestOperations:testUnaryMinus()
        luaunit.assertEquals(-APInt(16), {-16})
        luaunit.assertEquals(-APInt(-2), {2})
        luaunit.assertEquals(-APInt(0), {0})
    end

    function TestOperations:testEqual()
        luaunit.assertTrue(APInt(1) == APInt(1))
        luaunit.assertTrue(APInt(1000) == APInt(1000))
        luaunit.assertTrue(APInt(2) + APInt(2) ~= APInt(5))
        luaunit.assertTrue(APInt({1, 2, 3}) == APInt({1, 2, 3}))
        luaunit.assertTrue(APInt({1, 3, 3}) ~= APInt({1, 2, 3}))
    end

    function TestOperations:testLessThan()
        luaunit.assertTrue(APInt(1) < APInt(2))
        luaunit.assertTrue(APInt({0}) < APInt({0, 1}))
        luaunit.assertTrue(APInt({3, 2, 1}) < APInt({1, 2, 3}))
    end

    function TestOperations:testToString()
        luaunit.assertEquals(tostring(APInt(1234)), "1234")
        luaunit.assertEquals(tostring(APInt({0, 1})), string.format("%.f", APInt.BASE))
        luaunit.assertEquals(tostring(-APInt(1234)), "-1234")
        luaunit.assertEquals(tostring(-APInt(0)), "0")

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

        luaunit.assertEquals(tostring(fibonacci(100)), "354224848179261915075")

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
        
        local big_factorial = "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000"
        luaunit.assertEquals(tostring(factorial(100)), big_factorial)
    end
os.exit(luaunit.LuaUnit.run())
