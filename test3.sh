#!/bin/bash

test3() {

  # list action files
  actions_path="./redux/actions"
  actions_list=$(
    find "${actions_path}/" -maxdepth 1 -name "*.js" |
      # exclude redux/actions/types.js
      sed '/types.js/d'
  )
  actions_list_filtered="$actions_list"

  # Each file:
  while IFS= read -r action_file
  do
    # execute test.sh
    test_result=$(source test.sh "$action_file")
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
     grep -rl "${action_name}" ./ --exclude-dir=node_modules/ --exclude-dir=out/ \
      --exclude-dir=.next/ --exclude-dir=.git/ --exclude="${action_name}.js" |
      awk 'NF'
    )

    # Each file that using action:
    if [ ! -z "${using_file_list}" ];
    then
      while IFS= read -r using_file
      do
        # execute test2.sh
        test2_action_name=$(
          grep -Eon "import.*${action_name}" "$using_file" |
            grep -oP "(?<=import\s)(\w+)\s+from.*(?=${action_name})" |
            grep -oP "^\w+(?=\s)"
        )
        if [ ! -z "${test2_action_name}" ];
        then
          source test2.sh "$using_file" "$test2_action_name"
        fi
      done <<< $using_file_list
    fi

  done <<< $actions_list_filtered

}
test3


# NOTE: EXCLUDE PropTypes



# list action files
# Each file:
  # execute test.sh
  # filter out not processed case
# Each filtered file:
  # search Action for usage in project, exclude its filename
  # Each file that using action:
    # execute test2.sh











