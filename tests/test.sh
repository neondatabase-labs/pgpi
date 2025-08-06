env $(grep -v '^#' "$(dirname "$0")/.env" | xargs) ruby "$(dirname "$0")/test.rb"
