--!native

local APInt = {}
local APInt_metatable = {}
APInt.__index = APInt

local math_abs = math.abs
local math_floor = math.floor
local math_log10 = math.log10
local math_max = math.max
local table_insert = table.insert
local table_concat = table.concat
local string_format = string.format
local string_sub = string.sub
local string_match = string.match
local tonumber = tonumber
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local unpack = unpack or table.unpack

local POWER = 52
local BASE = 2^POWER
local SPLIT_BASE = 2^(POWER / 2)
APInt.BASE = BASE
APInt.MODE = "NOT-STRICT"
local PRELOADED = {}

for i = -5, 256 do
	PRELOADED[i] = setmetatable({ i }, APInt_metatable)
end

local supported_versions = { "Lua 5.2", "Luau" }
local supported = false
for _, version in pairs(supported_versions) do
	if version == _VERSION then
		supported = true
		break
	end
end
if not supported then
	warn("You are using an unsupported version of Lua for this library. If it's 5.2+, it should still work.")
end

assert(POWER % 2 == 0, "POWER must be an even number for multiplication to work properly")

local TOSTRING_DIVISOR_DIGITS = math_floor(math_log10(BASE))
local TOSTRING_DIVISOR = nil
local PADDING_FORMAT = "%0" .. TOSTRING_DIVISOR_DIGITS .. ".0f"

local function __remove_trailing_zeros(digits)
	local n = #digits
	while n > 1 and digits[n] == 0 do
		n = n - 1
	end
	if n == #digits then
		return digits
	end
	local new_digits = {}
	for i = 1, n do
		new_digits[i] = digits[i]
	end
	return new_digits
end

