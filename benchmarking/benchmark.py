"""Runs benchmark.lua on the installed Lua runtimes and plots APInt against BigNum.

Usage:
    python3 benchmark.py                        run on every runtime found, then plot
    python3 benchmark.py --quick                a faster, rougher run
    python3 benchmark.py --runtime luau-native  choose runtimes: lua5.2, luau, luau-native
    python3 benchmark.py --plot FILE [FILE ...] only plot saved results: CSV files written
                                                by this script, or console output of
                                                benchmark.lua (e.g. copied from Roblox Studio)

Each run is saved as results/<runtime>.csv. The charts go to results/: one
throughput_<runtime>.png per runtime and speedup.png comparing all of them. The
Luau CLI is found on PATH or through the LUAU environment variable. Plotting needs
matplotlib (pip install matplotlib).
"""

import argparse
import csv
import io
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(HERE, "results")
SCRIPT = os.path.join(HERE, "benchmark.lua")

# Chart styling: the data is the only loud thing.
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
INK_MUTED = "#898781"
GRID = "#e1e0d9"
AXIS = "#c3c2b7"
LIBRARY_STYLE = {
    "APInt": {"color": "#2a78d6", "marker": "o"},
    "BigNum": {"color": "#eb6834", "marker": "s"},
}
RUNTIME_STYLES = [  # in this fixed order, for the runtimes in the order they appear
    {"color": "#2a78d6", "marker": "o"},
    {"color": "#eb6834", "marker": "s"},
    {"color": "#1baf7a", "marker": "^"},
]


def find_lua52():
    for name in ("lua5.2", "lua"):
        path = shutil.which(name)
        if path:
            version = subprocess.run([path, "-v"], capture_output=True, text=True)
            if "5.2" in version.stdout + version.stderr:
                return path
    return None


def find_luau():
    return os.environ.get("LUAU") or shutil.which("luau")


def available_runtimes():
    """Maps runtime names to (label, command prefix, extra args before script args)."""
    runtimes = {}
    lua = find_lua52()
    if lua:
        runtimes["lua5.2"] = ("Lua 5.2", [lua, SCRIPT], [])
    luau = find_luau()
    if luau:
        runtimes["luau"] = ("Luau", [luau, SCRIPT], ["-a"])
        runtimes["luau-native"] = ("Luau (native)", [luau, "--codegen", SCRIPT], ["-a"])
    return runtimes


def extract_csv(text):
    """Returns the CSV rows from benchmark.lua output, or from a plain CSV file."""
    match = re.search(r"BEGIN CSV\s*\n(.*?)\n\s*END CSV", text, re.S)
    body = match.group(1) if match else text
    # Roblox Studio prefixes every output line with a timestamp; drop anything before the CSV columns
    lines = []
    for line in body.splitlines():
        start = line.find('"') if not line.startswith("runtime,") else 0
        if line.strip() and start >= 0:
            lines.append(line[start:])
    rows = list(csv.DictReader(io.StringIO("\n".join(lines))))
    for row in rows:
        row["digits"] = int(row["digits"])
        row["ops_per_second"] = float(row["ops_per_second"])
    return rows


def run_benchmark(name, label, command, separator, quick):
    """Runs benchmark.lua with one runtime, streaming its output, and saves the CSV."""
    print(f"\n=== {label} ===", flush=True)
    args = separator + [f"--label={label}"] + (["--quick"] if quick else [])
    process = subprocess.Popen(command + args, stdout=subprocess.PIPE, text=True, cwd=HERE)
    output = []
    in_csv = False
    for line in process.stdout:
        output.append(line)
        in_csv = in_csv or line.startswith("BEGIN CSV")
        if not in_csv:
            print(line, end="", flush=True)
        in_csv = in_csv and not line.startswith("END CSV")
    if process.wait() != 0:
        sys.exit(f"benchmark.lua failed on {label}")

    rows = extract_csv("".join(output))
    path = os.path.join(RESULTS, f"{name}.csv")
    with open(path, "w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Saved {os.path.relpath(path)}")
    return rows


def compact(value):
    for limit, suffix in ((1e9, "G"), (1e6, "M"), (1e3, "K")):
        if value >= limit:
            return f"{value / limit:g}{suffix}"
    return f"{value:g}"


