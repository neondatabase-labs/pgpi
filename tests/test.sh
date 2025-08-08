env $(grep -v -s '^#' "$(dirname "$0")/.env" | xargs) ruby "$(dirname "$0")/test.rb" "$@"
