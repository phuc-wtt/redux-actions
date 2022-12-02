#!/bin/bash

# cmd: ./action-services.sh -p "./redux/actions/services" -x "index"


base_name=$(echo $(basename "$0"))
echo "Executing $base_name"
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

# require: file_path
if [ -z "$file_path" ];
  then exit
  # extract working_folder
  else
    file_path=$(echo "$file_path" | sed 's|/$||g')
    working_folder=$(echo "$file_path" | grep -oP '(?<=/)\w+$')
fi

# Print out initial config
echo "-------------- Input --------------"
echo "File path: "$file_path""
echo "File name: "$file_name""
echo "File to exclude:"
for i in "${exclude_file[@]}"
do
  echo "$i"
done
echo "-------------- Output --------------"

actions() {

  # Variable
  local file_path="$1"

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
  local file_path=$1
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

  # append Service to method
  sed -i -E "s/${actions_name}\.(\w+)\(/\1Service(/g" "$file_path"
  # c)remove the actions_name and dot
  sed -i "s/${actions_name}\.//g" "$file_path"
  # d)replace import actions_name with actions_using
  destructuring_import_str=$(
  echo $actions_arr | sed -E "s/(\w+)/\1Service/g" |sed "s/\s/, /g" | sed -E "s/^(\w*)/{ \1/g" |
      sed -E "s/(\w*)$/\1 }/g"
  )
  sed -i "s/import ${actions_name}/import ${destructuring_import_str}/g" "$file_path"
}

query_string_helper_handler() {

  local string_helper_path="./redux/actions/services/queryString.js"
  local string_helper_all_method=$(
    grep -oP '(?<=export\sfunction\s)\w+' "$string_helper_path"
  )

  local string_helper_import_list=$(
    grep -rlP "import.*queryStringHelper.*" ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
      --exclude-dir=.next/ --exclude-dir=.git | awk 'NF'
  )
  echo "$string_helper_import_list"
  while IFS= read -r helper_using_file
  do
    while IFS= read -r helper_method
    do
      # check if helper_method in use
      local is_in_use=$(grep -oE "${helper_method}" "$helper_using_file")
      if [ ! -z "$is_in_use" ];
      then
        sed -i -E "s/queryStringHelper\.(${helper_method})\(/\1Service(/g" "$helper_using_file"
        sed -i "\|{ queryStringHelper }|a import { ${helper_method}Service } from '${string_helper_path}'" "$helper_using_file"
      fi
    done <<< $string_helper_all_method
  done <<< $string_helper_import_list

}

