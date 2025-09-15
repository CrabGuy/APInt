# A PInt 🍺: The Arbitrary-Precision Integer Library for Lua (and Roblox)

<table>
<tr>
<td>
<strong>APInt</strong> is an <strong>A</strong>rbitrary <strong>P</strong>recision <strong>Int</strong>eger library, built to calculate large numbers without losing a single bit of precision. 🔢

This library is engineered to be <strong>effortlessly easy to use</strong>, integrating as seamlessly as possible into your existing Lua projects by <strong>overloading standard arithmetic</strong> metatables.
</td>
<td>
<img src="./logo.png" alt="APInt Library Logo" />
</td>
</tr>
</table>

## Features 🌟

*   **🧠 Arbitrary-Precision Integers**: Create and manipulate integers far larger than Lua's maximum int value.

All standard arithmetic operators are overloaded:
*   **➕ Operations**:
    *   Addition (`+`)
    *   Subtraction (`-`)
    *   Multiplication (`*`)
    *   Division (`/`) (floor division)
    *   Modulo (`%`)
    *   Exponentiation (`^`)
    *   Unary Minus (`-`)
*   **⚖️ Comparison Operators**:
    *   Less Than (`<`)
    *   Equality (`==`)
    *   (Greater than, less than or equal to, etc., also work, inferred from `<` and `==`)
*   **📜 String Conversion**: `tostring` method also works.
* **⚙️ Additional Operations**: Implemented for internal use
    *   **Bitwise-like Shifts**: Perform logical left and right shifts (`__lsl` and `__lsr` are ready, though not aliased to `<<` or `>>` to maintain Lua 5.2 standards).
    *   **🔧 Flexible Type Handling**: Configure the library to operate in different modes (`STRICT`, `WARNING`, `NOT-STRICT`) to manage operations with mixed `APInt` and standard number types.

## Getting Started 🚀

To use APInt 🍺, simply `require` the `APInt.lua` file in your project.

```lua
local APInt = require("APInt")
```

If you're on **Roblox**: just make the library a ModuleScript and require it from a Local or Server Script.

### Creating New Large Integers 🔢

You can create new arbitrary-precision integers from a number, a string, or even another `APInt` object (a table of integers between `0` and `BASE`).

```lua
-- From a number
local a = APInt.new(12345)
local b = APInt(98765) -- You can also call the library object directly!

-- From a string for massive numbers
local very_large_number = APInt.new("123456789012345678901234567890")
local another_large_one = APInt("987654321098765432109876543210")
```

## Usage Snippets 💡

### Arithmetic Operations 🧮

All the standard arithmetic operators work seemlessly as you'd expect.

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

### Comparisons 👀


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

### String Conversion 🔄

You can `APInt` objects to strings for printing or serialization.

```lua
local APInt = require("APInt")

local large_number = APInt(2)^APInt(128)

-- Implicitly calls __tostring
print("2^128 is: " .. large_number)

local as_string = tostring(large_number)
print(as_string)
```

### Configuration 🛠️

You can tweak the library's mode for handling non-`APInt` types in operations.

*   `"NOT-STRICT"` (default): Automatically converts numbers to `APInt`. ✅
*   `"WARNING"`: Converts numbers but gives you a heads-up with a warning. ⚠️
*   `"STRICT"`: Throws an error if an operation involves a non-`APInt` type. 🛑

```lua
local APInt = require("APInt")

APInt.MODE = "STRICT"

local a = APInt(100)
-- This will now throw an error instead of silently converting 50!
local result = a + 50
```

## Performance Showdown 🏎️💨

### The Competitor
APInt competes with the [BigNum](https://github.com/RoStrap/Math/blob/master/BigNum.lua) library by the great programmer [Validark](https://github.com/Validark). It has equal or better performance for correct results in Roblox Studio, which I am satisfied with!

### Blazing-Fast Performance 🔥

The benchmark file is in the repository, so **you can test it** on your own machine! (You'll need the **BigNum** and **APInt** libraries in the same directory).

The results files are also in the repository: **"benchmark_results_computer"** for tests on **my computer™** and **"benchmark_results_studio"** for tests in **Roblox Studio**.

Here are some of the most egregious results:

### 🖥️ Computer Benchmark
| Operation | BigNum Time | APInt Time | Speedup |
| :--- | :--- | :--- | :--- |
| Creation (.new) | 1.003874 | 0.009388 | **~107x** |
| Division (Large) | 175.193368 | 49.426132 | **~3.5x** |
| Modulo (Large) | 170.684935 | 48.997882 | **~3.5x** |
| To String (Large) | 152.764841 | 11.557140 | **~13.2x** |

### 🕹️ Roblox Studio Benchmark
| Operation | BigNum Time | APInt Time | Speedup |
| :--- | :--- | :--- | :--- |
| Creation (.new) | 0.166527 | 0.020295 | **~8.2x** |
| Division (Large) | 6.890840 | 1.265368 | **~5.4x** |
| Modulo (Large) | 7.019249 | 1.278361 | **~5.5x** |
| To String (Large) | 6.511121 | 0.333968 | **~19.5x** |

## More Info ℹ️

### Implementation Details
The numbers are stored as a table (array) of numbers in base `2^52` by default, with the last number also storing the sign. This structure takes advantage of Lua's [float64](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) number type without sacrificing precision. The table is variable-sized, and every number is immutable. The algorithms used are linked in the source code!

### Testing

The library is unit-tested using [Busted](https://github.com/lunarmodules/busted) in `test.lua`. It runs as a standalone file with Lua 5.2 (with Busted installed).

### Additional info

-   This library aims to replicate the simplicity and elegance of how [Python](https://github.com/python/cpython) handles big integers. 🐍
- It took about a month of work
- I implemented [karatsuba's algorithm](https://en.wikipedia.org/wiki/Karatsuba_algorithm) for multiplication ([and divsion](https://www.researchgate.net/publication/2649773_Practical_Integer_Division_with_Karatsuba_Complexity)) but the performance was worse even for big numbers so it got cut in the final release.
- My favourite beer is Guinness

### Missing Features (Feel free to fork! 🍴)

-   The library was built for Roblox games but doesn't yet leverage Roblox's `Bit32` library, which could be faster.