def slug(label):
    return re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")


def group(rows):
    """data[runtime][operation][library] = sorted list of (digits, ops/s), plus metadata."""
    data = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
    workloads = {}
    for row in rows:
        data[row["runtime"]][row["operation"]][row["library"]].append((row["digits"], row["ops_per_second"]))
        workloads[row["operation"]] = row["workload"]
    for operations in data.values():
        for libraries in operations.values():
            for points in libraries.values():
                points.sort()
    operations = list(dict.fromkeys(row["operation"] for row in rows))
    return data, operations, workloads


def style_axes(ax, sizes):
    import matplotlib.ticker as ticker

    ax.set_facecolor(SURFACE)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xticks(sizes)
    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda value, _: compact(value)))
    ax.xaxis.set_minor_locator(ticker.NullLocator())
    ax.yaxis.set_minor_locator(ticker.NullLocator())
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda value, _: compact(value)))
    ax.grid(True, which="major", color=GRID, linewidth=0.8, linestyle="-")
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(AXIS)
        ax.spines[side].set_linewidth(0.8)
    ax.tick_params(colors=INK_MUTED, labelsize=8, length=0, pad=4)


def fit_y(ax, values, suffix=""):
    """Sets log y limits that show at least a 4x range, with clean 1-2-5 or decade ticks."""
    import math
    import matplotlib.ticker as ticker

    low, high = min(values), max(values)
    if high / low < 4:
        middle = math.sqrt(low * high)
        low, high = middle / 2, middle * 2
    ax.set_ylim(low / 1.25, high * 1.25)
    subs = (1.0, 2.0, 5.0) if high / low <= 1000 else (1.0,)
    ax.yaxis.set_major_locator(ticker.LogLocator(base=10, subs=subs))
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda value, _: compact(value) + suffix))


def plot_line(ax, points, style, label):
    xs, ys = zip(*points)
    ax.plot(xs, ys, label=label, color=style["color"], marker=style["marker"], linewidth=1.6,
            markersize=6, markeredgecolor=SURFACE, markeredgewidth=1.5, solid_capstyle="round",
            solid_joinstyle="round")


def panel_grid(count):
    import matplotlib.pyplot as plt

    columns = 4
    rows = (count + columns - 1) // columns
    figure, axes = plt.subplots(rows, columns, figsize=(4 * columns, 3.1 * rows + 1.2), facecolor=SURFACE)
    axes = axes.flatten()
    for ax in axes[count:]:
        ax.set_visible(False)
    return figure, axes


def finish(figure, title, subtitle, path):
    figure.suptitle(title, x=0.01, y=0.995, ha="left", fontsize=14, color=INK, fontweight="semibold")
    figure.text(0.01, 0.955, subtitle, ha="left", va="top", fontsize=9.5, color=INK_SECONDARY)
    handles, labels = figure.axes[0].get_legend_handles_labels()
    figure.legend(handles, labels, loc="upper right", bbox_to_anchor=(0.995, 0.995), ncol=len(labels),
                  frameon=False, fontsize=10, labelcolor=INK)
    figure.tight_layout(rect=(0, 0, 1, 0.93))
    figure.savefig(path, dpi=150, facecolor=SURFACE)
    print(f"Saved {os.path.relpath(path)}")


def panel_title(ax, operation, workloads):
    ax.set_title(f"{operation}  ·  {workloads[operation]}", loc="left", fontsize=9.5, color=INK, pad=8)


def plot_throughput(data, operations, workloads):
    import matplotlib.pyplot as plt

    for runtime, by_operation in data.items():
        figure, axes = panel_grid(len(operations))
        for ax, operation in zip(axes, operations):
            sizes = sorted({digits for points in by_operation[operation].values() for digits, _ in points})
            values = []
            for library, style in LIBRARY_STYLE.items():
                if by_operation[operation][library]:
                    plot_line(ax, by_operation[operation][library], style, library)
                    values.extend(rate for _, rate in by_operation[operation][library])
            style_axes(ax, sizes)
            fit_y(ax, values)
            panel_title(ax, operation, workloads)
        for ax in axes[::4]:
            ax.set_ylabel("operations per second", fontsize=8.5, color=INK_SECONDARY)
        for ax in axes[-4:]:
            ax.set_xlabel("size (decimal digits)", fontsize=8.5, color=INK_SECONDARY)
        finish(figure, f"APInt vs BigNum throughput on {runtime}",
               "Operations per second by operand size, both axes logarithmic; higher is better. "
               "A line that stops early means that library would need more than a second per operation.",
               os.path.join(RESULTS, f"throughput_{slug(runtime)}.png"))
        plt.close(figure)


