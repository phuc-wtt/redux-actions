#!/bin/bash

test_community_page() {

  # Variable
  file_path=$1
  actions_name=$2
  
  actions_arr=$(
    grep -oP "(?<=${actions_name}\.)\w+" "$file_path" |
      sort | uniq
  )
  
  # b)each actions_using check if need to suffix Callback
  while IFS= read -r action
  do
    is_duplicated=$(grep -oP "(const\s+${action})(\s+=)" "$file_path")
    if [ ! -z "$is_duplicated" ];
    then
      line_num=$(
        grep -noP "(?<!${actions_name}\.)${action}" "$file_path" |
          grep -oP "^\d*(?=:)" | sort | uniq
      )

      while IFS= read -r line
      do
        to_be_replace=$(
          awk -v line=${line} 'NR==line' "$file_path" |
            sed 's/\./\\./g' |
            sed 's:\/:\\/:g' |
            sed 's/(/\\(/g' | sed 's/)/\\)/g' |
            sed 's/{/\\{/g' | sed 's/}/\\}/g' |
            sed 's/\[/\\[/g' | sed 's/\]/\\]/g' |
            sed 's/|/\\|/g' 
        )
        appended_action="${action}Callback"
        replace_string=$(
          awk -v line=${line} -v action=${action} -v appended_action=${appended_action} \
            'NR==line {sub(action, appended_action); print}' "$file_path" |
            sed 's/\./\\./g' |
            sed 's:\/:\\/:g' |
            sed 's/(/\\(/g' | sed 's/)/\\)/g' |
            sed 's/{/\\{/g' | sed 's/}/\\}/g' |
            sed 's/\[/\\[/g' | sed 's/\]/\\]/g' |
            sed 's/|/\\|/g' 
        )
        if [ ! -z "$replace_string" ];
        then
          sed -i -r "s@${to_be_replace}@${replace_string}@g" "$file_path"
          continue;
        fi
      done <<< $line_num
    fi
  done <<< $actions_arr

  # c)remove the actions_name and dot
  sed -i "s/${actions_name}\.//g" "$file_path"
  # d)replace import actions_name with actions_using
  destructuring_import_str=$(
    echo $actions_arr |
      sed "s/\s/, /g" |
      sed -E "s/^(\w*)/{ \1/g" |
      sed -E "s/(\w*)$/\1 }/g"
  )
  sed -i "s/import ${actions_name}/import ${destructuring_import_str}/g" "$file_path"


}

test_community_page $1 $2









# III.each actions_name:
#  1>search for file_contains actions_name
#  2>each file_contains 
#   a)search for actions_using
#   b)each actions_using check if need to suffix Callback
#   c)remove the actions_name and dot
#   d)replace import actions_name with actions_using
