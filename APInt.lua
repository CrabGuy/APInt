--!native
--!optimize 2

--[[
	APInt: arbitrary precision integers for Lua 5.2 and Luau (Roblox).

	A number is an immutable array of digits in base 2^52, least significant digit first.
	The sign is stored on the most significant digit: every other digit is in [0, 2^52)
	and the last one is in (-2^52, 2^52). Numbers are always normalized, so the last
	digit is only 0 for zero itself, which is {0}.

	Lua numbers are doubles, which hold every integer below 2^53 exactly. Base 2^52 is
	the largest base where adding two digits and a carry stays below that limit. Products
	of two digits need 104 bits, so multiplication and division split digits into 26-bit
	halves (HALF) whose products are exact, and assemble the full product from those.
]]

local APInt = {}
local APInt_metatable = {}

local math_floor = math.floor
local string_format = string.format
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local getmetatable = getmetatable
local setmetatable = setmetatable
local tonumber = tonumber
local type = type
local warn_user = warn or function(message)
	print("Warning: " .. message)
end

local BASE = 2^52
local HALF = 2^26 -- HALF * HALF == BASE
local SAFE_LIMIT = 2^53 -- every integer with a smaller magnitude is exact as a double

-- String conversion works in chunks of 8 decimal digits. CHUNK * HALF < 2^53 keeps
-- the in-place chunk multiplication and division exact.
local CHUNK = 10^8
local CHUNK_DIGITS = 8
local MAX_SINGLE_DIGIT_LENGTH = 15 -- any 15 digit decimal is below BASE

-- Multiplying numbers with at least this many digits uses Karatsuba's algorithm.
local KARATSUBA_THRESHOLD = 32

APInt.BASE = BASE
APInt.MODE = "NOT-STRICT"

if _VERSION ~= "Lua 5.2" and _VERSION ~= "Luau" then
	warn_user("You are using an unsupported version of Lua for this library. If it's 5.2+, it should still work.")
end

--------------------------------------------------------------------------------
-- Magnitude kernels
--
-- These work on plain arrays of non-negative digits with explicit lengths. Kernels
-- that build a result return a new array together with its length and never modify
-- their inputs. The ones marked "in place" only ever modify private working arrays.
--------------------------------------------------------------------------------

-- Removes zero digits from the top of the n-digit array r, returning its new length.
local function trim(r, n)
	while n > 1 and r[n] == 0 do
		r[n] = nil
		n = n - 1
	end
	return n
end

-- Copies digits first..last of a into a new array.
local function slice(a, first, last)
	local r = {}
	for i = first, last do
		r[i - first + 1] = a[i]
	end
	return r, trim(r, last - first + 1)
end

-- Returns -1, 0 or 1 as |a| is smaller than, equal to or larger than |b|.
local function compare_magnitudes(a, na, b, nb)
	if na ~= nb then
		return na < nb and -1 or 1
	end
	for i = na, 1, -1 do
		local x, y = a[i], b[i]
		if x ~= y then
			return x < y and -1 or 1
		end
	end
	return 0
end

-- |a| + |b|
local function add_magnitudes(a, na, b, nb)
	if na < nb then
		a, na, b, nb = b, nb, a, na
	end
	local r = {}
	local carry = 0
	for i = 1, nb do
		local sum = a[i] + b[i] + carry
		if sum >= BASE then
			r[i] = sum - BASE
			carry = 1
		else
			r[i] = sum
			carry = 0
		end
	end
	for i = nb + 1, na do
		local sum = a[i] + carry
		if sum >= BASE then
			r[i] = sum - BASE
			carry = 1
		else
			r[i] = sum
			carry = 0
		end
	end
	if carry == 0 then
		return r, na
	end
	r[na + 1] = carry
	return r, na + 1
end

