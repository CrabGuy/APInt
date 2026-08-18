---@diagnostic disable-next-line: undefined-global
package.path = package.path .. ";../?.lua"

local APInt = require("./APInt")
local BigNum = require("./BigNum")

assert(APInt.new and BigNum.new, "Libraries must implement a .new method for benchmark to work properly")

-- Roblox-compatible yield function (does nothing outside Roblox)
local yield_func = nil
if type(task) == "table" and type(task.wait) == "function" then
    yield_func = function()
        task.wait()
    end
end

local config = {
    num_small_values = 1000,
    num_large_values = 500,
    num_creation_values = 1000,
    small_digits_max = 5,
    large_digits_max = 50,
    ops_per_binary = 50000,
    ops_per_unary = 50000,
    ops_per_pow = 500,
    chunk_size = 1000,
    pow_chunk_size = 50,
    creation_chunk_size = 100,
    iterations = 10
}

local pow_exponent_values = { 0, 1, 2, 3, 4, 5, 10, 20, 50, 100 }

local function random_digits_string(digits_amount)
    local digits = {}
    for i = 1, digits_amount do
        table.insert(digits, tostring(math.random(0, 9)))
    end
    if digits_amount > 1 and digits[1] == "0" then
        digits[1] = tostring(math.random(1, 9))
    end
    return table.concat(digits)
end

local function generate_random_strings(amount, max_digits)
    local strings = {}
    for i = 1, amount do
        local num_digits = math.random(1, max_digits)
        table.insert(strings, random_digits_string(num_digits))
    end
    return strings
end

local function create_numbers_from_strings(library, strings)
    local numbers = {}
    for i = 1, #strings do
        numbers[i] = library.new(strings[i])
    end
    return numbers
end

local function generate_numbers(library, amount, max_digits)
    local strings = generate_random_strings(amount, max_digits)
    return create_numbers_from_strings(library, strings)
end

local function ensure_nonzero_denominators(list, library)
    local one = library.new("1")
    for i = 1, #list do
        if tostring(list[i]) == "0" then
            list[i] = list[i] + one
        end
    end
end

-- Run binary operations in chunks, yield between chunks, return total work time
local function run_binary_bench(op_fn, left, right, op_count, chunk_size)
    chunk_size = chunk_size or config.chunk_size
    local total_time = 0
    local n_left, n_right = #left, #right
    local start_i = 1
    while start_i <= op_count do
        local end_i = math.min(start_i + chunk_size - 1, op_count)
        local t_start = os.clock()
        for i = start_i, end_i do
            local a = left[(i - 1) % n_left + 1]
            local b = right[(i - 1) % n_right + 1]
            op_fn(a, b)
        end
        total_time = total_time + (os.clock() - t_start)
        if yield_func and end_i < op_count then
            yield_func()
        end
        start_i = start_i + chunk_size
    end
    return total_time
end

-- Run unary operations in chunks, yield between chunks, return total work time
local function run_unary_bench(op_fn, values, op_count, chunk_size)
    chunk_size = chunk_size or config.chunk_size
    local total_time = 0
    local n = #values
    local start_i = 1
    while start_i <= op_count do
        local end_i = math.min(start_i + chunk_size - 1, op_count)
        local t_start = os.clock()
        for i = start_i, end_i do
            op_fn(values[(i - 1) % n + 1])
        end
        total_time = total_time + (os.clock() - t_start)
        if yield_func and end_i < op_count then
            yield_func()
        end
        start_i = start_i + chunk_size
    end
    return total_time
end

