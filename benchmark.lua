-- Import Libraries
local APInt = require("./APInt")
local BigNum = require("./BigNum")

assert(APInt.new and BigNum.new, "Libraries must implement a .new method for benchmark to work properly")

--[[
    Configuration for the benchmark.
    - num_small_values: The quantity of small numbers to generate.
    - num_large_values: The quantity of large numbers to generate.
    - small_digits_max: The maximum number of digits for a "small" number.
    - large_digits_max: The maximum number of digits for a "large" number.
]]
local config = {
    num_small_values = 1000,
    num_large_values = 1000,
    small_digits_max = 5,
    large_digits_max = 20,
}

-- Helper function to generate a string of random digits.
local function random_digits_string(digits_amount)
    local digits = {}
    for i = 1, digits_amount do
        table.insert(digits, tostring(math.random(0, 9)))
    end
    -- Avoid leading zeros for numbers with more than one digit
    if digits_amount > 1 and digits[1] == "0" then
        digits[1] = tostring(math.random(1, 9))
    end
    return table.concat(digits)
end

-- Helper function to measure execution time.
local function time_it_takes(f)
    local start = os.clock()
    f()
    return os.clock() - start
end

-- Generates a table of numbers for a given library.
local function generate_numbers(library, amount, max_digits)
    local numbers = {}
    for i = 1, amount do
        local num_digits = math.random(1, max_digits)
        table.insert(numbers, library.new(random_digits_string(num_digits)))
    end
    return numbers
end

-- The operations to be benchmarked.
local operations = {
    add = function(a, b) return a + b end,
    sub = function(a, b) return a - b end,
    mul = function(a, b) return a * b end,
    -- Avoid division by zero by adding 1 if b is zero.
    div = function(a, b)
        local is_zero = (tostring(b) == "0")
        return a / (is_zero and (b + 1) or b)
    end,
    mod = function(a, b)
        local is_zero = (tostring(b) == "0")
        return a % (is_zero and (b + 1) or b)
    end,
    -- For pow, we use smaller numbers to avoid extremely long computations.
    pow = function(a, b) return a^b end,
    eq = function(a, b) return a == b end,
    lt = function(a, b) return a < b end,
    unm = function(a, b) return -a end,
    tostr = function(a, b) return tostring(a) end,
}

-- Benchmarks an operation by iterating through two sets of numbers.
local function run_operation_benchmark(op, numbers1, numbers2)
    for i = 1, #numbers1 do
        for j = 1, #numbers2 do
            op(numbers1[i], numbers2[j])
        end
    end
end

-- Main execution block
print("Preparing numbers for benchmarks...")

-- Pre-generate all numbers to avoid creation overhead during tests.
local data = {
    APInt = {
        small = generate_numbers(APInt, config.num_small_values, config.small_digits_max),
        large = generate_numbers(APInt, config.num_large_values, config.large_digits_max),
        -- For pow, we need a small exponent to keep it fast
        pow_exponents = generate_numbers(APInt, 5, 1)
    },
    BigNum = {
        small = generate_numbers(BigNum, config.num_small_values, config.small_digits_max),
        large = generate_numbers(BigNum, config.num_large_values, config.large_digits_max),
        pow_exponents = generate_numbers(BigNum, 5, 1)
    }
}

print("--- Starting Benchmarks ---\n")

-- Benchmark operations
for op_name, op in pairs(operations) do
    print(string.format("--- Operation: %s ---", op_name))

    for library_name, library_data in pairs(data) do
        local delta_small, delta_large, delta_mixed

        if op_name == "pow" then
            -- Special case for pow to keep it from taking too long
            delta_small = time_it_takes(function()
                run_operation_benchmark(op, library_data.small, library_data.pow_exponents)
            end)
            delta_large = time_it_takes(function()
                run_operation_benchmark(op, library_data.large, library_data.pow_exponents)
            end)
            delta_mixed = "N/A" -- Not applicable for pow in this setup
        else
            delta_small = time_it_takes(function()
                run_operation_benchmark(op, library_data.small, library_data.small)
            end)
            delta_large = time_it_takes(function()
                run_operation_benchmark(op, library_data.large, library_data.large)
            end)
            delta_mixed = time_it_takes(function()
                run_operation_benchmark(op, library_data.small, library_data.large)
            end)
        end

        print(string.format("%s:\n\tSmall vs Small: %f\n\tLarge vs Large: %f\n\tSmall vs Large: %s",
            library_name, delta_small, delta_large, tostring(delta_mixed)))
    end
    print("") -- Newline for spacing
end

-- Benchmark creation time separately
print("--- Operation: .new (Creation) ---")
for library_name, library in pairs({ APInt = APInt, BigNum = BigNum }) do
    local delta = time_it_takes(function()
        -- Use the same generation parameters for a fair comparison
        generate_numbers(library, config.num_small_values, config.small_digits_max)
        generate_numbers(library, config.num_large_values, config.large_digits_max)
    end)
    print(string.format("%s:\t%f", library_name, delta))
end

print("\n--- Benchmarks Finished ---")