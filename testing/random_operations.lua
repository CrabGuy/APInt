---@diagnostic disable-next-line: undefined-global
package.path = package.path .. ";../?.lua"
math.randomseed(os.time())


local APInt = require("APInt")

local OPERATIONS_AMOUNT = 10
local FILE_NAME = "operations.txt"

local function io_write(file_name, content)
    if _VERSION == "Luau" then
        local file = game.Lighting:FindFirstChild(file_name) or Instance.new(file_name, game.Lighting)
        file.Source = content
        return
    end

    return io.output(file_name):write(content):close()
end

local function io_append(file_name, content)
    if _VERSION == "Luau" then
        local file = game.Lighting:FindFirstChild(file_name) or Instance.new(file_name, game.Lighting)
        file.Source = file.Source .. content
        return
    end

    return io.output(io.open(file_name, "a")):write(content):close()
end

local function random_number()
    local MAX_DECIMAL_DIGITS = 10
    local result = {}
    for i = 1, math.random(1, MAX_DECIMAL_DIGITS) do
        local x = math.random(0, 9)
        if i == 1 and x == 0 then
            x = math.random(1, 9)
        end

        table.insert(result, tostring(x))
    end
    return table.concat(result)
end

local function perform_operations(file_name, operation_amount, operation, operation_string)
    for i = 1, operation_amount do
        local first = random_number()
        local second = random_number()
        local result = operation(APInt(first), APInt(second))

        io_append(file_name, first .. operation_string .. second .. "=" .. APInt.format(result) .. "\n")
    end
end

io_write("operations.txt", "")

perform_operations("operations.txt", OPERATIONS_AMOUNT, function(x, y) return x + y end, "+")
perform_operations("operations.txt", OPERATIONS_AMOUNT, function(x, y) return x - y end, "-")
perform_operations("operations.txt", OPERATIONS_AMOUNT, function(x, y) return x * y end, "*")
perform_operations("operations.txt", OPERATIONS_AMOUNT, function(x, y) return x / y end, "/")