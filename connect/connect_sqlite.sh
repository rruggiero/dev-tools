#!/bin/bash
#
# vim: ts=4 ai
# $Id: connect.sh,v 1.2 2025/06/21 23:17:39 rick Exp $
#
DB="../data/f1db.db"
PROGNAME=$(basename "$0")
ERRLOG="./sqlite3_error.log"

PROGNAME=$(basename "$0")

usage() {
    cat <<EOF
Usage: ${PROGNAME} [SQL statement or meta-command]
Examples:
  ${PROGNAME} .tables
  ${PROGNAME} SELECT * FROM mytable
  ${PROGNAME} describe .table mytable
  ${PROGNAME} describe .indexes mytable
  ${PROGNAME} describe .fkeys mytable
  ${PROGNAME} describe .schema_version
  ${PROGNAME} describe .integrity_check
  ${PROGNAME} -h         Show this usage message
  ${PROGNAME} -help      More detailed usage help
  ${PROGNAME} --help     More detailed usage help
EOF
    exit 0
}

longUsage() {
    cat <<EOF
Usage:   ${PROGNAME} [SQL statement or meta-command]
------------------------------------------------------
Examples:
  ${PROGNAME} .tables
      - List all tables in the database

  ${PROGNAME} SELECT * FROM mytable
      - Run an SQL query and show results

  ${PROGNAME} describe .table mytable
      - Show table columns/structure for 'mytable'

  ${PROGNAME} describe .indexes mytable
      - Show indexes for 'mytable'

  ${PROGNAME} describe .fkeys mytable
      - Show foreign keys for 'mytable'

  ${PROGNAME} describe .schema_version
      - Show database schema version

  ${PROGNAME} describe .integrity_check
      - Run SQLite integrity check

  ${PROGNAME} -h
      - Show this help message

  ${PROGNAME} -help, --help
      - Show more detailed help message

Notes:
  * Arguments starting with '.' (like .tables) are passed directly to sqlite3.
  * SQL statements without a trailing semicolon are auto-appended one.
  * For 'describe' helpers, tablename is required except for .schema_version and .integrity_check.

EOF
    exit 0
}

# Check help switches up top
case "$1" in
    -h)    usage ;;
    -help|--help) longUsage ;;
esac

describe() {
    case "$1" in
        .table)
            if [ -z "$2" ]; then
                echo -e "\e[91mERROR: No table specified for describe .table\e[0m" >&2
                exit 2
            fi
            echo "PRAGMA table_info($2);"
            ;;
        .indexes)
            if [ -z "$2" ]; then
                echo -e "\e[91mERROR: No table specified for describe .indexes\e[0m" >&2
                exit 2
            fi
            echo "PRAGMA index_list($2);"
            ;;
        .fkeys)
            if [ -z "$2" ]; then
                echo -e "\e[91mERROR: No table specified for describe .fkeys\e[0m" >&2
                exit 2
            fi
            echo "PRAGMA foreign_key_list($2);"
            ;;
        .schema_version)
            echo "PRAGMA schema_version;"
            ;;
        .integrity_check)
            echo "PRAGMA integrity_check;"
            ;;
        .tables)
            echo ".tables"
            ;;
        *)
            echo -e "\e[91mERROR: Unknown describe command: $1\e[0m" >&2
            usage
            ;;
    esac
}

if [[ $# -eq 0 ]]; then
	echo -e "${PROGNAME}: calling sqlite3..."
	sqlite3 "$DB"
	echo -e "${PROGNAME}: exiting.\n"
    exit 0
fi

args=("$@")

if [[ "${args[0]}" == "describe" ]]; then
    if [[ -z "${args[1]}" ]]; then
        echo -e "\e[91mERROR: No describe sub-command specified.\e[0m" >&2
        usage
    fi
    # Special: describe .tables → just run .tables directly
    if [[ "${args[1]}" == ".tables" ]]; then
        sqlite3 "$DB" ".tables"
        exit $?
    fi
    # Compose PRAGMA/meta-command
    desc_cmd=$(describe "${args[1]}" "${args[2]}")
    if [[ "${args[1]}" == .* ]]; then
        sqlite3 "$DB" "$desc_cmd"
    else
        output=$(sqlite3 "$DB" 2>"$ERRLOG" <<EOF
.headers on
.mode column
$desc_cmd
EOF
        )
        exitcode=$?
        if [[ $exitcode -ne 0 ]]; then
            echo -e "\e[91mSQLite error occurred:\e[0m"
            cat "$ERRLOG"
            echo -e "\e[93mTip:\e[0m There was a problem with your describe command. Check your arguments or table name."
            exit $exitcode
        else
            echo "$output"
        fi
    fi
    exit 0
fi

if [[ "${args[0]}" == .* ]]; then
    sqlite3 "$DB" "${args[@]}"
    exit $?
fi

sql_cmd="$*"
[[ "$sql_cmd" != *\; ]] && sql_cmd="${sql_cmd};"

output=$(sqlite3 "$DB" 2>"$ERRLOG" <<EOF
.headers on
.mode column
$sql_cmd
EOF
)
exitcode=$?
if [[ $exitcode -ne 0 ]]; then
    echo -e "\e[91mSQLite error occurred:\e[0m"
    cat "$ERRLOG"
    # Only suggest for SQL commands (not for meta-commands)
    if echo "$output" | grep -qi "no such table"; then
        echo -e "\e[93mTip:\e[0m The table you referenced does not exist. Use '.tables' to see available tables."
    elif echo "$output" | grep -qi "syntax error"; then
        echo -e "\e[93mTip:\e[0m There is a syntax error in your SQL. Double-check your command."
    fi
    exit $exitcode
else
    echo "$output"
fi

