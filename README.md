# Jira Time Tracker

A command-line tool to track and display time logged in Jira for a specific date.

## Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd jira-time-tracker
```

2. Add your Jira credentials in jira_time.sh:
```bash
JIRA_BASE_URL="your-jira-instance-url"
JIRA_USER="your-email@example.com"
JIRA_API_TOKEN="your-jira-api-token"
WORKLOG_AUTHOR="your-jira-account-id"
```

3. Run the installation script:
```bash
./install.sh
```

This will install the `jtime` command globally.

## Usage

Basic usage:
```bash
jtime [date]
```

Options:
- `date`: Optional date in YYYY-MM-DD format (defaults to today)
- `compact`: Add this flag to omit comments in the output

Examples:
```bash
# Show today's time entries
jtime

# Show time entries for a specific date
jtime 2024-03-20

# Show time entries without comments
jtime compact

# Show time entries for a specific date without comments
jtime 2024-03-20 compact
```

## Requirements

- Bash
- Python 3 (for URL encoding)
- `jq` (for JSON parsing)
- `curl` (for API requests)

## Configuration

The tool uses the following environment variables from `.env`:
- `JIRA_BASE_URL`: Your Jira instance URL
- `JIRA_USER`: Your Jira email
- `JIRA_API_TOKEN`: Your Jira API token
- `WORKLOG_AUTHOR`: Your Jira account ID