-- |a| - |b|, which requires |a| >= |b|.
local function subtract_magnitudes(a, na, b, nb)
	local r = {}
	local borrow = 0
	for i = 1, nb do
		local difference = a[i] - b[i] - borrow
		if difference < 0 then
			r[i] = difference + BASE
			borrow = 1
		else
			r[i] = difference
			borrow = 0
		end
	end
	for i = nb + 1, na do
		local difference = a[i] - borrow
		if difference < 0 then
			r[i] = difference + BASE
			borrow = 1
		else
			r[i] = difference
			borrow = 0
		end
	end
	return r, trim(r, na)
end

-- Adds the n-digit array src into dst starting at dst[offset], in place.
-- dst must be long enough to absorb the final carry.
local function add_into(dst, offset, src, n)
	local carry = 0
	local k = offset
	for i = 1, n do
		local sum = dst[k] + src[i] + carry
		if sum >= BASE then
			dst[k] = sum - BASE
			carry = 1
		else
			dst[k] = sum
			carry = 0
		end
		k = k + 1
	end
	while carry ~= 0 do
		local sum = dst[k] + carry
		if sum >= BASE then
			dst[k] = sum - BASE
		else
			dst[k] = sum
			carry = 0
		end
		k = k + 1
	end
end

-- Returns an array of n zeros.
local function zeros(n)
	local r = {}
	for i = 1, n do
		r[i] = 0
	end
	return r
end

-- |a| * |b| with the schoolbook method. Each digit is split into 26-bit halves so the
-- four partial products stay exact and add up to the full 104-bit digit product.
local function multiply_schoolbook(a, na, b, nb)
	local r = zeros(na + nb)
	for i = 1, na do
		local digit = a[i]
		if digit ~= 0 then
			local a_low = digit % HALF
			local a_high = (digit - a_low) / HALF
			local carry = 0
			local k = i
			for j = 1, nb do
				local other = b[j]
				local b_low = other % HALF
				local b_high = (other - b_low) / HALF
				local middle = a_low * b_high + a_high * b_low
				local middle_low = middle % HALF
				local low = a_low * b_low + middle_low * HALF
				local high = a_high * b_high + (middle - middle_low) / HALF
				-- digit * other == high * BASE + low; fold in r[k] and the carry one at a time
				if low >= BASE then
					low = low - BASE
					high = high + 1
				end
				low = low + r[k]
				if low >= BASE then
					low = low - BASE
					high = high + 1
				end
				low = low + carry
				if low >= BASE then
					low = low - BASE
					high = high + 1
				end
				r[k] = low
				carry = high
				k = k + 1
			end
			r[k] = carry
		end
	end
	return r, trim(r, na + nb)
end

local multiply_magnitudes

-- |a| * |b| with Karatsuba's algorithm, for na >= nb > na / 2. Splitting both numbers
-- at m digits as a = a1 * BASE^m + a0 and b = b1 * BASE^m + b0 gives
-- a * b = z2 * BASE^2m + (z1 - z2 - z0) * BASE^m + z0, with z0 = a0 * b0,
-- z2 = a1 * b1 and z1 = (a0 + a1) * (b0 + b1): three multiplications instead of four.
local function multiply_karatsuba(a, na, b, nb)
	local m = math_floor(na / 2)
	local a0, na0 = slice(a, 1, m)
	local a1, na1 = slice(a, m + 1, na)
	local b0, nb0 = slice(b, 1, m)
	local b1, nb1 = slice(b, m + 1, nb)

	local z0, nz0 = multiply_magnitudes(a0, na0, b0, nb0)
	local z2, nz2 = multiply_magnitudes(a1, na1, b1, nb1)
	local sum_a, nsum_a = add_magnitudes(a0, na0, a1, na1)
	local sum_b, nsum_b = add_magnitudes(b0, nb0, b1, nb1)
	local z1, nz1 = multiply_magnitudes(sum_a, nsum_a, sum_b, nsum_b)
	z1, nz1 = subtract_magnitudes(z1, nz1, z0, nz0)
	z1, nz1 = subtract_magnitudes(z1, nz1, z2, nz2)

	local r = zeros(na + nb)
	for i = 1, nz0 do
		r[i] = z0[i]
	end
	for i = 1, nz2 do
		r[2 * m + i] = z2[i]
	end
	add_into(r, m + 1, z1, nz1)
	return r, trim(r, na + nb)
