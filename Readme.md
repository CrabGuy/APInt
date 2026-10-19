# APInt 🍺: Arbitrary-Precision Integer Library for Lua (and Roblox)

**APInt** is an **A**rbitrary **P**recision **Int**eger library, built to calculate large numbers without losing precision.

This library is engineered to be **effortlessly easy to use**, integrating as seamlessly as possible into existing Lua projects by **overloading standard arithmetic** metatables.

## Features

* **Arbitrary-Precision Integers**: Create and manipulate integers far larger than Lua's maximum integer limit.


* **Overloaded Operators**: Supports `+`, `-`, `*`, `/`, `%`, `^`, unary `-`, `==`, `<`, `<=`, `>` and `>=` (and `//` in Luau, which is the same as `/`).


* **String & Roblox Support**: Works natively with `tostring` and offers standard Wally/Roblox compatibility.


* **Fast**: from about 1.1x up to thousands of times faster than [BigNum](#performance-comparison), depending on the operation and number size.



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

### How numbers behave

* **Integer division rounds down**, and `%` takes the sign of the divisor, exactly like Python and Lua's own `//` and `%`. So `a == (a / b) * b + a % b` always holds:
  `APInt(-7) / APInt(2)` is `-4` and `APInt(-7) % APInt(2)` is `1`.
* **Negative exponents round down the same way**, as if computing `1 / a^n`: `APInt(2) ^ -1` is `0`, `APInt(-2) ^ -1` is `-1`, and `APInt(-1) ^ -3` is `-1`.
* **Lua numbers must be exact whole numbers**, smaller than `2^53` in magnitude. Bigger doubles may already have lost precision, so pass those values as strings: `APInt("12345678901234567890")`.
* **Numbers are immutable**: every operation returns a new value, and creating an `APInt` from a digit table copies the table.
* `APInt(5) == 5` is always `false`, because Lua only calls `__eq` when both sides are tables. Compare against `APInt(5)` instead. In Lua 5.2, `<` and `<=` also work against plain numbers, but Luau requires both sides to be `APInt`.

### Configuration

Set standard or strict type checking via `APInt.MODE`:

* **`"NOT-STRICT"`** (default): Automatically converts numbers (and strings) to `APInt`.


* **`"WARNING"`**: Converts numbers with a warning message.


* **`"STRICT"`**: Throws an error on non-`APInt` inputs.



## Performance comparison!

### The Competitor
APInt competes with the [BigNum](https://github.com/RoStrap/Math/blob/master/BigNum.lua) library by the great programmer [Validark](https://github.com/Validark) which is the de-facto standard for the usecase.

### Benchmarks

The benchmark times every operation on numbers from 5 to 1000 decimal digits, feeding the same values to both libraries and checking that both produce the same results before timing them. BigNum numbers have a fixed width, so for each workload it gets the smallest width that holds the values involved.

![APInt speedup over BigNum](benchmarking/results/speedup.png)

APInt speedup over BigNum on Luau and Lua 5.2 (see [`benchmarking/results`](benchmarking/results) for the raw numbers and per-runtime charts, including Luau with native code generation):

| Operation | Workload | Luau, 5 digits | Luau, 50 digits | Luau, 500 digits | Lua 5.2, 5 digits | Lua 5.2, 500 digits |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| **Addition** | N + N digits | 1.7x | 1.9x | 3.5x | 1.8x | 2.9x |
| **Subtraction** | N - N digits | 2.7x | 2.6x | 4.4x | 2.5x | 3.9x |
| **Multiplication** | N * N digits | 3.1x | 3.6x | 6.8x | 2.4x | 6.3x |
| **Division** | 2N / N digits | 8.5x | 31x | 1,755x | 5.4x | 1,273x |
| **Modulo** | 2N % N digits | 8.6x | 34x | 5,226x | 5.4x | 1,956x |
| **Power** | 3 digit base, N digit result | 9.6x | 13x | 19x | 7.8x | 15x |
| **Equality** | N == N digits | 1.4x | 1.8x | 2.0x | 1.4x | 1.9x |
| **Less than** | N < N digits | 1.1x | 1.2x | 1.1x | 1.3x | 1.4x |
| **Negation** | -(N digits) | 2.1x | 1.9x | 2.4x | 2.2x | 2.4x |
| **To string** | N digits | 20x | 62x | 639x | 31x | 630x |
| **Creation** | string of N digits | 7.4x | 30,406x | BigNum too slow | 6.4x | BigNum too slow |

Measured on a desktop Linux machine with the Luau 0.743 CLI and Lua 5.2.4. Numbers of roughly 16 to 31 digits are the closest race (about 1.1x to 1.8x for addition and subtraction), because they take two APInt digits and miss the single-digit fast path, while BigNum's fixed width is at its smallest.

**Run it yourself:** put `BigNum.lua` in the repository root and run `python3 benchmarking/benchmark.py`. It benchmarks every runtime it finds (`lua5.2`, and `luau` on your PATH or in the `LUAU` environment variable), saves the CSV results and draws the charts with matplotlib. `--quick` gives a faster, rougher run.

**On Roblox:** put `benchmarking/benchmark.lua` in a Script next to the `APInt` and `BigNum` ModuleScripts and run it. Then save the Output window text to a file and plot it with `python3 benchmarking/benchmark.py --plot output.txt`.

A note for fair comparisons: `BigNum.new` misreads strings that are longer than its width argument and start with a digit from 5 to 9 (it treats the first decimal digit as a sign digit). With the default width of 32, this affects numbers of 32 or more digits, so the benchmark builds BigNum values from their digits directly and cross-checks every workload.

## More Info ℹ️

### Implementation Details
The numbers are stored as a table (array) of numbers in base `2^52`, least significant digit first, with the last number also storing the sign. This structure takes advantage of Lua's [float64](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) number type without sacrificing precision: doubles hold every integer below `2^53` exactly, and `2^52` is the largest base where adding two digits and a carry stays below that. The table is variable-sized, always normalized (no leading zero digits), and every number is immutable, so small numbers from -5 to 256 are created once and shared.

* **Addition and subtraction** work digit by digit; numbers with a single digit use plain Lua arithmetic.
* **Multiplication** splits each digit into two 26-bit halves, whose products are exact, and assembles the full 104-bit product of two digits from them. Numbers with 32 or more digits use [Karatsuba's algorithm](https://en.wikipedia.org/wiki/Karatsuba_algorithm).
* **Division** is schoolbook long division with one base `2^52` digit of quotient per step. Each quotient digit is estimated with floating point division of the leading digits, then corrected exactly, so no conversion to a smaller base is needed.
* **String conversion** multiplies or divides a private working copy in place, 8 decimal digits at a time.

### Testing

Run `python3 testing/run_test.py`. For every runtime it finds (Lua 5.2, Luau and Luau with native code generation), it runs:

* the unit and property tests in `testing/test.lua`: known values, edge cases around digit boundaries, signs and rounding, error cases, immutability, and algebraic identities such as `(a / b) * b + a % b == a` on random numbers of many sizes;
* thousands of random operations from `testing/random_operations.lua`, checked against Python's integers by `testing/check_operations.py`. This also verifies that every result is normalized.

`test.lua` uses a tiny built-in test runner instead of LuaUnit, so it runs unchanged on Lua 5.2, the Luau CLI (`luau test.lua`) and in Roblox.

### Additional info

- This library aims to replicate the simplicity and elegance of how [Python](https://github.com/python/cpython) handles big integers.
- [Karatsuba's algorithm](https://en.wikipedia.org/wiki/Karatsuba_algorithm) for multiplication is used for numbers with 32 or more digits (about 500 decimal digits), where it beats the schoolbook method. A [Karatsuba-style division](https://www.researchgate.net/publication/2649773_Practical_Integer_Division_with_Karatsuba_Complexity) is not implemented.
- My favourite beer was Guinness (I don't drink anymore)

### Missing Features (Feel free to fork!)

-   The library was built for Roblox games but doesn't yet leverage Roblox's `buffer` library, which could be faster.
-   Division and string conversion are quadratic, so numbers with hundreds of thousands of digits get slow. Subquadratic algorithms (such as Karatsuba division) would fix that.
