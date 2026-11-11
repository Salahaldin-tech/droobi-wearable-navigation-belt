#!/usr/bin/env python3
"""Repair V3 QGZ datasource paths after moving the GeoPackage beside the project.

Only the relative path prefix is changed. Layer names, styles, map settings,
features, and the GeoPackage itself are not modified.
"""
from __future__ import annotations

import os
import tempfile
import zipfile
from pathlib import Path

PROJECT = Path("assets/campus_map_v3/AAUP_Campus_Network.qgz")
OLD = b"./data/campus_network.gpkg"
NEW = b"./campus_network.gpkg"


def main() -> None:
    if not PROJECT.is_file():
        raise SystemExit(f"QGIS project not found: {PROJECT}")

    with zipfile.ZipFile(PROJECT, "r") as source:
        qgs_names = [
            name for name in source.namelist()
            if name.lower().endswith(".qgs")
        ]
        if len(qgs_names) != 1:
            raise SystemExit(
                f"Expected exactly one .qgs document in QGZ; found {qgs_names!r}"
            )

        qgs_name = qgs_names[0]
        contents = source.read(qgs_name)
        occurrences = contents.count(OLD)

        if occurrences == 0:
            print("QGIS datasource paths already use the project-relative GeoPackage.")
            return

        repaired = contents.replace(OLD, NEW)
        if repaired.count(OLD):
            raise SystemExit("Not all obsolete relative datasource paths were repaired.")

        fd, temporary_name = tempfile.mkstemp(
            prefix=PROJECT.stem + ".",
            suffix=".qgz",
            dir=PROJECT.parent,
        )
        os.close(fd)
        temporary = Path(temporary_name)

        try:
            with zipfile.ZipFile(temporary, "w") as target:
                target.comment = source.comment
                for info in source.infolist():
                    data = repaired if info.filename == qgs_name else source.read(info.filename)
                    target.writestr(info, data)

            # Re-open and verify the rewritten project archive before replacing.
            with zipfile.ZipFile(temporary, "r") as check:
                verified = check.read(qgs_name)
                if verified.count(OLD) or verified.count(NEW) != occurrences:
                    raise SystemExit("Rewritten QGZ failed datasource-path verification.")
                if set(check.namelist()) != set(source.namelist()):
                    raise SystemExit("Rewritten QGZ archive entries differ from source.")

            os.replace(temporary, PROJECT)
        finally:
            if temporary.exists():
                temporary.unlink()

    print(
        f"Repaired {occurrences} datasource path(s): "
        f"{OLD.decode()} -> {NEW.decode()}"
    )


if __name__ == "__main__":
    main()
