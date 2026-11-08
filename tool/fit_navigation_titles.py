# /// script
# dependencies = ["numpy", "scipy"]
# ///
"""Fit native presentation traces. Run: uv run tool/fit_navigation_titles.py <directory>."""

import argparse
import json
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares


def response(time, omega, damping_ratio, onset, velocity):
    time = np.maximum(0, time + onset)
    if damping_ratio < 1:
        frequency = omega * np.sqrt(1 - damping_ratio**2)
        return 1 - np.exp(-damping_ratio * omega * time) * (
            np.cos(frequency * time)
            + (damping_ratio * omega - velocity) / frequency * np.sin(frequency * time)
        )
    if damping_ratio > 1:
        root = np.sqrt(damping_ratio**2 - 1)
        a, b = -omega * (damping_ratio - root), -omega * (damping_ratio + root)
        first = (velocity + b) / (a - b)
        return 1 + first * np.exp(a * time) + (-1 - first) * np.exp(b * time)
    return 1 - (1 + (omega - velocity) * time) * np.exp(-omega * time)


def fit_file(path):
    samples = json.loads(path.read_text())
    series = [
        (sample["t"], label["effectiveOpacity"])
        for sample in samples
        for label in sample["labels"]
        if label["fontSize"] == 17
    ]
    previous_start = -1
    for index in range(1, len(series)):
        time, value = series[index]
        initial = series[index - 1][1]
        if initial not in (0, 1) or abs(value - initial) <= 0.0001:
            continue
        if time - previous_start <= 0.8:
            continue
        previous_start = time
        points = []
        for timestamp, opacity in series[index:]:
            if timestamp - time > 0.6 or (points and opacity in (0, 1)):
                break
            points.append((timestamp - time, opacity if initial == 0 else 1 - opacity))
        if len(points) < 10:
            continue
        times, values = np.array(points).T
        fits = [
            least_squares(
                lambda parameters: response(times, *parameters) - values,
                [16, ratio, 0.01, 0],
                bounds=([1, 0.1, -0.02, -50], [100, 3, 0.05, 50]),
                max_nfev=10000,
            )
            for ratio in (0.7, 0.95, 1.05, 1.5)
        ]
        fit = min(fits, key=lambda result: sum(result.fun**2))
        omega, ratio, onset, velocity = fit.x
        yield {
            "source": path.name,
            "direction": "enter" if initial == 0 else "exit",
            "firstChangedSample": time,
            "mass": 1,
            "stiffness": omega**2,
            "damping": 2 * ratio * omega,
            "fittedSubframeOnset": onset,
            "initialVelocity": velocity,
            "rmse": float(np.sqrt(np.mean(fit.fun**2))),
            "maxError": float(max(abs(fit.fun))),
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    for mode in ("large", "inlineLarge"):
        path = args.directory / f"navigation-{mode}-never-automatic.json"
        if path.exists():
            for result in fit_file(path):
                print(json.dumps(result))


if __name__ == "__main__":
    main()
