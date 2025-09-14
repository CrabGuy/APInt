![APInt Library Logo](./logo.png)

# A PInt 🍺: Arbitrary-Precision Integer library for Lua (and Roblox)


**APInt** is an (A)rbitrary (P)recision (Int)eger library for calculating large numbers without losing a bit of precision.

The library is designed to be **easy to use** and tries to integrate as seamlessly as possible into existing Lua projects by **overloading standard arithmetic** metatables.

## Features

*   **Arbitrary-Precision Integers**: Create and manipulate integers far larger than Lua's native number type can handle.
*   **Full Arithmetic Support**: All standard arithmetic operators are overloaded:
    *   Addition (`+`)
    *   Subtraction (`-`)
    *   Multiplication (`*`)
    *   Division (`/`) (floor division)
    *   Modulo (`%`)
    *   Exponentiation (`^`)
    *   Unary Minus (`-`)
*   **Comparison Operators**: Compare large integers with standard operators:
    *   Less Than (`<`)
    *   Equality (`==`)
    *   (Greater than, less than or equal to, etc., also work and are inferred from `<` and `==`)
*   **String Conversion**: Convert large integers to and from strings.
* **Additional operations** (implemented for internal use in the library but can be used freely)
    *   **Bitwise-like Shifts**: Perform logical left and right shifts (`__lsl` and `__lsr` are implemented but not aliased to `<<` or `>>` as they are not standard in Lua 5.2).
    *   **Flexible Type Handling**: The library can be configured to operate in different modes (`STRICT`, `WARNING`, `NOT-STRICT`) to handle operations with mixed `APInt` and standard number types.

## Getting Started

To use the library, simply require the `APInt.lua` file in your project.

```lua
local APInt = require("APInt")
```

If coming from **roblox**: make the library a module script and require it from either a local or server script.

### Creating New Large Integers

You can create a new arbitrary-precision integer from a number, a string, or another `APInt` object.

```lua
-- From a number
local a = APInt.new(12345)
local b = APInt(98765) -- You can also call the library object directly

-- From a string for very large numbers
local very_large_number = APInt.new("123456789012345678901234567890")
local another_large_one = APInt("987654321098765432109876543210")
```

## Usage Snippets

### Arithmetic Operations

All the standard arithmetic operators work as you would expect.

```lua
local APInt = require("APInt")

local a = APInt("23456789012345678901")
local b = APInt("98765432109876543210")

-- Addition
local sum = a + b
print("Sum:", sum)

-- Subtraction
local difference = b - a
print("Difference:", difference)

-- Multiplication
local product = APInt(2)^APInt(256)
print("Product:", product)

-- Division
local quotient, remainder = a / b
print("Quotient:", quotient)
print("Remainder:", remainder)

-- Modulo
local mod = b % a
print("Modulo:", mod)

-- Exponentiation
local power = APInt(5)^APInt(100)
print("5^100:", power)
```

### Comparisons

You can compare `APInt` objects using standard comparison operators.

```lua
local APInt = require("APInt")

local a = APInt("100000000000000000000")
local b = APInt("100000000000000000001")

if a < b then
    print("a is less than b")
end

if a == a then
    print("a is equal to itself")
end
```

### String Conversion

Easily convert `APInt` objects to strings for printing or serialization.

```lua
local APInt = require("APInt")

local large_number = APInt(2)^APInt(128)

-- Implicitly calls __tostring
print("2^128 is: " .. large_number)

local as_string = tostring(large_number)
print(as_string)
```

### Configuration

You can change the library's mode for handling non-`APInt` types in operations.

*   `"NOT-STRICT"` (default): Automatically converts numbers to `APInt`.
*   `"WARNING"`: Converts numbers and prints a warning.
*   `"STRICT"`: Throws an error if an operation involves a non-`APInt` type.

```lua
local APInt = require("APInt")

APInt.MODE = "STRICT"

local a = APInt(100)
-- This will now throw an error instead of automatically converting 50
local result = a + 50
```

## Additional information

### Implementation
The numbers are saved as a table (array) of numbers in base 2^52 by default with the last number of the array also storing the sign. Which takes advantage of the lua [float64](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) number type without losing precision. The table has a variable size and every number is immutable. The algorithms used for the operations are the name of the functions in the code for that operation.

### General Info

- The library tries to replicate the ease-of-use and style of how [Python](https://github.com/python/cpython) handles big integers
- It tries to compete with the [BigNum](https://github.com/RoStrap/Math/blob/master/BigNum.lua) library by the great programmer [Validark](https://github.com/Validark). It has equal or better performance for correct results in roblox studio which I am satisfied with.
- The algorithms used should be self-explanatory but there are links to relevant resources where I felt it was needed.
- The library is tested using [Busted](https://github.com/lunarmodules/busted) in the file "test.lua", it runs as a standalone file using lua5.2 (you need to install Busted for it to work).

### TODO

- Should be adding some proper performance benchmarks against the [BigNum](https://github.com/RoStrap/Math/blob/master/BigNum.lua) library.
- The library was made for use in roblox games but does not take advantage of Roblox's Bit32 library which could improve performance.