local function __sign(x)
	return (x[#x] >= 0 and 1) or -1
end

local function __abs_mag(x)
	local t = {}
	for i = 1, #x do
		t[i] = math_abs(x[i])
	end
	return t
end

local function __from_mag(mag, sign)
	mag = __remove_trailing_zeros(mag)
	if mag[#mag] == 0 then
		sign = 1
	end
	if sign == -1 then
		mag[#mag] = -mag[#mag]
	end
	return setmetatable(mag, APInt_metatable)
end

local function mag_add(a, b)
	local max_len = math_max(#a, #b)
	local digits = {}
	local carry = 0
	for i = 1, max_len do
		local sum = (a[i] or 0) + (b[i] or 0) + carry
		if sum >= BASE then
			digits[i] = sum - BASE
			carry = 1
		else
			digits[i] = sum
			carry = 0
		end
	end
	if carry ~= 0 then
		digits[max_len + 1] = carry
	end
	return digits
end

local function mag_sub(a, b)
	local digits = {}
	local borrow = 0
	for i = 1, #a do
		local sub = a[i] - (b[i] or 0) - borrow
		if sub < 0 then
			sub = sub + BASE
			borrow = 1
		else
			borrow = 0
		end
		digits[i] = sub
	end
	return digits
end

local function mag_lt(a, b)
	if #a ~= #b then
		return #a < #b
	end
	for i = #a, 1, -1 do
		if a[i] ~= b[i] then
			return a[i] < b[i]
		end
	end
	return false
end

local function mag_eq(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function to_base26(a)
	local res = {}
	for i = 1, #a do
		local d = a[i]
		local high = math_floor(d / SPLIT_BASE)
		local low = d % SPLIT_BASE
		table_insert(res, low)
		table_insert(res, high)
	end
	return __remove_trailing_zeros(res)
end

local function from_base26(a)
	local res = {}
	for i = 1, #a, 2 do
		local low = a[i] or 0
		local high = a[i + 1] or 0
		table_insert(res, high * SPLIT_BASE + low)
	end
	return __remove_trailing_zeros(res)
end

local BASE_26 = SPLIT_BASE

local function mag_mul_base26(a, b)
	local result = {}
	for i = 1, #a do
		local carry = 0
		for j = 1, #b do
			local pos = i + j - 1
			local cur = (result[pos] or 0) + a[i] * b[j] + carry
			result[pos] = cur % BASE_26
			carry = math_floor(cur / BASE_26)
		end
		local pos = i + #b
		while carry > 0 do
			local cur = (result[pos] or 0) + carry
			result[pos] = cur % BASE_26
			carry = math_floor(cur / BASE_26)
			pos = pos + 1
		end
	end
	return __remove_trailing_zeros(result)
end

local function mag_mul(a, b)
	local a26 = to_base26(a)
	local b26 = to_base26(b)
	local prod26 = mag_mul_base26(a26, b26)
	return from_base26(prod26)
end

local function mag_div_small_2(a)
	local q = {}
	local rem = 0
	for i = #a, 1, -1 do
		local cur = rem * BASE + a[i]
		q[i] = math_floor(cur / 2)
		rem = cur % 2
	end
	return __remove_trailing_zeros(q), { rem }
end

local function mag_div_small_base26(a, d)
	local q = {}
	local r = 0
	for i = #a, 1, -1 do
		local cur = r * BASE_26 + a[i]
		q[i] = math_floor(cur / d)
		r = cur % d
	end
	return __remove_trailing_zeros(q), { r }
end

local function mag_div_base26(a, b)
	if #b == 1 then
		return mag_div_small_base26(a, b[1])
	end

	local u = {}
	for i = #a, 1, -1 do
		u[#u + 1] = a[i]
	end

	local v = {}
	for i = #b, 1, -1 do
		v[#v + 1] = b[i]
	end

	if #u < #v then
		return { 0 }, a
	end

	local n = #v
	local d = math_floor(BASE_26 / (v[1] + 1))

	local u_norm = {}
	local carry = 0
	for i = #u, 1, -1 do
		local val = u[i] * d + carry
		u_norm[i] = val % BASE_26
		carry = math_floor(val / BASE_26)
	end
	if carry > 0 then
		table_insert(u_norm, 1, carry)
	end

	local v_norm = {}
	carry = 0
	for i = #v, 1, -1 do
		local val = v[i] * d + carry
		v_norm[i] = val % BASE_26
		carry = math_floor(val / BASE_26)
	end
	if carry > 0 then
		table_insert(v_norm, 1, carry)
	end

	table_insert(u_norm, 1, 0)
	n = #v_norm
	local m = #u_norm - n - 1
	local q = {}

	for j = 1, m + 1 do
		local uj = u_norm[j] or 0
		local uj1 = u_norm[j + 1] or 0
		local qhat = math_floor((uj * BASE_26 + uj1) / v_norm[1])
		local rhat = (uj * BASE_26 + uj1) % v_norm[1]

		while qhat >= BASE_26 or (n > 1 and qhat * v_norm[2] > BASE_26 * rhat + (u_norm[j + 2] or 0)) do
			qhat = qhat - 1
			rhat = rhat + v_norm[1]
			if rhat >= BASE_26 then
				break
			end
		end

		local borrow = 0
		for i = n, 1, -1 do
			local p = qhat * v_norm[i] + borrow
			local sub = (u_norm[j + i] or 0) - (p % BASE_26)
			if sub < 0 then
				u_norm[j + i] = sub + BASE_26
				borrow = math_floor(p / BASE_26) + 1
			else
				u_norm[j + i] = sub
				borrow = math_floor(p / BASE_26)
			end
		end

		local total = (u_norm[j] or 0) - borrow
		if total < 0 then
			qhat = qhat - 1
			local carry_add = 0
			for i = n, 1, -1 do
				local sum = (u_norm[j + i] or 0) + v_norm[i] + carry_add
				u_norm[j + i] = sum % BASE_26
				carry_add = math_floor(sum / BASE_26)
			end
			u_norm[j] = ((u_norm[j] or 0) + carry_add) % BASE_26
		else
			u_norm[j] = total
		end

		q[j] = qhat
	end

	local q_little = {}
	for i = #q, 1, -1 do
		q_little[#q_little + 1] = q[i]
	end

	local rem_big = {}
	for i = m + 2, m + n + 1 do
		rem_big[#rem_big + 1] = u_norm[i]
	end

	local rem_little = {}
	for i = #rem_big, 1, -1 do
		rem_little[#rem_little + 1] = rem_big[i]
	end

	local rem_norm = __remove_trailing_zeros(rem_little)
	local remainder, _ = mag_div_small_base26(rem_norm, d)

	return __remove_trailing_zeros(q_little), remainder
end

local function mag_div(a, b)
	local a26 = to_base26(a)
	local b26 = to_base26(b)
	local q26, r26 = mag_div_base26(a26, b26)
	return from_base26(q26), from_base26(r26)
end

function APInt.__is_big_int(x)
	return type(x) == "table" and getmetatable(x) == APInt_metatable
end

local function typecheck(f)
	return function(...)
		local arguments = { ... }
		for i, v in ipairs(arguments) do
			if not APInt.__is_big_int(v) then
				if APInt.MODE == "STRICT" then
					error("Argument for operation was not APInt")
				else
					if APInt.MODE == "WARNING" then
						warn("Argument for operation was not a APInt, converted")
					end
					arguments[i] = APInt.new(v)
				end
			end
		end
		return f(unpack(arguments))
	end
end

function APInt.new(x, sign)
	if APInt.__is_big_int(x) then
		if sign and __sign(x) ~= sign then
			return -x
		end
		return x
	end

	if type(x) == "string" then
		assert(sign == nil, "Cannot provide a sign argument when creating from a string")
		return APInt.from_string(x)
	end

	if type(x) == "number" then
		if PRELOADED[x] then
			return PRELOADED[x]
		end
		assert(x % 1 == 0, "The number passed must be a whole number")
		assert((-BASE < x) and (x < BASE), "Number is out of single-digit range")
		local digits = { x }
		if sign then
			digits[#digits] = math_abs(digits[#digits]) * sign
		end
		return setmetatable(digits, APInt_metatable)
	end

	assert(type(x) == "number" or type(x) == "table", "Argument of new must be an integer, string, or a APInt table representation")

	local digits
	if type(x) == "table" then
		local last = x[#x]
		if last then
			assert(type(last) == "number" and -BASE < last and last < BASE, "Last element of digits table is out of range")
		end
		for i = 1, #x - 1 do
			local v = x[i]
			assert(type(v) == "number" and 0 <= v and v < BASE, "Elements of digits table are out of range")
		end
		digits = __remove_trailing_zeros(x)
	end

	if sign and digits[#digits] then
		digits[#digits] = math_abs(digits[#digits]) * sign
	end

	return setmetatable(digits, APInt_metatable)
end

local function __abs(x)
	return __from_mag(__abs_mag(x), 1)
end

local function __unm(x)
	if x[#x] == 0 then
		return PRELOADED[0]
	end
	return __from_mag(__abs_mag(x), -__sign(x))
end

local function __add(a, b)
	local sign_a = __sign(a)
	local sign_b = __sign(b)
	local mag_a = __abs_mag(a)
	local mag_b = __abs_mag(b)

	if sign_a == sign_b then
		return __from_mag(mag_add(mag_a, mag_b), sign_a)
	else
		if mag_eq(mag_a, mag_b) then
			return PRELOADED[0]
		end
		if mag_lt(mag_a, mag_b) then
			return __from_mag(mag_sub(mag_b, mag_a), sign_b)
		else
			return __from_mag(mag_sub(mag_a, mag_b), sign_a)
		end
	end
end

local function __sub(a, b)
	return __add(a, __unm(b))
end

local function __mul(a, b)
	if a == PRELOADED[0] or b == PRELOADED[0] then
		return PRELOADED[0]
	end

	local sign = __sign(a) * __sign(b)
	local mag = mag_mul(__abs_mag(a), __abs_mag(b))
	return __from_mag(mag, sign)
end

local function __div(a, b)
	assert(b ~= PRELOADED[0], "Division by 0")
	local sign_q = __sign(a) * __sign(b)
	local q_mag, r_mag = mag_div(__abs_mag(a), __abs_mag(b))
	local q = __from_mag(q_mag, sign_q)
	local r = __from_mag(r_mag, 1)
	return q, r
end

local function __mod(a, b)
	assert(b ~= PRELOADED[0], "Modulo by 0")
	local _, r = __div(a, b)
	if __sign(a) == -1 and r ~= PRELOADED[0] then
		r = __sub(__abs(b), r)
	end
	return r
end

local function div_small_2_apint(x)
	local q_mag, r_mag = mag_div_small_2(__abs_mag(x))
	return __from_mag(q_mag, 1), __from_mag(r_mag, 1)
end

local function __pow(a, b)
	if b < PRELOADED[0] then
		assert(a ~= PRELOADED[0], "Negative power of 0")
		if a == PRELOADED[1] then
			return PRELOADED[1]
		end
		return PRELOADED[0]
	end

	if b == PRELOADED[0] then
		return PRELOADED[1]
	end

	local result = PRELOADED[1]
	local base = a
	local exp = b

	while exp > PRELOADED[0] do
		local q, r = div_small_2_apint(exp)
		if r == PRELOADED[1] then
			result = __mul(result, base)
		end
		base = __mul(base, base)
		exp = q
	end

	return result
end

local function __eq(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if __sign(a) ~= __sign(b) then
		return false
	end
	return mag_eq(__abs_mag(a), __abs_mag(b))
end

local function __lt(a, b)
	local sign_a = __sign(a)
	local sign_b = __sign(b)

	if sign_a ~= sign_b then
		return sign_a < sign_b
	end

	local mag_a = __abs_mag(a)
	local mag_b = __abs_mag(b)

	if sign_a == 1 then
		return mag_lt(mag_a, mag_b)
	else
		return mag_lt(mag_b, mag_a)
	end
end

local function __tostring(x)
	if not TOSTRING_DIVISOR then
		TOSTRING_DIVISOR = APInt.new(10 ^ TOSTRING_DIVISOR_DIGITS)
	end

	if __eq(x, PRELOADED[0]) then
		return "0"
	end

	local work_val = __abs(x)
	local sign = (__sign(x) == -1) and "-" or ""
	local parts = {}

	while work_val > PRELOADED[0] do
		local quotient, remainder = __div(work_val, TOSTRING_DIVISOR)
		local remainder_val = (remainder[1] or 0)
		table_insert(parts, 1, remainder_val)
		work_val = quotient
	end

	local first = parts[1]
	local str = sign .. first
	for i = 2, #parts do
		str = str .. string_format(PADDING_FORMAT, parts[i])
	end

	return str
end

function APInt.from_string(s)
	assert(type(s) == "string", "Argument to from_string must be a string")

	local sign = 1
	if string_sub(s, 1, 1) == "-" then
		sign = -1
		s = string_sub(s, 2)
	end

	assert(string_match(s, "^[0-9]+$"), "Invalid number string format")

	if not TOSTRING_DIVISOR then
		TOSTRING_DIVISOR = APInt.new(10 ^ TOSTRING_DIVISOR_DIGITS)
	end

	local result = PRELOADED[0]
	local len = #s
	local first_chunk_len = len % TOSTRING_DIVISOR_DIGITS
	if first_chunk_len == 0 and len > 0 then
		first_chunk_len = TOSTRING_DIVISOR_DIGITS
	end

	local current_pos = 1
	if first_chunk_len > 0 then
		local first_chunk_str = string_sub(s, 1, first_chunk_len)
		result = APInt.new(tonumber(first_chunk_str))
		current_pos = first_chunk_len + 1
	end

	while current_pos <= len do
		local chunk_str = string_sub(s, current_pos, current_pos + TOSTRING_DIVISOR_DIGITS - 1)
		result = result * TOSTRING_DIVISOR + APInt.new(tonumber(chunk_str))
		current_pos = current_pos + TOSTRING_DIVISOR_DIGITS
	end

	return sign == -1 and -result or result
end

function APInt.format(x)
	local is_number = type(x) == "number"
	if is_number then
		return string_format("%.f", x)
	end

	if type(x) == "table" and not APInt.__is_big_int(x) then
		for _, v in pairs(x) do
			assert(type(v) == "number", "Trying to format an invalid table")
		end
	end

	assert(type(x) == "number" or type(x) == "table", "Invalid argument passed to format")

	local digits = {}
	for i, v in ipairs(x) do
		digits[i] = string_format("%.f", v)
	end

	return string.format("[%s]", table_concat(digits, ", "))
end

function APInt.table_print(x)
	print(APInt.format(x))
end

APInt_metatable.__index = APInt
APInt_metatable.__add = typecheck(__add)
APInt_metatable.__sub = typecheck(__sub)
APInt_metatable.__mod = typecheck(__mod)
APInt_metatable.__div = typecheck(__div)
APInt_metatable.__mul = typecheck(__mul)
APInt_metatable.__pow = typecheck(__pow)
APInt_metatable.__tostring = __tostring
APInt_metatable.__unm = typecheck(__unm)
APInt_metatable.__lt = typecheck(__lt)
APInt_metatable.__eq = __eq

local call_proxy = {
	__call = function(_, x, sign)
		return APInt.new(x, sign)
	end
}
setmetatable(APInt, call_proxy)

return APInt