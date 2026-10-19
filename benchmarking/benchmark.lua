--!nocheck
--[[
	Benchmarks APInt against BigNum (https://github.com/RoStrap/Math/blob/master/BigNum.lua).

	Every operation is timed on numbers of increasing size, giving both libraries the
	same values, and every result is cross-checked between the two libraries first.

		lua5.2 benchmark.lua [--quick] [--label=NAME] [--output=FILE.csv]
		luau benchmark.lua -a [--quick] [--label=NAME]

	The results are printed as a table followed by CSV between "BEGIN CSV" and "END CSV"
	lines. When file access is available (Lua 5.2) the CSV is also written to --output.
	benchmark.py runs this script on every installed runtime and plots the results; it
	can also plot output copied from Roblox. In Roblox, put this script next to the
	APInt and BigNum ModuleScripts.
]]

local function load_module(name)
	if script then
		return require(script.Parent[name])
	end
	if package and package.path then
		local directory = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
		package.path = directory .. "/../?.lua;" .. package.path
		return require(name)
	end
	return require("../" .. name)
end

local APInt = load_module("APInt")
local BigNum = load_module("BigNum")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local options = { quick = false, label = _VERSION, output = nil }
for _, argument in ipairs({ ... }) do
	if argument == "--quick" then
		options.quick = true
	elseif argument:match("^%-%-label=") then
		options.label = argument:match("^%-%-label=(.*)$")
	elseif argument:match("^%-%-output=") then
		options.output = argument:match("^%-%-output=(.*)$")
	else
		error("Unknown argument: " .. argument)
	end
end

local config = {
	sizes = options.quick and { 5, 50, 500 } or { 5, 10, 20, 50, 100, 200, 500, 1000 }, -- decimal digits
	min_time = options.quick and 0.02 or 0.05, -- seconds each timed batch must last
	repeats = options.quick and 2 or 3, -- batches per measurement, the fastest one counts
	pool_size = 8, -- different operand sets per measurement, used in turn
	max_seconds_per_op = 1, -- skip sizes predicted to take longer than this per operation
}

local yield = (type(task) == "table" and task.wait) or function() end -- avoids Roblox timeouts

--------------------------------------------------------------------------------
-- Workloads
--------------------------------------------------------------------------------

local function random_digits(count)
	local digits = { tostring(math.random(1, 9)) }
	for i = 2, count do
		digits[i] = tostring(math.random(0, 9))
	end
	return table.concat(digits)
end

-- Each workload says how to build operand strings for a size and what it computes.
-- `digits` is the size of the largest value involved, which fixes BigNum's width.
local workloads = {
	{
		name = "add", description = "N digits + N digits",
		operands = function(n) return { random_digits(n), random_digits(n) } end,
		digits = function(n) return n + 1 end,
		run = function(a, b) return a + b end,
	},
	{
		name = "sub", description = "N digits - N digits",
		operands = function(n) return { random_digits(n), random_digits(n) } end,
		digits = function(n) return n + 1 end,
		run = function(a, b) return a - b end,
	},
	{
		name = "mul", description = "N digits * N digits",
		operands = function(n) return { random_digits(n), random_digits(n) } end,
		digits = function(n) return 2 * n end,
		run = function(a, b) return a * b end,
	},
	{
		name = "div", description = "2N digits / N digits",
		operands = function(n) return { random_digits(2 * n), random_digits(n) } end,
		digits = function(n) return 2 * n end,
		run = function(a, b) return a / b end,
	},
	{
		name = "mod", description = "2N digits % N digits",
		operands = function(n) return { random_digits(2 * n), random_digits(n) } end,
		digits = function(n) return 2 * n end,
		run = function(a, b) return a % b end,
	},
	{
		name = "pow", description = "3 digit base ^ exponent, N digit result",
		operands = function(n)
			local base = math.random(100, 999)
			return { tostring(base), tostring(math.max(1, math.floor(n / math.log(base, 10)))) }
		end,
		digits = function(n) return n + 3 end,
		run = function(a, b) return a ^ b end,
	},
	{
		name = "eq", description = "N digits == N digits (equal values)",
		operands = function(n) local text = random_digits(n) return { text, text } end,
		digits = function(n) return n end,
		run = function(a, b) return a == b end,
	},
	{
		name = "lt", description = "N digits < N digits",
		operands = function(n) return { random_digits(n), random_digits(n) } end,
		digits = function(n) return n end,
		run = function(a, b) return a < b end,
	},
	{
		name = "unm", description = "-(N digits)",
		operands = function(n) return { random_digits(n) } end,
		digits = function(n) return n + 1 end,
		run = function(a) return -a end,
	},
	{
		name = "tostring", description = "N digits to string",
		operands = function(n) return { random_digits(n) } end,
		digits = function(n) return n end,
		run = function(a) return tostring(a) end,
	},
	{
		name = "new", description = "string of N digits to number",
		operands = function(n) return { random_digits(n) } end,
		digits = function(n) return n end,
		run = nil, -- creation is timed from the strings themselves, see below
	},
}

--------------------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------------------

local RADIX_BASE = 2^24 -- BigNum's digit base

-- BigNum numbers have a fixed width in base 2^24 digits ("radix"), so each workload gets
-- the smallest width that holds its largest value.
local function bignum_radix(decimal_digits)
	return math.ceil((decimal_digits * math.log(10, 2) + 2) / 24) + 1
end

-- Builds a BigNum of the given width from a non-negative APInt. BigNum's own parser is
-- far too slow for large inputs, and it misreads strings longer than its width argument
-- when they start with 5-9 (it treats the first decimal digit as a sign digit).
local function apint_to_bignum(value, radix)
	local digits = {}
	local divisor = APInt(RADIX_BASE)
	for i = radix, 1, -1 do
		digits[i] = tonumber(tostring(value % divisor))
		value = value / divisor
	end
	assert(value == APInt(0) and digits[1] < RADIX_BASE / 2, "value does not fit in the BigNum width")
	return BigNum.new(digits)
end

-- Reads a BigNum (big-endian two's complement digits) back as an APInt.
local function bignum_to_apint(x)
	local value = APInt(0)
	for i = 1, #x do
		value = value * APInt(RADIX_BASE) + APInt(x[i])
	end
	if x[1] >= RADIX_BASE / 2 then
		value = value - APInt(RADIX_BASE) ^ APInt(#x)
	end
	return value
end

local libraries = {
	{
		name = "APInt",
		from_apint = function(value) return value end,
		to_apint = function(x) return x end,
		new = function() return APInt.new end,
	},
	{
		name = "BigNum",
		from_apint = apint_to_bignum,
		to_apint = bignum_to_apint,
		new = function(radix)
			-- wide enough that BigNum parses every string correctly
			return function(text) return BigNum.new(text, math.max(radix, #text + 1)) end
		end,
	},
}

--------------------------------------------------------------------------------
-- Timing
--------------------------------------------------------------------------------

local function time_batch(run, count)
	local start = os.clock()
	run(count)
	return os.clock() - start
end

-- Returns operations per second for run(count), which performs count operations.
local function measure(run)
	local count = 1
	local elapsed = time_batch(run, count)
	while elapsed < config.min_time do
		-- grow towards the target duration, at most 10x at a time
		local factor = math.min(10, math.max(2, config.min_time * 1.2 / math.max(elapsed, 1e-6)))
		count = math.ceil(count * factor)
		yield()
		elapsed = time_batch(run, count)
	end
	local best = elapsed
	for _ = 2, config.repeats do
		yield()
		best = math.min(best, time_batch(run, count))
	end
	return count / best
end

-- Builds the function that performs `count` operations of a workload with one library.
local function make_runner(workload, inputs, new)
	local pool = #inputs
	if workload.name == "new" then
		return function(count)
			for i = 1, count do
				new(inputs[(i - 1) % pool + 1][1])
			end
		end
	end
	local run = workload.run
	return function(count)
		for i = 1, count do
			local operands = inputs[(i - 1) % pool + 1]
			run(operands[1], operands[2])
		end
	end
end

-- Computes one result of the workload with a library, in a form comparable across libraries.
local function sample_result(workload, library, strings, inputs, radix)
	local result
	if workload.name == "new" then
		result = library.new(radix)(strings[1][1])
	else
		result = workload.run(inputs[1][1], inputs[1][2])
	end
	if type(result) == "table" then
		return library.to_apint(result)
	end
	return result
end

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

math.randomseed(12345)
local rows = {}

-- Whether an operation that ran at `rate` ops/s on `size` digits would be too slow on
-- `next_size` digits, assuming the cost grows at most with the cube of the size.
local function too_slow(rate, size, next_size)
	return (next_size / size)^3 / rate > config.max_seconds_per_op
end

print(string.format("Benchmarking APInt against BigNum on %s%s", options.label, options.quick and " (quick)" or ""))

for _, workload in ipairs(workloads) do
	print(string.format("\n%s: %s", workload.name, workload.description))
	print(string.format("  %8s %14s %14s %10s", "digits", "APInt ops/s", "BigNum ops/s", "speedup"))
	local last = {} -- last[library] = { size, rate } of its previous measurement

	for _, size in ipairs(config.sizes) do
		local radix = bignum_radix(workload.digits(size))
		local strings = {}
		for i = 1, config.pool_size do
			strings[i] = workload.operands(size)
		end

		local rates, samples = {}, {}
		for _, library in ipairs(libraries) do
			local previous = last[library.name]
			if not (previous and too_slow(previous.rate, previous.size, size)) then
				local inputs = strings
				if workload.name ~= "new" then
					inputs = {}
					for i, texts in ipairs(strings) do
						inputs[i] = {}
						for j, text in ipairs(texts) do
							inputs[i][j] = library.from_apint(APInt(text), radix)
						end
					end
				end
				samples[#samples + 1] = sample_result(workload, library, strings, inputs, radix)

				local rate = measure(make_runner(workload, inputs, library.new(radix)))
				rates[library.name] = rate
				rows[#rows + 1] = { library.name, workload.name, workload.description, size, rate }
				last[library.name] = { size = size, rate = rate }
				yield()
			end
		end

		local apint, bignum = rates.APInt, rates.BigNum
		local consistent = #samples < 2 or samples[1] == samples[2]
		print(string.format("  %8d %14s %14s %10s%s", size,
			apint and string.format("%.0f", apint) or "skipped",
			bignum and string.format("%.0f", bignum) or "skipped",
			(apint and bignum) and string.format("%.2fx", apint / bignum) or "-",
			consistent and "" or "   WARNING: results differ"))
	end
end

local csv = { "runtime,library,operation,workload,digits,ops_per_second" }
for _, row in ipairs(rows) do
	csv[#csv + 1] = string.format('"%s",%s,%s,"%s",%d,%.3f', options.label, row[1], row[2], row[3], row[4], row[5])
end
local csv_text = table.concat(csv, "\n")

print("\nBEGIN CSV\n" .. csv_text .. "\nEND CSV")

if options.output then
	local file = assert(io.open(options.output, "w"), "Cannot open " .. options.output)
	file:write(csv_text, "\n")
	file:close()
	print("Saved results to " .. options.output)
end
