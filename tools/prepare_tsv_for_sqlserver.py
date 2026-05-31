# -*- coding: utf-8 -*-
"""Convert Kaggle CSV files to tab-delimited files for SQL Server BULK INSERT.

Some SQL Server installations fail on BULK INSERT ... FORMAT='CSV'. These TSV
files avoid quoted commas, so the compatible loader can use FIELDTERMINATOR.
"""

from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "processed" / "tsv"

FILES = [
    "event_details.csv",
    "fighter_details.csv",
    "fight_details.csv",
    "UFC.csv",
]


def clean(value: str | None) -> str:
    if value is None:
        return ""
    return value.replace("\t", " ").replace("\r", " ").replace("\n", " ").strip()


def convert(path: Path) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / f"{path.stem}.tsv"
    with path.open("r", encoding="utf-8-sig", newline="") as src, target.open(
        "w", encoding="utf-8", newline=""
    ) as dst:
        reader = csv.reader(src)
        writer = csv.writer(dst, delimiter="\t", lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
        for row in reader:
            writer.writerow([clean(value) for value in row])
    return target


def main() -> None:
    for name in FILES:
        target = convert(RAW / name)
        print(target)


if __name__ == "__main__":
    main()