def speedups(by_operation, operation):
    apint = dict(by_operation[operation]["APInt"])
    bignum = dict(by_operation[operation]["BigNum"])
    return [(digits, apint[digits] / bignum[digits]) for digits in sorted(apint) if digits in bignum]


def plot_speedup(data, operations, workloads):
    import matplotlib.pyplot as plt

    figure, axes = panel_grid(len(operations))
    for ax, operation in zip(axes, operations):
        sizes, values = set(), [1.0]
        for runtime, style in zip(data, RUNTIME_STYLES):
            points = speedups(data[runtime], operation)
            if points:
                plot_line(ax, points, style, runtime)
                sizes.update(digits for digits, _ in points)
                values.extend(ratio for _, ratio in points)
        style_axes(ax, sorted(sizes))
        fit_y(ax, values, suffix="x")
        ax.axhline(1, color=AXIS, linewidth=1, zorder=1)
        panel_title(ax, operation, workloads)
    for ax in axes[::4]:
        ax.set_ylabel("APInt speed / BigNum speed", fontsize=8.5, color=INK_SECONDARY)
    for ax in axes[-4:]:
        ax.set_xlabel("size (decimal digits)", fontsize=8.5, color=INK_SECONDARY)
    finish(figure, "How many times faster APInt is than BigNum",
           "Ratio of operations per second by operand size, both axes logarithmic. "
           "Above the 1x line APInt is faster; sizes BigNum could not finish are left out.",
           os.path.join(RESULTS, "speedup.png"))
    plt.close(figure)


def print_summary(data, operations):
    """Prints the speedups as markdown tables, one per runtime."""
    for runtime, by_operation in data.items():
        sizes = sorted({digits for operation in operations for digits, _ in speedups(by_operation, operation)})
        print(f"\n**{runtime}**: APInt speedup over BigNum by operand size (decimal digits)\n")
        print("| operation | " + " | ".join(str(size) for size in sizes) + " |")
        print("|---|" + "---:|" * len(sizes))
        for operation in operations:
            ratios = dict(speedups(by_operation, operation))
            cells = [f"{ratios[size]:,.1f}x" if size in ratios else "-" for size in sizes]
            print(f"| {operation} | " + " | ".join(cells) + " |")


def plot(rows):
    data, operations, workloads = group(rows)
    print_summary(data, operations)
    try:
        import matplotlib

        matplotlib.use("Agg")
    except ImportError:
        print("\nmatplotlib is not installed, skipping the charts (pip install matplotlib).")
        return
    plot_throughput(data, operations, workloads)
    plot_speedup(data, operations, workloads)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--quick", action="store_true", help="fewer sizes and shorter timings")
    parser.add_argument("--runtime", action="append", help="runtime to benchmark (repeatable)")
    parser.add_argument("--plot", nargs="+", metavar="FILE", help="plot saved results instead of running")
    args = parser.parse_args()
    os.makedirs(RESULTS, exist_ok=True)

    if args.plot:
        rows = []
        for path in args.plot:
            with open(path) as file:
                rows.extend(extract_csv(file.read()))
        plot(rows)
        return

    runtimes = available_runtimes()
    chosen = args.runtime or list(runtimes)
    missing = [name for name in chosen if name not in runtimes]
    if missing:
        sys.exit(f"Runtime not found: {', '.join(missing)} (available: {', '.join(runtimes) or 'none'})")
    rows = []
    for name in chosen:
        label, command, separator = runtimes[name]
        rows.extend(run_benchmark(name, label, command, separator, args.quick))
    plot(rows)


if __name__ == "__main__":
    main()
