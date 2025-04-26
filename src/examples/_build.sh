#!/bin/bash

# Set the output directory
output_dir="bin"

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Find all .v files
find . -name "*.v" -print0 | while IFS= read -r -d $'\0' file; do
  # Extract filename without extension
  filename="${file%.v}"
  #Construct the output file name
  output_file="$output_dir/$(basename "$filename")"

  # Compile the file using v -prod
  echo "Compiling: $file -> $output_file"
  v -prod "$file" -o "$output_file" || {
    echo "Error compiling $file"
    exit 1 # Exit with an error code if compilation fails
  }
done

echo "Compilation complete."