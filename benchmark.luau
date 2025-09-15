-- benchmarks have been run on roblox servers in studio, this code is not vanilla lua

local APInt = require(script.Parent.APInt)
local BigNum = require(script.Parent.BigNum)

assert(APInt.new and BigNum.new, "Libraries must implement a .new method for benchmark to work properly")

local function random_digits_string(digits_amount)
	local digits = {}
	for i = 1, digits_amount do
		table.insert(digits, tostring(math.random(0, 9)))
	end

	return table.concat(digits)
end

local CREATION_DIGITS_AMOUNT = 100
local function create_value(digits, library)
	return library.new(digits)
end

-- as per specification https://www.lua.org/manual/5.2/manual.html#2.4
local operations = {
	sum = {
        op = function(a, b)
            return a + b
        end,
        digits_amount = 20,
    },
	
	sub = {
		op = function(a, b)
			return a - b
		end,
		digits_amount = 10,
	},
	
	mul = {
		op = function(a, b)
			return a * b
		end,
		digits_amount = 10,
	},
	
	div = {
		op = function(a, b)
			return a / (b + 1) -- to avoid division by 0 in testing
		end,
		digits_amount = 10,
	},
	
	mod = {
		op = function(a, b)
			return a % (b + 1)
		end,
		digits_amount = 10,
	},
	
	pow = {
		op = function(a, b)
			return a^b
		end,
		digits_amount = 2,
	},
	
	eq = {
		op = function(a, b)
			return a == b
		end,
		digits_amount = 10,
	},
	
	lt = {
		op = function(a, b)
			return a < b
		end,
		digits_amount = 10,
	},
	
	unm = {
		op = function(a, b)
			return -a
		end,
		digits_amount = 10,
	},

	tostring = {
		op = function(a, b)
			return tostring(a)
		end,
		digits_amount = 10,
	},
}

local function perform_operation(numbers, operation)
    for i = 1, #numbers - 1 do
        operation(numbers[i], numbers[i + 1])
    end
end

local function time_it_takes(f)
    local start = tick()
    f()
    local finish = tick()
    return finish - start
end

local function generate_numbers(amount, digits, library)
    local numbers = {}
    for i = 1, amount do
        table.insert(numbers, create_value(random_digits_string(math.random(1, digits)), library))
    end
    return numbers
end

local TESTS_AMOUNT = 1

local function test(name, operation, library)
    local numbers = generate_numbers(TESTS_AMOUNT, operation.digits_amount, library)
    local delta = time_it_takes(function()
        perform_operation(numbers, operation.op)
    end)

    print(`{name}:\t {delta}`)
end

local function test_creation(library)
    local delta = time_it_takes(function()
        for i = 1, TESTS_AMOUNT do
            create_value(random_digits_string(math.random(1, CREATION_DIGITS_AMOUNT)), library)
        end
    end)
    print(`.new:\t {delta}`)
end

local function run_test(library, operations)
    for name, operation in pairs(operations) do
        test(name, operation, library)
    end
end

print("-----")
print("APInt")
print("-----")
test_creation(APInt)
run_test(APInt, operations)


print("-----")
print("BigNum")
print("-----")
test_creation(BigNum)
run_test(BigNum, operations)