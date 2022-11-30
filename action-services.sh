#!/bin/bash

file_path=""
max_depth=1
file_name="*.js"
exclude_file=()
path_root=""

while getopts ":p:n:x:" option;
do
  case $option in
    p) file_path="$OPTARG" ;;
    n) file_name="$OPTARG" ;;
    x) exclude_file+=("$OPTARG") ;;
    d) max_depth=("$OPTARG") ;;
    *) echo "Invalid args"
  esac
done
if [ -z "$file_path" ];
# require: file_path
then exit

# extract working_folder
else
  file_path=$(echo "$file_path" | sed 's|/$||g')
  working_folder=$(echo "$file_path" | grep -oP '(?<=/)\w+$')
fi


echo "File path: "$file_path""
echo "File name: "$file_name""
echo "File to exclude:"
for i in "${exclude_file[@]}"
do
  echo "$i"
done

actions() {

  # Variable
  file_path="$1"

  # I.1. rm Obj
  actions_name=$(grep -oP '(?<=export\sdefault\s)(?!function\s)\w+' "$file_path")
  if [ ! -z "$actions_name" ];
    then
      line_num=$(grep -n "$actions_name" "$file_path" | sed 's/:.*//g')

      line_num=$(echo "$line_num" | sed 's/$/d;/g')
      line_num=$(echo $line_num | sed 's/\s//g')
      if [ ! -z "$line_num" ];
      then
        sed -i "$line_num" "$file_path"
        bracket_line=$(grep -nP '^\}$' "$file_path" | grep -oP "^\d+" )
        is_multi_bracket=$(echo "$bracket_line" | wc -l )
        if [ "$is_multi_bracket" -gt 1 ];
        then
          bracket_last_line=$(echo $bracket_line | grep -oP "(?<=\s)\d+$")
          sed -i "${bracket_last_line}d" "$file_path"
        else
          sed -i 's/^\}$//g' "$file_path"
        fi
      fi
    else
      # I.2. rm export default {}
      is_export_default_obj=$(
        grep -onP '^export\sdefault\s{' "$file_path" |
          sed 's:\/:\\/:g' |
          sed 's/{/\\{/g'
      )
      if [ ! -z "$is_export_default_obj" ];
      then
        sed -E -i "/^export\s+default\s+\{/d" "$file_path"
        line_num=$(echo "$is_export_default_obj" | sed 's/:.*//g')
        bracket_line=$(grep -nP '^\}$' "$file_path" | grep -oP "^\d+" )
        is_multi_bracket=$(echo "$bracket_line" | wc -l )
        if [ "$is_multi_bracket" -gt 1 ];
        then
          bracket_last_line=$(echo $bracket_line | grep -oP "(?<=\s)\d+$")
          sed -i "${bracket_last_line}d" "$file_path"
        else
          sed -i 's/^\}$//g' "$file_path"
        fi
      else
        echo "$1"
      fi
  fi

  # II.explode actions-obj fields with export function
    # normal case
  sed -E -i 's/^\s{2}(\w+\(.*)/  export function \1/g' "$file_path"
    # async case
  sed -E -i 's/^\s{2}async\s+(\w+\(.*)/  export async function \1/g' "$file_path"
    # rm "," from "}," && rm "this."
  sed -E -i 's/this\.//g' "$file_path"
  sed -E -i 's/^(\s{2})\}\,/\1};/g' "$file_path"
}


action_using() {
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
            sed 's/|/\\|/g' | sed 's/?/\\?/g'
        )
        appended_action="${action}Func"
        replace_string=$(
          awk -v line=${line} -v action=${action} -v appended_action=${appended_action} \
            'NR==line {sub(action, appended_action); print}' "$file_path" |
            sed 's/\./\\./g' |
            sed 's:\/:\\/:g' |
            sed 's/(/\\(/g' | sed 's/)/\\)/g' |
            sed 's/{/\\{/g' | sed 's/}/\\}/g' |
            sed 's/\[/\\[/g' | sed 's/\]/\\]/g' |
            sed 's/|/\\|/g' | sed 's/?/\\?/g'
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

actions_service_phase_2() {
  file_path={$1}

  # rm all "import services" from prj
  # get all service method: [service:file_path]
  # check for duplicate method
  # Each service method:
    # grep in prj for "services.method" using_file
      # Each using_file:
      # rm the "services." && append "Service" to the method
      # explode the import -> { methodService }
    # append "Service" to export default

}


run() {

  # list action files
  actions_list=$( find "${file_path}" -maxdepth ${max_depth} -name "${file_name}" )
  for exclude in "${exclude_file[@]}"
  do
    actions_list=$( echo "$actions_list" | sed "/${exclude}/d" )
  done
  actions_list_filtered="$actions_list"

  # Each file:
  while IFS= read -r action_file
  do
    # execute actions.sh
    test_result=$(actions "$action_file")
    # filter out not processed case
    if [ ! -z "$test_result" ];
    then
      test_result=$(echo "$test_result" | sed "s/\./\\\./g" | sed "s,/,\\\/,g")
      actions_list_filtered=$(
        echo "$actions_list_filtered" |
          sed "s/${test_result}//g" |
          awk 'NF'
      )
    fi
  done <<< $actions_list

  # Each filtered file:
  while IFS= read -r action_file
  do

    # search Action for usage in project, exclude its filename
    action_name=$(echo "$action_file" | grep -oE "(\w+\.js)$" | grep -oE "^\w+")
    using_file_list=$(
      grep -rlP "import.*${working_folder}/${action_name}(?!\w)(?!\.scss)" ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
        --exclude-dir=.next/ --exclude-dir=.git/ --exclude="${action_name}.js" |
        awk 'NF'
    )

    # Each file that using action:
    if [ ! -z "${using_file_list}" ];
    then
      while IFS= read -r using_file
      do
        # execute action_using.sh
        test2_action_name=$(
          grep -noP "import.*${working_folder}/${action_name}(?!\w)(?!\.scss)" "$using_file" |
            grep -oP "(?<=import\s)(\w+)\s+from.*(?=${action_name})" |
            grep -oP "^\w+(?=\s)"
        )
        if [ ! -z "${test2_action_name}" ];
        then
          action_using "$using_file" "$test2_action_name"
        fi
      done <<< $using_file_list
    fi

  done <<< $actions_list_filtered

  # phase 2: rm services.method
  actions_service_phase_2 "$file_path"

}
run


# exclude redux/actions/types.js
# sed '/types.js/d' |
# sed '/modalActions.js/d' |
# sed '/toastActions.js/d'


# list action files
# Each file:
  # execute actions.sh
  # filter out not processed case
# Each filtered file:
  # search Action for usage in project, exclude its filename
  # Each file that using action:
    # execute action_using.sh






