--!nocheck
--[[
	Unit and property tests for APInt. Runs on Lua 5.2, the Luau CLI and Roblox:

		lua5.2 test.lua
		luau test.lua

	It uses a tiny built-in runner instead of LuaUnit, because LuaUnit needs io and
	os.exit, which neither Luau nor Roblox provide. A failing run ends with an error,
	so the process exits with a non-zero status.
]]

local function load_apint()
	if script then -- Roblox: put this script next to the APInt ModuleScript
		return require(script.Parent.APInt)
	end
	if package and package.path then
		local directory = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
		package.path = directory .. "/../?.lua;" .. package.path
		return require("APInt")
	end
	return require("../APInt")
end

local APInt = load_apint()
local BASE = APInt.BASE

--------------------------------------------------------------------------------
-- Test runner
--------------------------------------------------------------------------------

local tests = {}

local function test(name, body)
	tests[#tests + 1] = { name = name, body = body }
end

local function check(condition, message)
	if not condition then
		error(message or "check failed", 2)
	end
end

-- Checks that x is an APInt with the given decimal value.
local function check_value(x, expected)
	if not APInt.__is_big_int(x) then
		error("expected an APInt equal to " .. expected .. ", got " .. type(x), 2)
	end
	local actual = tostring(x)
	if actual ~= expected then
		error("expected " .. expected .. ", got " .. actual, 2)
	end
end

-- Checks that x is an APInt whose internal digits are exactly the given ones.
local function check_digits(x, expected)
	local actual = APInt.format(x)
	if not APInt.__is_big_int(x) or actual ~= APInt.format(expected) then
		error("expected digits " .. APInt.format(expected) .. ", got " .. actual, 2)
	end
end

-- Checks that calling f raises an error, optionally containing the given text.
local function check_error(f, text)
	local ok, message = pcall(f)
	if ok then
		error("expected an error" .. (text and (" containing '" .. text .. "'") or ""), 2)
	end
	if text and not tostring(message):find(text, 1, true) then
		error("expected an error containing '" .. text .. "', got: " .. tostring(message), 2)
	end
end

local function snapshot(x)
	return APInt.format(x)
end

--------------------------------------------------------------------------------
-- Helpers for building test values
--------------------------------------------------------------------------------

local function factorial(n)
	local result = APInt(1)
	for i = 2, n do
		result = result * APInt(i)
	end
	return result
end

local function fibonacci(n)
	local a, b = APInt(0), APInt(1)
	for _ = 1, n do
		a, b = b, a + b
	end
	return a
end

local function repeat_string(s, n)
	return string.rep(s, n)
end

-- A random number with the given amount of digits (in base 2^52) and a random sign.
local function random_apint(length)
	local digits = {}
	for i = 1, length do
		digits[i] = math.random(0, 2^26 - 1) * 2^26 + math.random(0, 2^26 - 1)
	end
	if digits[length] == 0 then
		digits[length] = 1
	end
	if math.random() < 0.5 then
		digits[length] = -digits[length]
	end
	return APInt(digits)
end

local SIZES = { 1, 2, 3, 5, 10, 31, 32, 33, 70 } -- 32 is the Karatsuba threshold

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

test("new from numbers", function()
	check_digits(APInt(0), { 0 })
	check_digits(APInt(1), { 1 })
	check_digits(APInt(-1), { -1 })
	check_digits(APInt(BASE - 1), { BASE - 1 })
	check_digits(APInt(BASE), { 0, 1 })
	check_digits(APInt(-BASE), { 0, -1 })
	check_digits(APInt(2^53 - 1), { BASE - 1, 1 })
	check_digits(APInt(-(2^53 - 1)), { BASE - 1, -1 })
	check_digits(APInt(-0), { 0 })
	check(APInt.new(12345) == APInt(12345))
end)

test("new rejects numbers that are not exact integers", function()
	check_error(function() APInt(2^53) end, "too large")
	check_error(function() APInt(-2^53) end, "too large")
	check_error(function() APInt(1.5) end, "whole number")
	check_error(function() APInt(-0.25) end, "whole number")
	check_error(function() APInt(math.huge) end)
	check_error(function() APInt(-math.huge) end)
	check_error(function() APInt(0 / 0) end)
end)

test("new from strings", function()
	check_digits(APInt("12345"), { 12345 })
	check_digits(APInt("-54321"), { -54321 })
	check_digits(APInt("0"), { 0 })
	check_digits(APInt("-0"), { 0 })
	check_digits(APInt("000123"), { 123 })
	check_digits(APInt(repeat_string("0", 40)), { 0 })
	check_digits(APInt("-" .. repeat_string("0", 40) .. "7"), { -7 })
	check_digits(APInt("999999999999999"), { 999999999999999 }) -- 15 digits: single digit path
	check_digits(APInt("9999999999999999"), { 992800745259007, 2 }) -- 16 digits: chunked path
	check_digits(APInt("4503599627370496"), { 0, 1 })
	check_digits(APInt("-4503599627370496"), { 0, -1 })
	check_digits(APInt("15511210043330985984000000"), { 4416259248619520, 3444180505 })
	check_digits(APInt("1" .. repeat_string("0", 30)), { 1387490258714624, 222044604925031 })
	check(APInt.from_string("42") == APInt(42))
end)

test("new rejects malformed strings", function()
	for _, bad in ipairs({ "", "-", "abc", "12a", " 12", "12 ", "1.5", "1e5", "+-1", "--1", "0x10", "+5" }) do
		check_error(function() APInt(bad) end, "Invalid number string")
	end
	check_error(function() APInt.from_string(12) end, "must be a string")
end)

test("new from digit tables", function()
	check_digits(APInt({ 0, 1 }), { 0, 1 })
	check_digits(APInt({ 1, 2, 3, -4 }), { 1, 2, 3, -4 })
	check_digits(APInt({ 5, 0, 0 }), { 5 })
	check_digits(APInt({ 0, 0 }), { 0 })
	check_digits(APInt({ -0 }), { 0 })
	check_digits(APInt({ BASE - 1, BASE - 1 }), { BASE - 1, BASE - 1 })
	check_error(function() APInt({}) end, "empty")
	check_error(function() APInt({ BASE }) end, "out of range")
	check_error(function() APInt({ BASE, BASE }) end, "out of range")
	check_error(function() APInt({ 1, -2, 3, 4 }) end, "out of range")
	check_error(function() APInt({ 1, -BASE }) end, "out of range")
	check_error(function() APInt({ 1.5 }) end, "whole numbers")
	check_error(function() APInt({ "1" }) end, "whole numbers")
end)

test("new copies digit tables instead of adopting them", function()
	local digits = { 1, 2 }
	local x = APInt(digits)
	digits[1] = 99
	check_digits(x, { 1, 2 })
	check(getmetatable(digits) == nil, "the caller's table must not become an APInt")
end)

test("new from an APInt returns it unchanged", function()
	local x = APInt("123456789012345678901234567890")
	check(rawequal(APInt(x), x))
end)

test("new with a sign argument", function()
	check_value(APInt(5, -1), "-5")
	check_value(APInt(-5, 1), "5")
	check_value(APInt(-5, -1), "-5")
	check_value(APInt(0, -1), "0")
	check_value(APInt(APInt(7), -1), "-7")
	check_digits(APInt({ 1, 2 }, -1), { 1, -2 })
	check_error(function() APInt("5", 1) end, "sign argument")
	check_error(function() APInt(5, 2) end, "Sign must be")
end)

test("new rejects other types", function()
	check_error(function() APInt(true) end)
	check_error(function() APInt(nil) end)
	check_error(function() APInt(function() end) end)
end)

--------------------------------------------------------------------------------
-- Arithmetic
--------------------------------------------------------------------------------

test("addition", function()
	check_digits(APInt(2) + APInt(2), { 4 })
	check_digits(APInt(5) + APInt(-4), { 1 })
	check_digits(APInt(5) + APInt(-6), { -1 })
	check_digits(APInt(BASE / 2) + APInt(BASE / 2), { 0, 1 })
	check_digits(APInt(BASE - 1) + APInt(BASE - 1), { BASE - 2, 1 })
	check_digits(APInt(2^53 - 1) + APInt(2^53 - 1), { BASE - 2, 3 })
	check_digits(APInt(-(2^53 - 1)) + APInt(-(2^53 - 1)), { BASE - 2, -3 })
	check_digits(APInt({ 0, BASE - 1 }) + APInt({ 0, BASE - 1 }), { 0, BASE - 2, 1 })
	check_digits(APInt({ BASE - 1, BASE - 1, BASE - 1 }) + APInt(1), { 0, 0, 0, 1 })
	check_digits(APInt(1) + APInt({ BASE - 1, BASE - 1, BASE - 1 }), { 0, 0, 0, 1 })
	check_digits(APInt({ 0, 0, 1 }) + APInt({ 0, 0, -1 }), { 0 })
	check_digits(APInt({ 5, 0, 1 }) + APInt({ 0, 0, -1 }), { 5 })
	check_digits(APInt({ 0, 0, -1 }) + APInt(1), { BASE - 1, -(BASE - 1) })
end)

test("subtraction", function()
	check_digits(APInt(2) - APInt(1), { 1 })
	check_digits(APInt(5) - APInt(-4), { 9 })
	check_digits(APInt(3) - APInt(BASE - 1), { 3 - (BASE - 1) })
	check_digits(APInt(-(BASE - 1)) - APInt(1), { 0, -1 })
	check_digits(APInt({ 0, 0, 1 }) - APInt({ 0, BASE - 1 }), { 0, 1 })
	check_digits(APInt({ 0, 0, 0, 1 }) - APInt(1), { BASE - 1, BASE - 1, BASE - 1 })
	check_digits(APInt(1) - APInt({ 0, 0, 0, 1 }), { BASE - 1, BASE - 1, -(BASE - 1) })
	check_digits(APInt({ 7, 8, 9 }) - APInt({ 7, 8, 9 }), { 0 })
	check_digits(APInt({ 7, 8, -9 }) - APInt({ 7, 8, -9 }), { 0 })
	check_digits(APInt({ 1, 2, 3 }) - APInt({ 0, 2, 3 }), { 1 })
end)

test("multiplication", function()
	check_digits(APInt(2) * APInt(2), { 4 })
	check_digits(APInt(-2) * APInt(3), { -6 })
	check_digits(APInt(-2) * APInt(-3), { 6 })
	check_digits(APInt(420) * APInt(0), { 0 })
	check_digits(APInt(-5) * APInt(0), { 0 }) -- never a negative zero
	check_digits(APInt(0) * APInt({ 1, 2, 3 }), { 0 })
	check_digits(APInt(2^26) * APInt(2^26), { 0, 1 })
	check_digits(APInt(-(2^26)) * APInt(2^26), { 0, -1 })
	check_digits(APInt(BASE - 1) * APInt(BASE - 1), { 1, BASE - 2 })
	check_digits(APInt(2^53 - 1) * APInt(-2), { BASE - 2, -3 })
	check_digits(APInt({ BASE - 1, BASE - 1 }) * APInt({ BASE - 1, BASE - 1 }), { 1, 0, BASE - 2, BASE - 1 })
	check_digits(factorial(20), { 958209396572160, 540 })
	check_digits(factorial(25), { 4416259248619520, 3444180505 })
	check_value(factorial(100),
		"93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000")
end)

test("multiplication of large numbers", function()
	-- (10^n - 1)^2 == 10^2n - 2 * 10^n + 1, which is "9...980...01"
	for _, n in ipairs({ 20, 700, 1500 }) do
		local nines = APInt(repeat_string("9", n))
		check_value(nines * nines, repeat_string("9", n - 1) .. "8" .. repeat_string("0", n - 1) .. "1")
	end
	-- a long number times a short one exercises the unbalanced split
	local long = APInt(repeat_string("9", 1500))
	local short = APInt(repeat_string("9", 600))
	check_value(long * short, repeat_string("9", 599) .. "8" .. repeat_string("9", 900) .. repeat_string("0", 599) .. "1")
end)

test("division rounds down and modulo takes the sign of the divisor", function()
	local cases = {
		-- a, b, a / b, a % b
		{ 7, 2, 3, 1 },
		{ -7, 2, -4, 1 },
		{ 7, -2, -4, -1 },
		{ -7, -2, 3, -1 },
		{ 6, 3, 2, 0 },
		{ -6, 3, -2, 0 },
		{ 6, -3, -2, 0 },
		{ 0, 5, 0, 0 },
		{ 0, -5, 0, 0 },
		{ 1, 10, 0, 1 },
		{ -1, 10, -1, 9 },
		{ 1, -10, -1, -9 },
	}
	for _, case in ipairs(cases) do
		local a, b = APInt(case[1]), APInt(case[2])
		check_value(a / b, tostring(case[3]))
		check_value(a % b, tostring(case[4]))
	end
end)

test("division of multi-digit numbers", function()
	check_digits(APInt({ 0, 1 }) / APInt(2^26), { 2^26 })
	check_digits(APInt({ 0, 1 }) % APInt(10), { 6 })
	check_value(APInt(238497923847) / APInt(238477), "1000087")
	check_value(APInt(238497923847) % APInt(238477), "176348")
	check_digits(APInt(10) ^ APInt(100) / APInt(10^15),
		{ 0, 4419942254379008, 1218062511332401, 2252745923636380, 1562451958731451, 5397605 })
	local huge_1 = APInt({ 2310042140305905, 3779025547483650, 2759084521790143, 1333207883151640, 2871280155256532, 2361179593819894 })
	local huge_2 = APInt({ 4380989235077369, 1317378481282125, 3473886240354038 })
	check_digits(huge_1 / huge_2, { 664333360460499, 3982308273631934, 3061069592710197 })

	local dividend = APInt(2) ^ APInt(200) - APInt(1)
	local divisor = APInt(3) ^ APInt(50)
	check_value(dividend / divisor, "2238393297946874000179418290327143433")
	check_value(dividend % divisor, "249667313308346329176558")
	check_value(-dividend / divisor, "-2238393297946874000179418290327143434")
	check_value(-dividend % divisor, tostring(divisor - APInt("249667313308346329176558")))

	-- a small number divided by a larger one
	check_value(APInt(5) / APInt({ 0, 1 }), "0")
	check_value(APInt(-5) / APInt({ 0, 1 }), "-1")
	check_value(APInt(5) % APInt({ 0, -1 }), tostring(APInt(5) - APInt(BASE)))
end)

test("division where quotient digit estimates need correcting", function()
	-- dividend = divisor * quotient + (|divisor| - 1), with extreme leading digits
	local divisors = {
		APInt({ BASE - 1, BASE - 1, 1 }),
		APInt({ 0, 0, 1 }),
		APInt({ 1, 0, BASE - 1 }),
		APInt({ BASE - 1, BASE / 2 }),
		APInt({ 0, BASE / 2 - 1 }),
		APInt(BASE - 1),
		APInt(3),
	}
	local quotients = {
		APInt({ BASE - 1, BASE - 1, BASE - 1 }),
		APInt({ 0, 0, BASE - 1 }),
		APInt({ 1, BASE - 1 }),
		APInt(BASE - 1),
	}
	for _, divisor in ipairs(divisors) do
		for _, quotient in ipairs(quotients) do
			for _, remainder in ipairs({ APInt(0), APInt(1), divisor - APInt(1) }) do
				local dividend = divisor * quotient + remainder
				check(dividend / divisor == quotient, "quotient of " .. tostring(dividend) .. " / " .. tostring(divisor))
				check(dividend % divisor == remainder, "remainder of " .. tostring(dividend) .. " / " .. tostring(divisor))
			end
		end
	end
end)

test("division by zero", function()
	check_error(function() return APInt(10) / APInt(0) end, "Division by zero")
	check_error(function() return APInt(10) % APInt(0) end, "Division by zero")
	check_error(function() return APInt({ 1, 2, 3 }) / APInt(0) end, "Division by zero")
end)

test("power", function()
	check_value(APInt(2) ^ APInt(4), "16")
	check_digits(APInt(2) ^ APInt(53), { 0, 2 })
	check_value(APInt(-3) ^ APInt(3), "-27")
	check_value(APInt(-7) ^ APInt(21), "-558545864083284007")
	check_value(APInt(3) ^ APInt(200),
		"265613988875874769338781322035779626829233452653394495974574961739092490901302182994384699044001")
	check_value(APInt(10) ^ APInt(100), "1" .. repeat_string("0", 100))
	check_value(APInt(4) ^ APInt(0), "1")
	check_value(APInt(0) ^ APInt(0), "1")
	check_value(APInt(0) ^ APInt(5), "0")
	check_value(APInt({ 1, 2, 3 }) ^ APInt(1), tostring(APInt({ 1, 2, 3 })))
end)

test("power with negative exponents rounds down like 1 / base^n", function()
	check_value(APInt(10) ^ APInt(-1), "0")
	check_value(APInt(2) ^ APInt(-1), "0")
	check_value(APInt(-2) ^ APInt(-1), "-1")
	check_value(APInt(-2) ^ APInt(-2), "0")
	check_value(APInt(1) ^ APInt(-10), "1")
	check_value(APInt(-1) ^ APInt(-3), "-1")
	check_value(APInt(-1) ^ APInt(-2), "1")
	check_error(function() return APInt(0) ^ APInt(-1) end, "Negative power of zero")
end)

test("power with huge exponents", function()
	local huge = APInt({ 1, 1 }) -- 2^52 + 1, odd
	check_value(APInt(1) ^ huge, "1")
	check_value(APInt(0) ^ huge, "0")
	check_value(APInt(-1) ^ huge, "-1")
	check_value(APInt(-1) ^ (huge + APInt(1)), "1")
	check_value(APInt(2) ^ -huge, "0")
	check_error(function() return APInt(2) ^ huge end, "too large")
end)

test("unary minus", function()
	check_digits(-APInt(16), { -16 })
	check_digits(-APInt(-2), { 2 })
	check_digits(-APInt(0), { 0 })
	check_digits(-APInt({ 1, 2, 3 }), { 1, 2, -3 })
	check_digits(-APInt({ 1, 2, -3 }), { 1, 2, 3 })
end)

--------------------------------------------------------------------------------
-- Comparison
--------------------------------------------------------------------------------

test("equality", function()
	check(APInt(1) == APInt(1))
	check(APInt(1000) == APInt(1000))
	check(APInt(2) + APInt(2) ~= APInt(5))
	check(APInt({ 1, 2, 3 }) == APInt({ 1, 2, 3 }))
	check(APInt({ 1, 3, 3 }) ~= APInt({ 1, 2, 3 }))
	check(APInt({ 1, 2, 3 }) ~= APInt({ 1, 2, -3 }))
	check(APInt({ 1, 2 }) ~= APInt({ 1, 2, 3 }))
	check(APInt("123456789012345678901234567890") == APInt("123456789012345678901234567890"))
	check(APInt(0) == -APInt(0))
	-- like any Lua table, an APInt never equals a plain number or another kind of table
	check(APInt(5) ~= 5)
	check(APInt(1) ~= { 1 })
end)

test("ordering", function()
	-- every value is smaller than the ones after it
	local ordered = {
		APInt({ 0, 0, -1 }), APInt({ 5, -(BASE - 1) }), APInt({ 3, -(BASE - 1) }), APInt({ 0, -1 }),
		APInt(-(BASE - 1)), APInt(-2), APInt(-1), APInt(0), APInt(1), APInt(123), APInt(BASE - 1),
		APInt({ 0, 1 }), APInt({ 7, 1 }), APInt({ 3, 2 }), APInt({ 0, 0, 1 }), APInt({ 1, 0, 1 }),
	}
	for i = 1, #ordered do
		for j = 1, #ordered do
			local a, b = ordered[i], ordered[j]
			local message = tostring(a) .. " vs " .. tostring(b)
			check((a < b) == (i < j), message .. " (<)")
			check((a <= b) == (i <= j), message .. " (<=)")
			check((a > b) == (i > j), message .. " (>)")
			check((a >= b) == (i >= j), message .. " (>=)")
			check((a == b) == (i == j), message .. " (==)")
		end
	end
end)

test("sorting", function()
	local values = {}
	for i = 1, 60 do
		values[i] = random_apint(math.random(1, 4))
	end
	table.sort(values)
	for i = 2, #values do
		check(values[i - 1] <= values[i])
	end
end)

if _VERSION == "Lua 5.2" then
	-- Luau refuses to compare a table with a number before calling any metamethod
	test("comparison with numbers", function()
		check(APInt(1) < 2)
		check(2 > APInt(1))
		check(APInt(2) <= 2)
		check(not (APInt({ 0, 1 }) < 5))
	end)
end

--------------------------------------------------------------------------------
-- Strings
--------------------------------------------------------------------------------

test("tostring", function()
	check(tostring(APInt(1234)) == "1234")
	check(tostring(APInt(-1234)) == "-1234")
	check(tostring(APInt(0)) == "0")
	check(tostring(-APInt(0)) == "0")
	check(tostring(APInt({ 0, 1 })) == "4503599627370496")
	check(tostring(APInt({ 0, -1 })) == "-4503599627370496")
	check(tostring(APInt(BASE - 1)) == "4503599627370495")
	check(tostring(fibonacci(100)) == "354224848179261915075")
	check(tostring(fibonacci(300)) == "222232244629420445529739893461909967206666939096499764990979600")
end)

test("tostring keeps zeros inside the number", function()
	local ten = APInt(10)
	for _, exponent in ipairs({ 7, 8, 9, 15, 16, 17, 23, 24, 25, 100 }) do
		local power = ten ^ APInt(exponent)
		check_value(power, "1" .. repeat_string("0", exponent))
		check_value(power + APInt(1), "1" .. repeat_string("0", exponent - 1) .. "1")
		check_value(power - APInt(1), repeat_string("9", exponent))
		check_value(-power, "-1" .. repeat_string("0", exponent))
	end
end)

test("string round trips", function()
	for _, length in ipairs({ 1, 7, 8, 9, 15, 16, 17, 31, 32, 33, 100, 500 }) do
		for _ = 1, 10 do
			local digits = { tostring(math.random(1, 9)) }
			for i = 2, length do
				digits[i] = tostring(math.random(0, 9))
			end
			local text = table.concat(digits)
			check(tostring(APInt(text)) == text, text)
			check(tostring(APInt("-" .. text)) == "-" .. text, "-" .. text)
		end
	end
end)

test("format shows the internal digits", function()
	check(APInt.format(APInt({ 1, 2, -3 })) == "[1, 2, -3]")
	check(APInt.format(APInt(0)) == "[0]")
	check(APInt.format({ 4, 5 }) == "[4, 5]")
	check(APInt.format(42) == "42")
	check_error(function() APInt.format({ "x" }) end, "invalid table")
	check_error(function() APInt.format("x") end, "Invalid argument")
end)

--------------------------------------------------------------------------------
-- Mixed operand types and modes
--------------------------------------------------------------------------------

test("operations convert numbers and strings", function()
	check_value(APInt(5) + 3, "8")
	check_value(3 + APInt(5), "8")
	check_value(APInt(5) - 7, "-2")
	check_value(10 - APInt(5), "5")
	check_value(APInt(5) * -2, "-10")
	check_value(APInt(7) / 2, "3")
	check_value(7 % APInt(4), "3")
	check_value(APInt(2) ^ 10, "1024")
	check_value(2 ^ APInt(10), "1024")
	check_value(APInt(1) + "99999999999999999999", "100000000000000000000")
end)

test("STRICT mode rejects other types", function()
	APInt.MODE = "STRICT"
	local ok, message = pcall(function() return APInt(5) + 3 end)
	APInt.MODE = "NOT-STRICT"
	check(not ok and tostring(message):find("not APInt", 1, true), "expected a STRICT mode error")
	check_value(APInt(5) + APInt(3), "8")
end)

test("WARNING mode still converts", function()
	APInt.MODE = "WARNING"
	local ok, result = pcall(function() return APInt(5) + 3 end)
	APInt.MODE = "NOT-STRICT"
	check(ok, tostring(result))
	check_value(result, "8")
end)

--------------------------------------------------------------------------------
-- Immutability
--------------------------------------------------------------------------------

test("operations never modify their operands", function()
	local values = {
		APInt(0), APInt(7), APInt(-7), APInt({ 1, 2, 3 }), APInt({ 1, 2, -3 }),
		APInt({ BASE - 1, BASE - 1 }), APInt({ 0, 0, -1 }), random_apint(45), random_apint(45),
	}
	local operations = {
		function(a, b) return a + b end,
		function(a, b) return a - b end,
		function(a, b) return a * b end,
		function(a, b) if b ~= APInt(0) then return a / b end end,
		function(a, b) if b ~= APInt(0) then return a % b end end,
		function(a, b) return a < b, a <= b, a == b end,
		function(a) return -a, tostring(a), a ^ APInt(3) end,
	}
	for _, a in ipairs(values) do
		for _, b in ipairs(values) do
			local before_a, before_b = snapshot(a), snapshot(b)
			for _, operation in ipairs(operations) do
				operation(a, b)
				check(snapshot(a) == before_a and snapshot(b) == before_b, "operand changed")
			end
		end
	end
end)

test("an operation may use the same value on both sides", function()
	local x = APInt({ 3, 4, 5 })
	check(x - x == APInt(0))
	check(x / x == APInt(1))
	check(x % x == APInt(0))
	check(x * x == APInt({ 3, 4, 5 }) * APInt({ 3, 4, 5 }))
	check_digits(x, { 3, 4, 5 })
end)

--------------------------------------------------------------------------------
-- Properties on random numbers
--------------------------------------------------------------------------------

test("algebraic identities hold for random numbers", function()
	local zero = APInt(0)
	for _, size_a in ipairs(SIZES) do
		for _, size_b in ipairs(SIZES) do
			local a, b, c = random_apint(size_a), random_apint(size_b), random_apint(size_b)
			local label = " (sizes " .. size_a .. ", " .. size_b .. ")"
			check((a + b) - b == a, "(a + b) - b == a" .. label)
			check(a + b == b + a, "a + b == b + a" .. label)
			check(a - b == -(b - a), "a - b == -(b - a)" .. label)
			check(a * b == b * a, "a * b == b * a" .. label)
			check(a * (b + c) == a * b + a * c, "a * (b + c) == a * b + a * c" .. label)
			check((a * b) / b == a, "(a * b) / b == a" .. label)
			check((a * b) % b == zero, "(a * b) % b == 0" .. label)
			local q, r = a / b, a % b
			check(q * b + r == a, "(a / b) * b + a % b == a" .. label)
			if b > zero then
				check(zero <= r and r < b, "0 <= a % b < b" .. label)
			else
				check(b < r and r <= zero, "b < a % b <= 0" .. label)
			end
			local less, equal, greater = a < b, a == b, b < a
			check((less and 1 or 0) + (equal and 1 or 0) + (greater and 1 or 0) == 1, "exactly one ordering" .. label)
		end
	end
end)

test("string conversion round trips for random numbers", function()
	for _, size in ipairs(SIZES) do
		local x = random_apint(size)
		check(APInt(tostring(x)) == x, "round trip of " .. size .. " digits")
	end
end)

test("powers match repeated multiplication", function()
	for _, size in ipairs({ 1, 2, 4 }) do
		local base = random_apint(size)
		local expected = APInt(1)
		for exponent = 0, 24 do
			check(base ^ APInt(exponent) == expected, "exponent " .. exponent)
			expected = expected * base
		end
	end
end)

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

math.randomseed(1234)
local passed, failed = 0, 0
for _, entry in ipairs(tests) do
	local ok, message = pcall(entry.body)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL  " .. entry.name .. "\n      " .. tostring(message))
	end
end
print(string.format("%s: %d passed, %d failed", _VERSION, passed, failed))
if failed > 0 then
	error(failed .. " test(s) failed", 0)
end
