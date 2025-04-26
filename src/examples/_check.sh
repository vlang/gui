#!/bin/bash
find . -name "*.v" -print0 | while IFS= read -r -d $'\0' file; do
  echo $file
  v -check "$file"
  if [ $? -ne 0 ]; then
    echo "Error processing $file" >&2
  fi
done