end

-- |a| * |b| for a much longer than b: multiplies b by each nb-digit block of a.
local function multiply_unbalanced(a, na, b, nb)
	local r = zeros(na + nb)
	for first = 1, na, nb do
		local last = first + nb - 1
		if last > na then
			last = na
		end
		local block, nblock = slice(a, first, last)
		local product, nproduct = multiply_magnitudes(block, nblock, b, nb)
		add_into(r, first, product, nproduct)
	end
	return r, trim(r, na + nb)
end

-- |a| * |b|, picking the fastest method for the sizes involved.
function multiply_magnitudes(a, na, b, nb)
	if na < nb then
		a, na, b, nb = b, nb, a, na
	end
	if nb < KARATSUBA_THRESHOLD then
		return multiply_schoolbook(a, na, b, nb)
	end
	if 2 * nb <= na then
		return multiply_unbalanced(a, na, b, nb)
	end
	return multiply_karatsuba(a, na, b, nb)
end

-- Subtracts multiplier * v (nv digits, multiplier < BASE) from w[offset .. offset + nv]
-- in place. The top digit w[offset + nv] goes negative if the result is negative.
local function subtract_multiple(w, offset, v, nv, multiplier)
	local m_low = multiplier % HALF
	local m_high = (multiplier - m_low) / HALF
	local borrow = 0
	local k = offset
	for i = 1, nv do
		local digit = v[i]
		local v_low = digit % HALF
		local v_high = (digit - v_low) / HALF
		local middle = m_low * v_high + m_high * v_low
		local middle_low = middle % HALF
		local low = m_low * v_low + middle_low * HALF
		local high = m_high * v_high + (middle - middle_low) / HALF
		if low >= BASE then
			low = low - BASE
			high = high + 1
		end
		local difference = w[k] - low - borrow
		local result = difference % BASE
		w[k] = result
		borrow = high + (result - difference) / BASE
		k = k + 1
	end
	w[k] = w[k] - borrow
end

-- Adds v (nv digits) to w[offset .. offset + nv] in place.
local function add_back(w, offset, v, nv)
	local carry = 0
	local k = offset
	for i = 1, nv do
		local sum = w[k] + v[i] + carry
		if sum >= BASE then
			w[k] = sum - BASE
			carry = 1
		else
			w[k] = sum
			carry = 0
		end
		k = k + 1
	end
	w[k] = w[k] + carry
end

-- Whether the window w[offset .. offset + nv] is smaller than v (nv digits).
local function window_less_than(w, offset, v, nv)
	local top = w[offset + nv]
	if top ~= 0 then
		return top < 0
	end
	for i = nv, 1, -1 do
		local x, y = w[offset + i - 1], v[i]
		if x ~= y then
			return x < y
		end
	end
	return false
end

-- Long division of |u| by |v| (v nonzero). Returns quotient, its length, remainder, its length.
--
-- This is schoolbook long division with one base 2^52 digit of quotient per step. Each
-- quotient digit is estimated with floating point division of the leading digits, which
-- is off by at most a few units, and then corrected exactly: added back while the partial
-- remainder is negative, and subtracted again while it is still at least v.
local function divide_magnitudes(u, nu, v, nv)
	if nu < nv then
		local r, nr = slice(u, 1, nu)
		return { 0 }, 1, r, nr
	end

	-- w holds the running remainder; one extra zero digit on top keeps every window nv + 1 long
	local w = slice(u, 1, nu)
	w[nu + 1] = 0
	local divisor = v[nv] + (nv > 1 and v[nv - 1] / BASE or 0)
	local q = {}

	for j = nu - nv + 1, 1, -1 do
		local top = j + nv
		local estimate = math_floor((w[top] * BASE + w[top - 1]) / divisor)
		if estimate >= BASE then
			estimate = BASE - 1
		end
		if estimate > 0 then
			subtract_multiple(w, j, v, nv, estimate)
		end
		while w[top] < 0 do
			add_back(w, j, v, nv)
			estimate = estimate - 1
		end
		while not window_less_than(w, j, v, nv) do
			subtract_multiple(w, j, v, nv, 1)
			estimate = estimate + 1
		end
		q[j] = estimate
	end

	local r, nr = slice(w, 1, nv)
	return q, trim(q, nu - nv + 1), r, nr
