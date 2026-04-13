#!/usr/bin/env bash
set -euo pipefail

###############################################################################
TEST_DATE="22_22_2222"
SRC_BASE="/hps/nobackup/literature/text-mining/daily_pipeline_api/00_00_0000"
DST_BASE="/hps/nobackup/literature/text-mining/daily_pipeline_api/${TEST_DATE}"
LIMIT=300                               # files per section
###############################################################################

copy_first_n () {
  local section=$1
  local src="${SRC_BASE}/${section}/source"
  local dst="${DST_BASE}/${section}/source"

  echo "→ scanning ${src}"
  mkdir -p "${dst}"

  # associative array path ↦ integer extracted from basename
  local -A keep=()

  while IFS= read -r -d '' file; do
      base=${file##*/}               # strip leading directories
      digits=${base%%.*}             # cut off .xml.gz
      digits=${digits##*-}           # keep part after last '-'
      num=${digits//[^0-9]/}         # remove any non-digits
      num=${num:-0}                  # default to 0

      if ((${#keep[@]} < LIMIT)); then
          keep["$file"]=$num
      else
          # find current worst (largest) key
          worst_file='' worst_key=-1
          for k in "${!keep[@]}"; do
              if ((${keep[$k]} > worst_key)); then
                  worst_key=${keep[$k]} worst_file=$k
              fi
          done
          if (( num < worst_key )); then
              unset keep["$worst_file"]
              keep["$file"]=$num
          fi
      fi
  done < <(find "${src}" -type f -print0)

  echo "  ↳ will copy ${#keep[@]} files"
  for f in "${!keep[@]}"; do cp -n -- "$f" "${dst}/"; done
  echo "  ↳ ${section}: copied ${#keep[@]} files → ${dst}"
}

echo "Creating test dataset dated ${TEST_DATE} …"
copy_first_n abstract
copy_first_n fulltext
echo "Done."

