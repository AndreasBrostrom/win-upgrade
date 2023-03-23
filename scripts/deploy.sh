#!/bin/bash

set -e

VERSION_TAG=$*

mkdir release/

sed -i "s/*BUILD =.*/BUILD =. \"${VERSION_TAG}\"/" release/upgrade.ps1

# Pack Compositions
zip release/upgrade-${VERSION_TAG}.zip upgrade.cmd upgrade.ps1 README.md
