package.path = package.path .. ";../?.lua"

local APInt = require("./APInt")
local BigNum = require("./BigNum")

assert(APInt.new and BigNum.new, "Libraries must implement a .new method for benchmark to work properly")

local config = {
    num_small_values = 300,
    num_large_values = 300,
    small_digits_max = 5,
    large_digits_max = 20,
    iterations = 5,
}

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

local function time_it_takes(f)
    local start = os.clock()
    f()
    return os.clock() - start
end

local function generate_numbers(library, amount, max_digits)
    local numbers = {}
    for i = 1, amount do
        local num_digits = math.random(1, max_digits)
        table.insert(numbers, library.new(random_digits_string(num_digits)))
    end
    return numbers
end

local operations = {
    { name = "add", fn = function(a, b) return a + b end },
    { name = "sub", fn = function(a, b) return a - b end },
    { name = "mul", fn = function(a, b) return a * b end },
    { name = "div", fn = function(a, b) return a / b end },
    { name = "mod", fn = function(a, b) return a % b end },
    { name = "pow", fn = function(a, b) return a ^ b end },
    { name = "eq",  fn = function(a, b) return a == b end },
    { name = "lt",  fn = function(a, b) return a < b end },
    { name = "unm", fn = function(a) return -a end },
    { name = "tostr", fn = function(a) return tostring(a) end },
}

local function prepare_safe_pairs(num_list1, num_list2, is_div_or_mod)
    local pairs = {}
    for i = 1, #num_list1 do
        for j = 1, #num_list2 do
            local a = num_list1[i]
            local b = num_list2[j]
            if is_div_or_mod and tostring(b) == "0" then
                b = b + 1
            end
            table.insert(pairs, { a = a, b = b })
        end
    end
    return pairs
end

local function run_benchmark_set(op_fn, pairs)
    for i = 1, #pairs do
        local p = pairs[i]
        op_fn(p.a, p.b)
    end
end

math.randomseed(12345)

print("Preparing numbers for benchmarks...")

local data = {
    APInt = {
        small = generate_numbers(APInt, config.num_small_values, config.small_digits_max),
        large = generate_numbers(APInt, config.num_large_values, config.large_digits_max),
        pow_exponents = generate_numbers(APInt, 5, 1)
    },
    BigNum = {
        small = generate_numbers(BigNum, config.num_small_values, config.small_digits_max),
        large = generate_numbers(BigNum, config.num_large_values, config.large_digits_max),
        pow_exponents = generate_numbers(BigNum, 5, 1)
    }
}

print("--- Starting Benchmarks ---\n")

for _, op_data in ipairs(operations) do
    local op_name = op_data.name
    local op_fn = op_data.fn
    print(string.format("--- Operation: %s ---", op_name))

    for _, library_name in ipairs({"APInt", "BigNum"}) do
        local library_data = data[library_name]
        local is_div_or_mod = (op_name == "div" or op_name == "mod")

        local pairs_small = prepare_safe_pairs(library_data.small, library_data.small, is_div_or_mod)
        local pairs_large = prepare_safe_pairs(library_data.large, library_data.large, is_div_or_mod)
        local pairs_pow   = (op_name == "pow") and prepare_safe_pairs(library_data.small, library_data.pow_exponents, false) or nil
        local pairs_mixed = (op_name ~= "pow") and prepare_safe_pairs(library_data.small, library_data.large, is_div_or_mod) or nil

        local delta_small, delta_large, delta_mixed

        if op_name == "pow" then
            delta_small = 1/0
            delta_large = 1/0
            for k = 1, config.iterations do
                delta_small = math.min(delta_small, time_it_takes(function() run_benchmark_set(op_fn, pairs_pow) end))
                delta_large = math.min(delta_large, time_it_takes(function() run_benchmark_set(op_fn, pairs_pow) end))
            end
            delta_mixed = "N/A"
        else
            delta_small, delta_large, delta_mixed = 1/0, 1/0, 1/0
            for k = 1, config.iterations do
                delta_small = math.min(delta_small, time_it_takes(function() run_benchmark_set(op_fn, pairs_small) end))
                delta_large = math.min(delta_large, time_it_takes(function() run_benchmark_set(op_fn, pairs_large) end))
                delta_mixed = math.min(delta_mixed, time_it_takes(function() run_benchmark_set(op_fn, pairs_mixed) end))
            end
        end

        print(string.format("%s:\n\tSmall vs Small: %f\n\tLarge vs Large: %f\n\tSmall vs Large: %s",
            library_name, delta_small, delta_large, tostring(delta_mixed)))
    end
    print("")
end

print("--- Operation: .new (Creation) ---")
for _, library_name in ipairs({"APInt", "BigNum"}) do
    local library = (library_name == "APInt") and APInt or BigNum
    local best_delta = 1/0
    for k = 1, config.iterations do
        local delta = time_it_takes(function()
            generate_numbers(library, config.num_small_values, config.small_digits_max)
            generate_numbers(library, config.num_large_values, config.large_digits_max)
        end)
        best_delta = math.min(best_delta, delta)
    end
    print(string.format("%s:\t%f", library_name, best_delta))
end

print("\n--- Benchmarks Finished ---")