end

-- Divides the n-digit array digits by divisor (< 2^27) in place and returns the remainder.
-- Each digit is processed as two 26-bit halves so every intermediate value stays exact.
local function divide_small_in_place(digits, n, divisor)
	local remainder = 0
	for i = n, 1, -1 do
		local digit = digits[i]
		local low = digit % HALF
		local high_part = remainder * HALF + (digit - low) / HALF
		local high_remainder = high_part % divisor
		local low_part = high_remainder * HALF + low
		remainder = low_part % divisor
		digits[i] = (high_part - high_remainder) / divisor * HALF + (low_part - remainder) / divisor
	end
	return remainder
end

-- Sets the n-digit array digits to digits * multiplier + addend in place, where
-- multiplier and addend are below 2^27, and returns the new length.
local function multiply_add_small_in_place(digits, n, multiplier, addend)
	local carry = addend
	for i = 1, n do
		local digit = digits[i]
		local low = digit % HALF
		local low_part = low * multiplier + carry
		local low_digit = low_part % HALF
		local high_part = (digit - low) / HALF * multiplier + (low_part - low_digit) / HALF
		local high_digit = high_part % HALF
		digits[i] = high_digit * HALF + low_digit
		carry = (high_part - high_digit) / HALF
	end
	if carry > 0 then
		n = n + 1
		digits[n] = carry
	end
	return n
end

--------------------------------------------------------------------------------
-- Building APInt values
--------------------------------------------------------------------------------

-- Numbers are immutable, so small values are created once and shared.
local SMALL_MIN, SMALL_MAX = -5, 256
local SMALL_INTEGERS = {}
for i = SMALL_MIN, SMALL_MAX do
	SMALL_INTEGERS[i] = setmetatable({ i }, APInt_metatable)
end
local ZERO = SMALL_INTEGERS[0]
local ONE_DIGITS = { 1 }

local function is_apint(x)
	return getmetatable(x) == APInt_metatable
end

-- Wraps a single digit (|value| < BASE) as an APInt.
local function from_digit(value)
	if value == 0 then
		return ZERO -- also turns -0 into 0
	end
	if SMALL_MIN <= value and value <= SMALL_MAX then
		return SMALL_INTEGERS[value]
	end
	return setmetatable({ value }, APInt_metatable)
end

-- Wraps an integer with |value| < 2^53, which may need a second digit.
local function from_small_integer(value)
	if -BASE < value and value < BASE then
		return from_digit(value)
	end
	local size = value < 0 and -value or value
	local low = size % BASE
	local high = (size - low) / BASE
	return setmetatable({ low, value < 0 and -high or high }, APInt_metatable)
end

-- Turns a new, trimmed n-digit magnitude array into an APInt with the given sign.
local function from_magnitude(r, n, negative)
	if n == 1 then
		return from_digit(negative and -r[1] or r[1])
	end
	if negative then
		r[n] = -r[n]
	end
	return setmetatable(r, APInt_metatable)
end

-- Copies the digits of x (n digits) without the sign.
local function copy_magnitude(x, n)
	local r = {}
	for i = 1, n - 1 do
		r[i] = x[i]
	end
	local top = x[n]
	r[n] = top < 0 and -top or top
	return r
end

-- The digits of |x|: x itself when it is not negative, a copy otherwise.
local function magnitude(x, n)
	if x[n] >= 0 then
		return x
	end
	return copy_magnitude(x, n)
