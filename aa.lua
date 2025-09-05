local BASE = 10

local function two_digit_division(a, b)
    local second = a[2] / b[1]
    second = math.floor(second)
    local first = math.floor(a[1] / b[1] + (BASE / b[1]) * a[2])

    if a[2] >= b[1] then
        first = two_digit_division({a[1], a[2] - second * b[1]}, b)[1]
    end

    local result_digits = {first, second}
    return result_digits
end

local function format(x)
    local digits = {}
    for i, v in pairs(x) do
        table.insert(digits, string.format("%.f", v))
    end

    local text = table.concat(digits, ", ")
    return text
end

local function print_formatted(x)
    return print("{"..format(x).."}")
end


print_formatted(two_digit_division(a, b))
