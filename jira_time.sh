#!/bin/bash
# This script queries Jira for issues in the "B.sure Analytics" project with worklogs for a given date,
# then prints each issue's key, summary, time logged by the specified WORKLOG_AUTHOR on that date.
# If you pass "compact" as an argument, it will omit printing comments.

# --- Color definitions ---
ORANGE='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# --- Configuration ---
JIRA_BASE_URL="your-jira-instance-url"
JIRA_USER="your-email@example.com"
JIRA_API_TOKEN="your-jira-api-token"
WORKLOG_AUTHOR="your-jira-account-id"

# --- Parse arguments: find REPORT_DATE (first non-"compact" arg) and set COMPACT=true if "compact" was passed ---
COMPACT=false
REPORT_DATE=""

for arg in "$@"; do
  if [ "$arg" = "compact" ]; then
    COMPACT=true
  else
    if [ -z "$REPORT_DATE" ]; then
      REPORT_DATE="$arg"
    fi
  fi
done

# If no date was provided, default to today
if [ -z "$REPORT_DATE" ]; then
  REPORT_DATE=$(date +%Y-%m-%d)
fi

# --- Build JQL ---
JQL='project = "B.sure Analytics" and timespent is not EMPTY and worklogDate = "'"$REPORT_DATE"'" and worklogAuthor = '"$WORKLOG_AUTHOR"
ENCODED_JQL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$JQL'''))")

# Fetch key + summary up front
SEARCH_URL="$JIRA_BASE_URL/rest/api/3/search/jql?jql=$ENCODED_JQL&fields=key,summary&maxResults=1000"

echo "Fetching issues (key + summary) for $REPORT_DATE (compact=$COMPACT)..."
raw_response=$(curl -s -u "$JIRA_USER:$JIRA_API_TOKEN" \
  -X GET -H "Content-Type: application/json" "$SEARCH_URL")

# Parse "key<TAB>summary" lines into two parallel indexed arrays
declare -a ISSUE_KEYS
declare -a ISSUE_TITLES

while IFS=$'\t' read -r key title; do
  ISSUE_KEYS+=("$key")
  ISSUE_TITLES+=("$title")
done < <(
  echo "$raw_response" | jq -r '.issues[] | "\(.key)\t\(.fields.summary)"'
)

# Prepare arrays for later
declare -a ISSUE_SECONDS    # ISSUE_SECONDS[i] = seconds logged for ISSUE_KEYS[i]
declare -a VALID_INDICES    # indices i where ISSUE_SECONDS[i] > 0
total_seconds=0

# --- Loop over each issue to compute time logged today ---
for i in "${!ISSUE_KEYS[@]}"; do
  key="${ISSUE_KEYS[$i]}"

  # Fetch both worklog and comment fields (we need worklog to compute time)
  fetch_url="$JIRA_BASE_URL/rest/api/3/issue/$key?expand=worklog&fields=worklog,comment"
  issue_json=$(curl -s -u "$JIRA_USER:$JIRA_API_TOKEN" \
    -X GET -H "Content-Type: application/json" "$fetch_url")

  # Compute total seconds logged today by WORKLOG_AUTHOR
  secs=$(echo "$issue_json" | jq --arg REPORT_DATE "$REPORT_DATE" --arg WORKLOG_AUTHOR "$WORKLOG_AUTHOR" '
    (.fields.worklog.worklogs // [])
    | map(
        select(
          ( .started | split("T")[0] == $REPORT_DATE ) and
          ( .author.accountId == $WORKLOG_AUTHOR )
        )
        | .timeSpentSeconds
      )
    | add // 0
  ')
  secs=${secs:-0}

  if [ "$secs" != "null" ] && [ "$secs" -gt 0 ]; then
    ISSUE_SECONDS[$i]="$secs"
    VALID_INDICES+=("$i")
    total_seconds=$((total_seconds + secs))
  fi
done

# --- Helper: format seconds into hh:mm:ss ---
format_time() {
  local t=$1
  local h=$((t/3600))
  local m=$(((t%3600)/60))
  local s=$((t%60))
  printf "%02dh %02dm %02ds" $h $m $s
}

echo ""
echo "Detailed Time Logged for $REPORT_DATE"
echo "====================================="

# --- For each valid issue, print key, title, time, and (unless compact) comments for that date/author ---
for idx in "${VALID_INDICES[@]}"; do
  key="${ISSUE_KEYS[$idx]}"
  title="${ISSUE_TITLES[$idx]}"
  secs="${ISSUE_SECONDS[$idx]}"
  formatted=$(format_time "$secs")

  echo ""
  echo -e "${ORANGE}$key – $title${NC}: ${BLUE}$formatted${NC}"

  # Only print comments if COMPACT=false
  if [ "$COMPACT" = false ]; then
    # Fetch comments only
    fetch_comments_url="$JIRA_BASE_URL/rest/api/3/issue/$key?fields=comment"
    issue_json=$(curl -s -u "$JIRA_USER:$JIRA_API_TOKEN" \
      -X GET -H "Content-Type: application/json" "$fetch_comments_url")

    comments=$(echo "$issue_json" | jq -r --arg REPORT_DATE "$REPORT_DATE" --arg WORKLOG_AUTHOR "$WORKLOG_AUTHOR" '
      .fields.comment.comments[]?
      | select(
          ( .author.accountId == $WORKLOG_AUTHOR ) and
          ( (.created | split("T")[0]) == $REPORT_DATE )
        )
      | .body
    ')

    if [ -n "$comments" ]; then
      echo "Comments by $WORKLOG_AUTHOR on $REPORT_DATE:"
      while IFS= read -r line; do
        echo "  - $line"
      done <<< "$comments"
    fi
  fi
done

echo ""
echo -e "Total Time Logged: ${GREEN}$(format_time $total_seconds)${NC}"