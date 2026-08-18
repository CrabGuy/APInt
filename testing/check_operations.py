import sys

BASE = 2**52

def parse_apint(s):
    s = s.strip()
    if s.startswith('[') and s.endswith(']'):
        parts = [int(x.strip()) for x in s[1:-1].split(',')]
        res = 0
        for i, val in enumerate(parts):
            res += val * (BASE ** i)
        return res
    else:
        return int(s)

def check_operations(file_name):
    with open(file_name, 'r') as f:
        lines = f.readlines()

    failed = False
    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        if not line or '=' not in line:
            continue

        expr, expected_str = line.split('=', 1)
        expected = parse_apint(expected_str)

        if '+' in expr:
            a_str, b_str = expr.split('+')
            actual = int(a_str) + int(b_str)
        elif '-' in expr:
            a_str, b_str = expr.split('-')
            actual = int(a_str) - int(b_str)
        elif '*' in expr:
            a_str, b_str = expr.split('*')
            actual = int(a_str) * int(b_str)
        elif '/' in expr:
            a_str, b_str = expr.split('/')
            actual = int(a_str) // int(b_str)
        else:
            continue

        if actual != expected:
            print(f"Error on line {line_num}: {expr}")
            print(f"  Expected: {actual}")
            print(f"  Got:      {expected}")
            failed = True

    if not failed:
        print("All operations validated successfully!")
    else:
        sys.exit(1)

if __name__ == "__main__":
    file_name = sys.argv[1] if len(sys.argv) > 1 else "operations.txt"
    check_operations(file_name)