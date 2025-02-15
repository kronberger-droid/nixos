#!/bin/sh
# Run Tectonic build
"${pkgs.tectonic}/bin/tectonic" -X compile main.tex --synctex --keep-logs --outdir=.
# Check if Tectonic succeeded
if [ $? -eq 0 ]; then
  # Remove auxiliary files that you don't need
  rm -f main.aux main.log main.synctex
fi
