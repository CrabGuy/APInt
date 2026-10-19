"""Runs the whole APInt test suite on every installed runtime.

Usage:
    python3 run_test.py [--count N] [--seed S]

For Lua 5.2, Luau and Luau with native code generation (when installed) it runs
the unit tests in test.lua, then checks N rounds of random operations from
random_operations.lua against Python's integers. The Luau CLI is found on PATH
or through the LUAU environment variable. If a random check fails, the
operations are kept in operations.txt to reproduce it.
"""

import argparse
import os
import random
import shutil
import subprocess
import sys

from check_operations import check_operations

HERE = os.path.dirname(os.path.abspath(__file__))


def find_runtimes():
    """Returns (label, command prefix, separator before script arguments) for each runtime."""
    runtimes = []
    for name in ("lua5.2", "lua"):
        path = shutil.which(name)
        if path:
            version = subprocess.run([path, "-v"], capture_output=True, text=True)
            if "5.2" in version.stdout + version.stderr:
                runtimes.append(("Lua 5.2", [path], []))
                break
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if luau:
        runtimes.append(("Luau", [luau], ["-a"]))
        runtimes.append(("Luau (native)", [luau, "--codegen"], ["-a"]))
    return runtimes


def run_suite(label, command, separator, seed, count):
    print(f"\n=== {label} ===", flush=True)
    unit = subprocess.run(command + ["test.lua"], cwd=HERE)
    if unit.returncode != 0:
        print(f"Unit tests failed on {label}.")
        return False

    print(f"Random operations: seed {seed}, {count} rounds", flush=True)
    generated = subprocess.run(command + ["random_operations.lua"] + separator + [str(seed), str(count)],
                               cwd=HERE, capture_output=True, text=True)
    if generated.returncode != 0:
        print(generated.stdout[-2000:], generated.stderr[-2000:])
        print(f"Generating random operations failed on {label}.")
        return False
    if check_operations(generated.stdout.splitlines()) != 0:
        with open(os.path.join(HERE, "operations.txt"), "w") as file:
            file.write(generated.stdout)
        print("The operations were saved to operations.txt.")
        return False
    return True


def main():
    parser = argparse.ArgumentParser(description="Runs the APInt test suite on every installed runtime.")
    parser.add_argument("--count", type=int, default=500, help="rounds of random operations per runtime")
    parser.add_argument("--seed", type=int, default=random.randrange(1, 2**31), help="seed for the random operations")
    args = parser.parse_args()

    runtimes = find_runtimes()
    if not runtimes:
        sys.exit("No runtime found: install Lua 5.2 (lua5.2) or the Luau CLI (luau, or set LUAU).")

    failed = [label for label, command, separator in runtimes
              if not run_suite(label, command, separator, args.seed, args.count)]
    if failed:
        sys.exit(f"\nTests failed on: {', '.join(failed)} (seed {args.seed})")
    print(f"\n--- All correctness tests passed on {', '.join(label for label, _, _ in runtimes)}! ---")


if __name__ == "__main__":
    main()
