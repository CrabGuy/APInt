BASE = 2**52

def is_number(x):
    return isinstance(x, (int, float))

def decimal(number):
    if is_number(number):
        return int(number)

    return sum(digit * (BASE**i) for i, digit in enumerate(number))


def check_operations(file_name):
    file = open(file_name)
    lines = file.readlines()

    for (index, line) in enumerate(lines):

        is_empty_line = len(line) == 1

        if is_empty_line:
            continue

        tokens = line.split("=")
        assert len(tokens) == 2, "Invalid formatting"

        operations = tokens[0]
        given_result = decimal(eval(tokens[1]))

        correct_result = decimal(eval(operations))

        assert correct_result == given_result, f"ERROR: line {index}\nOperation:\t{operations}\nCorrect result:\t{correct_result}\nResult got:\t{given_result}"

    file.close()

if __name__ == "__main__":
    check_operations("operations.txt")
    