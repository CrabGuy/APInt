# APInt 🍺: Arbitrary-Precision Integer Library for Lua (and Roblox)

**APInt** is an **A**rbitrary **P**recision **Int**eger library, built to calculate large numbers without losing precision.

This library is engineered to be **effortlessly easy to use**, integrating as seamlessly as possible into existing Lua projects by **overloading standard arithmetic** metatables.

## Features

* **Arbitrary-Precision Integers**: Create and manipulate integers far larger than Lua's maximum integer limit.


* **Overloaded Operators**: Supports `+`, `-`, `*`, `/`, `%`, `^`, unary `-`, `<`, and `==`.


* **String & Roblox Support**: Works natively with `tostring` and offers standard Wally/Roblox compatibility.



## Getting Started

```lua
local APInt = require("APInt")

-- Create integers from numbers or strings
local a = APInt(12345)
local b = APInt("987654321098765432109876543210")

```

Installation:

* **Lua**: Place `APInt.lua` in your repository and call `require("APInt")`.

* **Roblox**: just make the library a ModuleScript and require it from a Local or Server Script.

* **Wally**: Available [[here]](https://wally.run/package/vran-n/apint) on [Wally (a roblox package manager)](https://wally.run/) thanks to [Vran-n](https://github.com/Vran-n)!


## Usage examples

```lua
local APInt = require("APInt")

local a = APInt("23456789012345678901")
local b = APInt("98765432109876543210")

-- Arithmetic & Comparisons
local sum = a + b
local diff = b - a
local prod = APInt(2) ^ APInt(256)
local div = a / b
local is_less = a < b

-- String Conversion
print("Result:")
print(sum)

```

### Configuration

Set standard or strict type checking via `APInt.MODE`:

* **`"NOT-STRICT"`** (default): Automatically converts numbers to `APInt`.


* **`"WARNING"`**: Converts numbers with a warning message.


* **`"STRICT"`**: Throws an error on non-`APInt` inputs.



## Performance comparison!

### The Competitor
APInt competes with the [BigNum](https://github.com/RoStrap/Math/blob/master/BigNum.lua) library by the great programmer [Validark](https://github.com/Validark) which is the de-facto standard for the usecase.

### Benchmarks

The benchmarks are in the repository (alongside benchmark results), so **you can test it** on your own machine! (You'll need the **BigNum** and **APInt** libraries in the same directory).

Comparing **APInt** against **BigNum** across benchmark operations (ops/s):

| Operation | Workload | APInt (ops/s) | BigNum (ops/s) | Speedup |
| --- | --- | --- | --- | --- |
| **Creation (.new)** | Large | 210,106 | 63 | **3,341.58x faster** |
| **To String (tostr)** | Small | 3,295,436 | 36,614 | **90.00x faster** |
| **To String (tostr)** | Large | 82,904 | 2,689 | **30.83x faster** |
| **Division (/)** | Large vs Large | 185,822 | 10,349 | **17.96x faster** |

## More Info ℹ️

### Implementation Details
The numbers are stored as a table (array) of numbers in base `2^52` by default, with the last number also storing the sign. This structure takes advantage of Lua's [float64](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) number type without sacrificing precision. The table is variable-sized, and every number is immutable.

### Testing

The library is unit-tested using LuaUnit (`test.lua`) and automated randomized correctness checks.

### Additional info

- This library aims to replicate the simplicity and elegance of how [Python](https://github.com/python/cpython) handles big integers.
- I implemented [karatsuba's algorithm](https://en.wikipedia.org/wiki/Karatsuba_algorithm) for multiplication ([and division](https://www.researchgate.net/publication/2649773_Practical_Integer_Division_with_Karatsuba_Complexity)) but the performance was worse even for big numbers so it got cut in the final release.
- My favourite beer was Guinness (I don't drink anymore)

### Missing Features (Feel free to fork!)

-   The library was built for Roblox games but doesn't yet leverage Roblox's `buffer` library, which could be faster.