end

local function is_zero(r, n)
	return n == 1 and r[1] == 0
end

--------------------------------------------------------------------------------
-- Arithmetic
--------------------------------------------------------------------------------

local function negate(x)
	local n = #x
	if n == 1 then
		return from_digit(-x[1])
	end
	local r = {}
	for i = 1, n - 1 do
		r[i] = x[i]
	end
	r[n] = -x[n]
	return setmetatable(r, APInt_metatable)
end

-- a + b, where b_negative gives the sign to use for b (subtraction passes the flipped sign).
local function add_with_sign(a, na, b, nb, b_negative)
	local a_negative = a[na] < 0
	local a_digits, b_digits = magnitude(a, na), magnitude(b, nb)
	if a_negative == b_negative then
		local r, nr = add_magnitudes(a_digits, na, b_digits, nb)
		return from_magnitude(r, nr, a_negative)
	end

	local order = compare_magnitudes(a_digits, na, b_digits, nb)
	if order == 0 then
		return ZERO
	elseif order > 0 then
		local r, nr = subtract_magnitudes(a_digits, na, b_digits, nb)
		return from_magnitude(r, nr, a_negative)
	end
	local r, nr = subtract_magnitudes(b_digits, nb, a_digits, na)
	return from_magnitude(r, nr, b_negative)
end

local function add(a, b)
	local na, nb = #a, #b
	if na == 1 and nb == 1 then
		return from_small_integer(a[1] + b[1])
	end
	return add_with_sign(a, na, b, nb, b[nb] < 0)
end

local function subtract(a, b)
	local na, nb = #a, #b
	if na == 1 and nb == 1 then
		return from_small_integer(a[1] - b[1])
	end
	return add_with_sign(a, na, b, nb, b[nb] > 0)
end

local function multiply(a, b)
	local na, nb = #a, #b
	if na == 1 and nb == 1 then
		local product = a[1] * b[1]
		if -SAFE_LIMIT < product and product < SAFE_LIMIT then
			return from_small_integer(product)
		end
	end

	local negative = (a[na] < 0) ~= (b[nb] < 0)
	local r, nr = multiply_magnitudes(magnitude(a, na), na, magnitude(b, nb), nb)
	return from_magnitude(r, nr, negative)
end

-- Floor division, like Python and Lua's own // and %: returns q and r with
-- a == q * b + r, where q is rounded down and r has the sign of b.
local function divide_with_remainder(a, b)
	local na, nb = #a, #b
	local b_top = b[nb]
	if nb == 1 then
		if b_top == 0 then
			error("Division by zero")
		end
		if na == 1 then
			-- with both values below 2^52 the float quotient rounds to the exact floor
			local x = a[1]
			local q = math_floor(x / b_top)
			return from_digit(q), from_digit(x - q * b_top)
		end
	end

	local a_negative, b_negative = a[na] < 0, b_top < 0
	local b_digits = magnitude(b, nb)
	local q, nq, r, nr = divide_magnitudes(magnitude(a, na), na, b_digits, nb)
	if a_negative ~= b_negative and not is_zero(r, nr) then
		q, nq = add_magnitudes(q, nq, ONE_DIGITS, 1)
		r, nr = subtract_magnitudes(b_digits, nb, r, nr)
	end
	return from_magnitude(q, nq, a_negative ~= b_negative), from_magnitude(r, nr, b_negative)
end

local function divide(a, b)
	return (divide_with_remainder(a, b))
end

local function modulo(a, b)
	local _, r = divide_with_remainder(a, b)
	return r
end

-- base ^ exponent for 0 <= exponent < BASE, by binary exponentiation from the top bit down.
local function power_by_digit(base, exponent)
	if exponent == 0 then
		return SMALL_INTEGERS[1]
	end
	local bit = 1
	while bit * 2 <= exponent do
		bit = bit * 2
	end
	local remaining = exponent - bit
	local result = base
	while bit > 1 do
		bit = bit / 2
		result = multiply(result, result)
		if remaining >= bit then
			remaining = remaining - bit
			result = multiply(result, base)
		end
	end
	return result
