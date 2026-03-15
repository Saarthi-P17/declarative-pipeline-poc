#!/bin/bash

# trigger commit sign off
echo "Checking commit sign-off..."

if ! git log -1 --pretty=%B | grep -q "Signed-off-by:"; then
  echo "ERROR: Commit is not signed off."
  exit 1
fi

echo "Commit sign-off verified."