-- Measure creation time (numbers from strings) with chunking, yields between chunks
local function measure_creation_time(library, strings, chunk_size)
    chunk_size = chunk_size or config.creation_chunk_size
    local total_time = 0
    local start_i = 1
    while start_i <= #strings do
        local end_i = math.min(start_i + chunk_size - 1, #strings)
        local t_start = os.clock()
        for i = start_i, end_i do
            library.new(strings[i])
        end
        total_time = total_time + (os.clock() - t_start)
        if yield_func and end_i < #strings then
            yield_func()
        end
        start_i = start_i + chunk_size
    end
    return total_time
end

-- Return the best (minimum) work time over multiple iterations
local function time_best(measure_func)
    local best = math.huge
    for _ = 1, config.iterations do
        local t = measure_func()
        if t < best then
            best = t
        end
    end
    return best
end

local function print_comparison(library_a, library_b, metric_name, ops_a, ops_b)
    local faster, slower, factor
    if ops_a > ops_b then
        faster, slower = library_a, library_b
        factor = ops_a / ops_b
    else
        faster, slower = library_b, library_a
        factor = ops_b / ops_a
    end
    print(string.format("%s is %.2fx faster than %s for %s", faster, factor, slower, metric_name))
end

math.randomseed(12345)

print("Preparing benchmark data...")

local binary_operations = {
    { name = "add", fn = function(a, b) return a + b end },
    { name = "sub", fn = function(a, b) return a - b end },
    { name = "mul", fn = function(a, b) return a * b end },
    { name = "div", fn = function(a, b) return a / b end },
    { name = "mod", fn = function(a, b) return a % b end },
    { name = "eq",  fn = function(a, b) return a == b end },
    { name = "lt",  fn = function(a, b) return a < b end },
}

local unary_operations = {
    { name = "unm", fn = function(a) return -a end },
    { name = "tostr", fn = function(a) return tostring(a) end },
}

local data = {}

for _, library_name in ipairs({ "APInt", "BigNum" }) do
    local library = (library_name == "APInt") and APInt or BigNum

    local small_a = generate_numbers(library, config.num_small_values, config.small_digits_max)
    local small_b = generate_numbers(library, config.num_small_values, config.small_digits_max)
    local large_a = generate_numbers(library, config.num_large_values, config.large_digits_max)
    local large_b = generate_numbers(library, config.num_large_values, config.large_digits_max)

    ensure_nonzero_denominators(small_b, library)
    ensure_nonzero_denominators(large_b, library)

    local pow_exponents = {}
    for i = 1, #pow_exponent_values do
        pow_exponents[i] = library.new(tostring(pow_exponent_values[i]))
    end

    data[library_name] = {
        small_a = small_a,
        small_b = small_b,
        large_a = large_a,
        large_b = large_b,
        pow_exponents = pow_exponents,
        creation_small_strings = generate_random_strings(config.num_creation_values, config.small_digits_max),
        creation_large_strings = generate_random_strings(config.num_creation_values, config.large_digits_max),
    }
end

print("--- Starting Benchmarks ---\n")

for _, op_data in ipairs(binary_operations) do
    local op_name = op_data.name
    local op_fn = op_data.fn
    print(string.format("--- Operation: %s (binary) ---", op_name))

    local results = {}

    for _, library_name in ipairs({ "APInt", "BigNum" }) do
        local lib_data = data[library_name]

        local small_small_time = time_best(function()
            return run_binary_bench(op_fn, lib_data.small_a, lib_data.small_b, config.ops_per_binary, config.chunk_size)
        end)

        local large_large_time = time_best(function()
            return run_binary_bench(op_fn, lib_data.large_a, lib_data.large_b, config.ops_per_binary, config.chunk_size)
        end)

        local small_large_time = time_best(function()
            return run_binary_bench(op_fn, lib_data.small_a, lib_data.large_b, config.ops_per_binary, config.chunk_size)
        end)

        local small_small_ops = config.ops_per_binary / small_small_time
        local large_large_ops = config.ops_per_binary / large_large_time
        local small_large_ops = config.ops_per_binary / small_large_time

        results[library_name] = {
            small_small = small_small_ops,
            large_large = large_large_ops,
            small_large = small_large_ops,
        }

        print(string.format(
            "%s:\n\tsmall vs small: %.0f ops/s\n\tlarge vs large: %.0f ops/s\n\tsmall vs large: %.0f ops/s",
            library_name,
            small_small_ops,
            large_large_ops,
            small_large_ops
        ))
    end

    print("")
    print_comparison("APInt", "BigNum", "small vs small", results.APInt.small_small, results.BigNum.small_small)
    print_comparison("APInt", "BigNum", "large vs large", results.APInt.large_large, results.BigNum.large_large)
    print_comparison("APInt", "BigNum", "small vs large", results.APInt.small_large, results.BigNum.small_large)
    print("")
end

print("--- Operation: pow (binary) ---")
do
    local pow_fn = function(a, b) return a ^ b end
    local results = {}

    for _, library_name in ipairs({ "APInt", "BigNum" }) do
        local lib_data = data[library_name]
        local pow_time = time_best(function()
            return run_binary_bench(pow_fn, lib_data.small_a, lib_data.pow_exponents, config.ops_per_pow, config.pow_chunk_size)
        end)
        results[library_name] = config.ops_per_pow / pow_time
        print(string.format(
            "%s:\n\tsmall base, small exponent: %.0f ops/s",
            library_name,
            results[library_name]
        ))
    end

    print("")
    print_comparison("APInt", "BigNum", "pow (small base, small exponent)", results.APInt, results.BigNum)
    print("")
end

for _, op_data in ipairs(unary_operations) do
    local op_name = op_data.name
    local op_fn = op_data.fn
    print(string.format("--- Operation: %s (unary) ---", op_name))

    local results = {}

    for _, library_name in ipairs({ "APInt", "BigNum" }) do
        local lib_data = data[library_name]

        local small_time = time_best(function()
            return run_unary_bench(op_fn, lib_data.small_a, config.ops_per_unary, config.chunk_size)
        end)

        local large_time = time_best(function()
            return run_unary_bench(op_fn, lib_data.large_a, config.ops_per_unary, config.chunk_size)
        end)

        local small_ops = config.ops_per_unary / small_time
        local large_ops = config.ops_per_unary / large_time

        results[library_name] = {
            small = small_ops,
            large = large_ops,
        }

        print(string.format(
            "%s:\n\tsmall: %.0f ops/s\n\tlarge: %.0f ops/s",
            library_name,
            small_ops,
            large_ops
        ))
    end

    print("")
    print_comparison("APInt", "BigNum", "small", results.APInt.small, results.BigNum.small)
    print_comparison("APInt", "BigNum", "large", results.APInt.large, results.BigNum.large)
    print("")
end

print("--- Operation: new (creation) ---")
do
    local results = {}

    for _, library_name in ipairs({ "APInt", "BigNum" }) do
        local library = (library_name == "APInt") and APInt or BigNum
        local lib_data = data[library_name]

        local small_time = time_best(function()
            return measure_creation_time(library, lib_data.creation_small_strings, config.creation_chunk_size)
        end)

        local large_time = time_best(function()
            return measure_creation_time(library, lib_data.creation_large_strings, config.creation_chunk_size)
        end)

        local small_ops = config.num_creation_values / small_time
        local large_ops = config.num_creation_values / large_time

        results[library_name] = {
            small = small_ops,
            large = large_ops,
        }

        print(string.format(
            "%s:\n\tsmall: %.0f ops/s\n\tlarge: %.0f ops/s",
            library_name,
            small_ops,
            large_ops
        ))
    end

    print("")
    print_comparison("APInt", "BigNum", "creation (small)", results.APInt.small, results.BigNum.small)
    print_comparison("APInt", "BigNum", "creation (large)", results.APInt.large, results.BigNum.large)
    print("")
end

print("\n--- Benchmarks Finished ---")