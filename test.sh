#!/bin/bash

test_postActions() {

  # Variable
  file_path="./redux/actions/postActions.js"


  # I.rm Obj
  actions_name=$(grep -oP '(?<=export\sdefault\s)\w+' "$file_path")

  if [ ! -z "$actions_name" ];
    then
      line_num=$(grep -n "$actions_name" "$file_path" | sed 's/:.*//g')

      line_num=$(echo "$line_num" | sed 's/$/d;/g')
      line_num=$(echo $line_num | sed 's/\s//g')
      if [ ! -z "$line_num" ];
      then
        sed -i "$line_num" "$file_path"
        sed -i 's/^\}$//g' "$file_path"
      fi
  fi

  # II.explode actions-obj fields with export function
    # normal case
  sed -E -i 's/^\s{2}(\w+\(.*\)\s*\{$)/  export function \1/g' "$file_path"
    # async case
  sed -E -i 's/^\s{2}async\s+(\w+\(.*\)\s*\{$)/  export async function \1/g' "$file_path"
    # rm "," from "}," && rm "this."
  sed -E -i 's/this\.//g' "$file_path"
  sed -E -i 's/^(\s{2})\}\,/\1};/g' "$file_path"
  

}

test_postActions

# process per Actions
# I.rm Obj
# II.explode actions-obj fields with export function
# III.each actions_name:
#  1>search for file_contains actions_name
#  2>each file_contains 
#   a)search for actions_using
#   b)each actions_using check if need to suffix Callback
#   c)remove the actions_name and dot
#   d)replace import actions_name with actions_using
