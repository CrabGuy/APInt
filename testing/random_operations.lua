--[[
	Prints random APInt operations and their results, one per line, so they can be
	checked against Python's integers by check_operations.py. Runs on Lua 5.2 and the
	Luau CLI:

		lua5.2 random_operations.lua [seed] [count]
		luau random_operations.lua -a [seed] [count]

	Every number is printed as its internal digit table, "[d1,d2,...]", so the checker can
	also verify that results are normalized. Line formats:

		<op> <a> <b> <result>      op in add, sub, mul, div, mod, pow, lt, le, eq
		addnum <a> <number> <result>   an APInt plus a Lua number
		unm <a> <result>
		tostring <a> <decimal>
		parse <decimal> <result>
]]

local function load_apint()
	if package and package.path then
		local directory = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
		package.path = directory .. "/../?.lua;" .. package.path
		return require("APInt")
	end
	return require("../APInt")
end

local APInt = load_apint()

local seed, count = ...
seed = tonumber(seed) or os.time()
count = tonumber(count) or 1000
math.randomseed(seed)

local BASE = APInt.BASE
local HALF = 2^26

-- Digit values around the edges where carries, borrows and splits happen.
local SPECIAL_DIGITS = { 0, 1, 2, HALF - 1, HALF, HALF + 1, BASE / 2, BASE - 2, BASE - 1 }

local function random_digit()
	if math.random() < 0.3 then
		return SPECIAL_DIGITS[math.random(#SPECIAL_DIGITS)]
	end
	return math.random(0, HALF - 1) * HALF + math.random(0, HALF - 1)
end

-- Most numbers are small, but some are long enough to take the Karatsuba path.
local function random_length()
	local roll = math.random()
	if roll < 0.5 then
		return math.random(1, 3)
	elseif roll < 0.8 then
		return math.random(4, 20)
	elseif roll < 0.95 then
		return math.random(21, 100)
	end
	return math.random(101, 250)
end

local function random_apint(length)
	local digits = {}
	for i = 1, length or random_length() do
		digits[i] = random_digit()
	end
	if math.random() < 0.5 then
		digits[#digits] = -digits[#digits]
	end
	return APInt(digits)
end

local function random_nonzero_apint(length)
	local x = random_apint(length)
	while x == APInt(0) do
		x = random_apint(length)
	end
	return x
end

local function random_decimal()
	local digits = {}
	for i = 1, math.random(1, 120) do
		digits[i] = tostring(math.random(0, 9))
	end
	return (math.random() < 0.5 and "-" or "") .. table.concat(digits)
end

local function show(x)
	return (APInt.format(x):gsub(" ", ""))
end

local function emit(...)
	print(table.concat({ ... }, " "))
end

-- Dividends built as b * q + r with r just below |b|, the worst case for quotient estimates.
local function hard_division_case()
	local b = random_nonzero_apint(math.random(1, 12))
	local q = random_apint(math.random(1, 12))
	local magnitude = b < APInt(0) and -b or b
	return b * q + (magnitude - APInt(1)), b
end

local binary_operations = {
	add = function(a, b) return a + b end,
	sub = function(a, b) return a - b end,
	mul = function(a, b) return a * b end,
	lt = function(a, b) return a < b end,
	le = function(a, b) return a <= b end,
	eq = function(a, b) return a == b end,
}
local binary_names = { "add", "sub", "mul", "lt", "le", "eq" }

for _ = 1, count do
	for _, name in ipairs(binary_names) do
		local a = random_apint()
		local b = math.random() < 0.1 and a or random_apint()
		local result = binary_operations[name](a, b)
		emit(name, show(a), show(b), type(result) == "boolean" and tostring(result) or show(result))
	end

	local a, b = random_apint(), random_nonzero_apint()
	if math.random() < 0.3 then
		a, b = hard_division_case()
	end
	emit("div", show(a), show(b), show(a / b))
	emit("mod", show(a), show(b), show(a % b))

	local base = random_apint(math.random(1, 3))
	local exponent = APInt(math.random(-3, 40))
	if base == APInt(0) and exponent < APInt(0) then
		exponent = -exponent
	end
	emit("pow", show(base), show(exponent), show(base ^ exponent))

	local number = (math.random(0, HALF - 1) * HALF * 2 + math.random(0, HALF * 2 - 1)) * (math.random() < 0.5 and -1 or 1)
	a = random_apint()
	emit("addnum", show(a), string.format("%.0f", number), show(a + number))

	emit("unm", show(a), show(-a))
	emit("tostring", show(a), tostring(a))

	local decimal = random_decimal()
	emit("parse", decimal, show(APInt(decimal)))
end
