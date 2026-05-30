# -*- coding: utf-8 -*-
"""Print simple row counts and headers for the Kaggle UFC CSV files."""

from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"


def main() -> None:
    for path in sorted(RAW.glob("*.csv")):
        with path.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.reader(f)
            header = next(reader)
            rows = sum(1 for _ in reader)
        print(f"{path.name}: {rows} rows, {len(header)} columns")
        print("  " + ", ".join(header[:12]) + (" ..." if len(header) > 12 else ""))


if __name__ == "__main__":
    main()
