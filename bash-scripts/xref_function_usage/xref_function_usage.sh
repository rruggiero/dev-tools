#!/bin/bash
#
# vim: ts=4 ai
#
# $Id: xref_function_usage.sh,v 1.2 2025/06/19 02:27:56 rick Exp $
#
PROGNAME=$(basename $0)

spinner_pid=""

start_spinner() {
	local delay=0.1
	local spinstr='|/-\'
	# Print spinner to stderr to avoid mixing with output
	(
		while :; do
			for i in $(seq 0 3); do
				printf "\r[%c] Scanning..." "${spinstr:$i:1}" >&2
				sleep $delay
			done
		done
	) &
	spinner_pid=$!
	disown
}

stop_spinner() {
	if [[ -n "$spinner_pid" ]]; then
		kill "$spinner_pid" 2>/dev/null
		wait "$spinner_pid" 2>/dev/null
		spinner_pid=""
		printf "\r%-20s\r" " " >&2	# Clear the spinner line
	fi
}

show_help() {
cat <<EOF
${PROGNAME} - Cross-reference function usage in your codebase.

Usage:
  ${PROGNAME} -f <file> [-p <path>] [-u]
      [-x <exclude-path> ...] [-X <exclude-name> ...]

Required:
      -f <file>      File to extract function definitions from.

Optional:
      -p <path>      Directory to scan for usages (default: .)
      -u             Only print functions that are UNUSED.
      -x <exclude>   Exclude all files and folders whose path starts with this value.
Can repeat (e.g. -x /foo/old -x ./bar/tmp).
      -X <name>      Exclude all files/folders whose NAME matches (wildcards ok).
E.g. -X node_modules -X '*.min.js' -X .git -X old*
      -h             Show this help and exit.

Examples:
  # Basic: Find usages of all functions defined in mylib.php, scan whole tree
    ${PROGNAME} -f mylib.php

  # Limit search to ./src, skip 'old' and 'RCS' folders everywhere
    ${PROGNAME} -f mylib.php -p ./src -X old -X RCS

  # Exclude by path (absolute or relative)
    ${PROGNAME} -f foo.js -x ./legacy -x /tmp/bar

  # Show only unused functions (no usages found)
    ${PROGNAME} -f lib.py -u

Notes:
  - Supports PHP, JavaScript, Python, and C by default (simple regex based).
  - All output lines are trimmed to fit typical terminal widths.
  - Exclusion with -X applies everywhere in the tree.
  - Exclusion with -x applies to any path that starts with the value.

See also: the man page (man xref_function_usage)
EOF
exit 0
}

SRC_FILE=""
SEARCH_PATH="."
UNUSED_ONLY=0
MAXLEN=60
EXCLUDES=()
EXCLNAMES=()

while getopts ":f:p:ux:X:h" opt; do
	case $opt in
	f) SRC_FILE="$OPTARG" ;;
	p) SEARCH_PATH="$OPTARG" ;;
	u) UNUSED_ONLY=1 ;
		 echo "${PROGNAME}: *** Unused functions..." ;;
	x) EXCLUDES+=("$OPTARG") ;;
	X) EXCLNAMES+=("$OPTARG") ;;
	h) show_help ;;
	*) show_help ;;
	esac
done

if [[ -z "$SRC_FILE" || ! -f "$SRC_FILE" ]]; then
	echo "Error: -f <file> is required and must exist."
	exit 1
fi


FUNCLIST=($(grep -oP 'function[ \t]+([a-zA-Z_][a-zA-Z0-9_]*)' "$SRC_FILE" | awk '{print $2}' | sort | uniq))

if [[ ${#FUNCLIST[@]} -eq 0 ]]; then
	echo "No functions found in $SRC_FILE."
	exit 0
fi

# --- Compose find command for search files with exclusions ---
find_args=( "$SEARCH_PATH" )
# Exclude by name/pattern
for name in "${EXCLNAMES[@]}"; do
	find_args+=( -type d -name "$name" -prune -o )
done
find_args+=( -type f )
# Exclude by extension
for pattern in zip tar gz bz2 xz rar 7z jpg jpeg png gif ico mp3 mp4 mov exe dll bin pdf; do
	find_args+=( ! -name "*.${pattern}" )
done
# User-specified exclusions (by path prefix)
for excl in "${EXCLUDES[@]}"; do
	find_args+=( ! -path "$excl*" )
done

start_spinner

# Generate list of files to search
SEARCH_FILES=()
while IFS= read -r f; do SEARCH_FILES+=("$f"); done < <(find "${find_args[@]}" 2>/dev/null)

for fname in "${FUNCLIST[@]}"; do
	grep_hits=$(grep -n -E "$fname[[:space:]]*\(" "${SEARCH_FILES[@]}" 2>/dev/null | grep -v "function $fname")
	if [[ $UNUSED_ONLY -eq 1 ]]; then
	if [[ -z "$grep_hits" ]]; then
		echo "$fname"
	fi
	else
	if [[ -z "$grep_hits" ]]; then
		printf "Function: %-30s	[UNUSED]\n" "$fname"
	else
		printf "Function: %s\n" "$fname"
		while IFS= read -r line; do
		fileline=${line%%:*}
		rest=${line#*:}
		lineno=${rest%%:*}
		code=${rest#*:}
		trunc="${code:0:$MAXLEN}"
		[[ ${#code} -gt $MAXLEN ]] && trunc="${trunc}..."
		printf "	- %s:%s: %s\n" "$fileline" "$lineno" "$trunc"
		done <<< "$grep_hits"
	fi
	echo
	fi
done

stop_spinner