actions_service_phase_2() {
  local file_path=$1
  local actions_list_filtered=$2
  local suffix="Service"
  local import_placeholder="// SERVICE_IMPORT_PLACEHOLDER"

  # replace all "import services" with import_placeholder
  file_list=$(
    grep -rlP "import\s+service[s]\s+from\s+.*/services." ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
      --exclude-dir=.next/ --exclude-dir=.git | awk 'NF'
  )
  while IFS= read -r file
  do
    sed -i -E "s|import\s+service[s]\s+from\s+.*/services.|${import_placeholder}|g" "$file"
  done <<< "$file_list"
    # in case 'import services, { ... } '
  file_list_extra=$(
    grep -rnP "import\s+service[s].*/services." ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
      --exclude-dir=.next/ --exclude-dir=.git | awk 'NF' |grep -o '^.*:.*:'
  )
  while IFS= read -r line
  do
    local extra_file=$(echo "$line" | sed 's|:.*||g' )
    local extra_line_num=$(echo "$line" | grep -oP '\d+' )
    sed -i "${extra_line_num}s|^|${import_placeholder}\n|" "$extra_file"
  done <<< "$file_list_extra"
  
  # get all service method: [service:file_path] && check for duplicate method
  local service_methods=$(
    grep -roP "(?<=export\sfunction\s)\w+" "$file_path" --exclude-dir=node_modules/ --exclude-dir=out/ \
      --exclude-dir=.next/ --exclude-dir=.git | awk 'NF' | sed 's/(//g'
  )
    # check for duplicate methods name
  local service_methods_dup=$(
    echo "$service_methods" | grep -oP "(?<=:).*" | sort | uniq -d
  )
  if [ ! -z "$service_methods_dup" ];
  then
    echo "Duplicate method: ${service_methods_dup}"
    echo "Duplicate method require manual handling."
    # filter out duplicated method
    while IFS= read -r dup_method
    do
      service_methods=$(
        echo "$service_methods" | sed "s|${dup_method}||g" |
          sed -E "/:$/d"
      )
    done <<< $service_methods_dup
  fi

  # Each service method:
  while IFS= read -r method_with_path
  do
    # grep in prj for "Servicemethod" using_file
    method=$(echo $method_with_path | grep -oP "(?<=:).*")
    using_file=$(
      grep -rlE "services\.${method}\(" ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
        --exclude-dir=.next/ --exclude-dir=.git | awk 'NF' | sed 's/(//g'
    )
    if [ ! -z "$using_file" ];
    then
      # Each using_file:
      while IFS= read -r file
      do
        # rm the "services" from "services.method" && append "Service" to the method
        sed -i -E "s/services\.${method}/${method}${suffix}/g" "$file"
        # search method export file && explode the import -> { methodService }
        local export_file_name=$(
          grep -rE "export\sfunction\s+${method}\(" "$file_path" |
            grep -E '^.*:' | grep -oP '(?<=/)\w+(?=\.js)'
        )

        # replace import with exploded one
        local is_existed=$(grep -nE "${import_placeholder}" "$file")
        local exploded_import="import { ${method}${suffix} } from '@redux/actions/services/${export_file_name}'"
        if [ ! -z "${is_existed}" ]
        then
          sed -i "\|${import_placeholder}|a ${exploded_import}" "$file"
          # else log out the file_name
        else
          echo "import_placeholder not found in: ${file}"
        fi
      done <<< $using_file
    fi

  done <<< $service_methods

  # clean up import_placeholder
  remaining_placeholder=$(
    grep -rlE "${import_placeholder}" ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
      --exclude-dir=.next/ --exclude-dir=.git --exclude="$base_name"  | awk 'NF'
  )
  escaped_import_placeholder=$(echo "$import_placeholder" | sed 's|/|\\/|g')
  while IFS= read -r remaining_file
  do
    sed -i "/${escaped_import_placeholder}/d" "$remaining_file"
  done <<< $remaining_placeholder

  # clean up: import services
  local excess_services_import=$(
    grep -rlE "import\s+service[s].*services." ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
      --exclude-dir=.next/ --exclude-dir=.git --exclude="$base_name" | awk 'NF'
  )
  while IFS= read -r excess_file
  do
    sed -i "/import service/d" "$excess_file"
  done <<< $excess_services_import
  # # clean up: import { queryStringHelper }
  # local excess_string_helper_import=$(
  #   grep -rlE "import.*queryStringHelper.*" ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
  #     --exclude-dir=.next/ --exclude-dir=.git --exclude="$base_name" | awk 'NF'
  # )
  # while IFS= read -r excess_helper_file
  # do
  #   sed -i "/import/d" "$excess_helper_file"
  # done <<< $excess_string_helper_import




  # append "Service" to export default in services/
  while IFS= read -r service_file
  do
    sed -E -i 's/(export function )(\w+)/\1\2Service/g' "$service_file"
  done <<< $actions_list_filtered

  # TODO: check services/ imports
  # TODO: if method define in-file no need for import
  # TODO: check services/tag.js

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

  # phase 2: rm Servicemethod
    # get rid queryStringHelper
    query_string_helper_handler "$file_path" # special case, higher priority
  actions_service_phase_2 "$file_path" "$actions_list_filtered"


}
run




# list action files
# Each file:
  # execute actions.sh
  # filter out not processed case
# Each filtered file:
  # search Action for usage in project, exclude its filename
  # Each file that using action:
    # execute action_using.sh