end

-- base ^ exponent. Negative exponents round down like 1 / base^|exponent| would.
local function power(base, exponent)
	local n = #exponent
	local exponent_negative = exponent[n] < 0
	local odd = exponent[1] % 2 == 1

	if #base == 1 then
		local x = base[1]
		if x == 0 then
			if exponent_negative then
				error("Negative power of zero")
			end
			return is_zero(exponent, n) and SMALL_INTEGERS[1] or ZERO
		elseif x == 1 or (x == -1 and not odd) then
			return SMALL_INTEGERS[1]
		elseif x == -1 then
			return base
		end
	end

	if exponent_negative then
		return (base[#base] < 0 and odd) and SMALL_INTEGERS[-1] or ZERO
	end
	if n > 1 then
		error("Exponent is too large")
	end
	return power_by_digit(base, exponent[1])
end

--------------------------------------------------------------------------------
-- Comparison
--------------------------------------------------------------------------------

local function equal(a, b)
	local n = #a
	if n ~= #b then
		return false
	end
	for i = 1, n do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Returns -1, 0 or 1 as a is smaller than, equal to or larger than b.
local function compare(a, b)
	local na, nb = #a, #b
	local a_top, b_top = a[na], b[nb]
	local a_negative = a_top < 0
	if a_negative ~= (b_top < 0) then
		return a_negative and -1 or 1
	end
	-- both have the same sign; for negative numbers the larger magnitude is the smaller number
	local larger = a_negative and -1 or 1
	if na ~= nb then
		return na < nb and -larger or larger
	end
	if a_top ~= b_top then
		return a_top < b_top and -1 or 1 -- the signed top digits already compare correctly
	end
	for i = na - 1, 1, -1 do
		local x, y = a[i], b[i]
		if x ~= y then
			return x < y and -larger or larger
		end
	end
	return 0
end

local function less_than(a, b)
	return compare(a, b) < 0
end

local function less_or_equal(a, b)
	return compare(a, b) <= 0
end

--------------------------------------------------------------------------------
-- Conversion
--------------------------------------------------------------------------------

local function to_string(x)
	local n = #x
	local top = x[n]
	if n == 1 then
		return string_format("%.0f", top)
	end

	-- repeatedly divide a scratch copy by 10^8, collecting 8 decimal digits at a time
	local work = copy_magnitude(x, n)
	local chunks = {}
	local count = 0
	repeat
		count = count + 1
		chunks[count] = divide_small_in_place(work, n, CHUNK)
		while n > 1 and work[n] == 0 do
			n = n - 1
		end
	until n == 1 and work[1] == 0

	local parts = { (top < 0 and "-" or "") .. string_format("%.0f", chunks[count]) }
	for i = count - 1, 1, -1 do
		parts[count - i + 1] = string_format("%08.0f", chunks[i])
	end
	return table_concat(parts)
end

local function from_string(s)
	local sign, digits = string_match(s, "^(%-?)(%d+)$")
	assert(digits, "Invalid number string format")
	local negative = sign == "-"
	local length = #digits
	if length <= MAX_SINGLE_DIGIT_LENGTH then
		local value = tonumber(digits)
		return from_digit(negative and -value or value)
	end

	-- Horner's method in chunks of 8 decimal digits, on a private array
	local first = (length - 1) % CHUNK_DIGITS + 1
	local work = { tonumber(string_sub(digits, 1, first)) }
	local n = 1
	for position = first + 1, length, CHUNK_DIGITS do
		local chunk = tonumber(string_sub(digits, position, position + CHUNK_DIGITS - 1))
		n = multiply_add_small_in_place(work, n, CHUNK, chunk)
	end
	return from_magnitude(work, n, negative)
end

local function from_number(x)
	assert(x % 1 == 0, "The number passed must be a whole number")
	assert(-SAFE_LIMIT < x and x < SAFE_LIMIT, "Number is too large to be exact, pass it as a string instead")
	return from_small_integer(x)
end

-- Builds an APInt from a digit table in the internal format (copying it).
local function from_digit_table(t)
	local n = #t
	assert(n > 0, "Digit table must not be empty")
	for i = 1, n do
		local digit = t[i]
		assert(type(digit) == "number" and digit % 1 == 0, "Digits must be whole numbers")
		if i < n then
			assert(0 <= digit and digit < BASE, "Elements of digits table are out of range")
		else
			assert(-BASE < digit and digit < BASE, "Last element of digits table is out of range")
		end
	end
	local r = copy_magnitude(t, n)
	return from_magnitude(r, trim(r, n), t[n] < 0)
end

--------------------------------------------------------------------------------
-- Public interface
--------------------------------------------------------------------------------

function APInt.new(x, sign)
	assert(sign == nil or sign == 1 or sign == -1, "Sign must be 1 or -1")
	local result
	if is_apint(x) then
		result = x
	elseif type(x) == "number" then
		result = from_number(x)
	elseif type(x) == "string" then
		assert(sign == nil, "Cannot provide a sign argument when creating from a string")
		result = from_string(x)
	elseif type(x) == "table" then
		result = from_digit_table(x)
	else
		error("Argument of new must be an integer, string, or a APInt table representation", 2)
	end

	if sign and (result[#result] < 0) ~= (sign < 0) then
		return negate(result)
	end
	return result
end

function APInt.from_string(s)
	assert(type(s) == "string", "Argument to from_string must be a string")
	return from_string(s)
end

-- Formats a number or digit table as "[d1, d2, ...]", showing the internal digits.
function APInt.format(x)
	if type(x) == "number" then
		return string_format("%.0f", x)
	end
	assert(type(x) == "table", "Invalid argument passed to format")
	local parts = {}
	for i = 1, #x do
		assert(type(x[i]) == "number", "Trying to format an invalid table")
		parts[i] = string_format("%.0f", x[i])
	end
	return "[" .. table_concat(parts, ", ") .. "]"
end

function APInt.table_print(x)
	print(APInt.format(x))
end

APInt.__is_big_int = is_apint

-- Converts an operand that is not an APInt, according to APInt.MODE.
local function coerce(value)
	if APInt.MODE == "STRICT" then
		error("Argument for operation was not APInt")
	elseif APInt.MODE == "WARNING" then
		warn_user("Argument for operation was not a APInt, converted")
	end
	return APInt.new(value)
end

-- Wraps a two-operand function so it accepts anything APInt.new does.
local function binary_operator(operation)
	return function(a, b)
		if getmetatable(a) ~= APInt_metatable then
			a = coerce(a)
		end
		if getmetatable(b) ~= APInt_metatable then
			b = coerce(b)
		end
		return operation(a, b)
	end
end

APInt_metatable.__index = APInt
APInt_metatable.__add = binary_operator(add)
APInt_metatable.__sub = binary_operator(subtract)
APInt_metatable.__mul = binary_operator(multiply)
APInt_metatable.__div = binary_operator(divide)
APInt_metatable.__idiv = APInt_metatable.__div -- Luau's // operator
APInt_metatable.__mod = binary_operator(modulo)
APInt_metatable.__pow = binary_operator(power)
APInt_metatable.__lt = binary_operator(less_than)
APInt_metatable.__le = binary_operator(less_or_equal)
APInt_metatable.__unm = negate
APInt_metatable.__tostring = to_string
APInt_metatable.__eq = function(a, b)
	-- Luau also calls __eq when only one side is an APInt
	return is_apint(a) and is_apint(b) and equal(a, b)
end

setmetatable(APInt, {
	__call = function(_, x, sign)
		return APInt.new(x, sign)
	end,
})

return APInt
