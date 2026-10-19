"""Checks the output of random_operations.lua against Python's arbitrary precision integers.

Usage:
    python3 check_operations.py operations.txt
    lua5.2 random_operations.lua 42 1000 | python3 check_operations.py

Besides the value of every result, it checks that results are normalized: every digit
but the last in [0, 2^52), the last in (-2^52, 2^52) and only zero for the number zero.
"""

import math
import sys
from fractions import Fraction

BASE = 2**52


def parse_digits(text):
    """Decodes "[d1,d2,...]" into an int, raising ValueError if it is not normalized."""
    if not (text.startswith("[") and text.endswith("]")):
        raise ValueError(f"not a digit table: {text}")
    parts = text[1:-1].split(",")
    if any(part == "-0" for part in parts):
        raise ValueError(f"negative zero digit: {text}")
    digits = [int(part) for part in parts]
    *lower, top = digits
    if not all(0 <= digit < BASE for digit in lower):
        raise ValueError(f"digit out of range: {text}")
    if not -BASE < top < BASE:
        raise ValueError(f"top digit out of range: {text}")
    if top == 0 and lower:
        raise ValueError(f"leading zero digit: {text}")
    magnitude = sum(digit * BASE**i for i, digit in enumerate(lower)) + abs(top) * BASE ** len(lower)
    return -magnitude if top < 0 else magnitude


def power(base, exponent):
    """base ** exponent, rounding negative exponents down like 1 // base**-exponent."""
    if exponent >= 0:
        return base**exponent
    return math.floor(Fraction(1, base**-exponent))


BINARY = {
    "add": lambda a, b: a + b,
    "sub": lambda a, b: a - b,
    "mul": lambda a, b: a * b,
    "div": lambda a, b: a // b,
    "mod": lambda a, b: a % b,
    "pow": power,
}

COMPARISONS = {
    "lt": lambda a, b: a < b,
    "le": lambda a, b: a <= b,
    "eq": lambda a, b: a == b,
}


def check_line(line):
    """Returns None if the line is correct, or a description of the problem."""
    op, *fields = line.split()
    if op in BINARY:
        a, b, result = fields
        expected = BINARY[op](parse_digits(a), parse_digits(b))
        actual = parse_digits(result)
    elif op in COMPARISONS:
        a, b, result = fields
        expected = COMPARISONS[op](parse_digits(a), parse_digits(b))
        actual = {"true": True, "false": False}[result]
    elif op == "addnum":
        a, number, result = fields
        expected = parse_digits(a) + int(number)
        actual = parse_digits(result)
    elif op == "unm":
        a, result = fields
        expected = -parse_digits(a)
        actual = parse_digits(result)
    elif op == "tostring":
        a, result = fields
        expected = str(parse_digits(a))
        actual = result
    elif op == "parse":
        decimal, result = fields
        expected = int(decimal)
        actual = parse_digits(result)
    else:
        return f"unknown operation {op!r}"
    if expected != actual:
        return f"expected {expected}, got {actual}"
    return None


def check_operations(lines):
    """Checks every line and returns the number of failures."""
    failures = 0
    checked = 0
    for line_number, line in enumerate(lines, 1):
        line = line.strip()
        if not line:
            continue
        checked += 1
        try:
            problem = check_line(line)
        except (ValueError, KeyError) as error:
            problem = f"malformed result ({error})"
        if problem:
            failures += 1
            if failures <= 10:
                print(f"Error on line {line_number}: {line[:300]}")
                print(f"  {problem[:300]}")
    if checked == 0:
        print("No operations to check.")
        return 1
    if failures:
        print(f"{failures} of {checked} operations failed.")
    else:
        print(f"All {checked} operations validated successfully!")
    return failures


if __name__ == "__main__":
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as file:
            lines = file.readlines()
    else:
        lines = sys.stdin.readlines()
    sys.exit(1 if check_operations(lines) else 0)
