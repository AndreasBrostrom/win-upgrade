#!/bin/bash

set -e

VERSION_TAG=$*

mkdir -p release/

sed -i "s/\$BUILD = \"DEV\"*/\$BUILD = \"${VERSION_TAG}\"/" upgrade.ps1

# Pack Compositions
zip release/upgrade-${VERSION_TAG}.zip upgrade.cmd upgrade.ps1 README.md
