set -euo pipefail
# Allow up to ~1 GB per field (Open Food Facts can have huge text fields)
export CSVKIT_FIELD_SIZE_LIMIT=$((1024 * 1024 * 1024))

INGREDIENT=""
DATA_DIR=""
CSV=""

usage() {
  echo "Usage: $0 -i \"<ingredient>\" -d /path/to/folder"
  echo "  -i ingredient to search (case-insensitive)"
  echo "  -d folder containing products.csv (tab-separated)"
  echo "  -h show help"
}

# Parse flags
while getopts ":i:d:h" opt; do
  case "$opt" in
    i) INGREDIENT="$OPTARG" ;;
    d) DATA_DIR="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# Validate inputs
[ -z "${INGREDIENT:-}" ] && { echo "ERROR: -i <ingredient> is required" >&2; usage; exit 1; }
[ -z "${DATA_DIR:-}" ] && { echo "ERROR: -d /path/to/folder is required" >&2; usage; exit 1; }

CSV="$DATA_DIR/products.csv"
[ -s "$CSV" ] || { echo "ERROR: $CSV not found or empty." >&2; exit 1; }

# Ensure csvkit tools exist
for cmd in csvcut csvgrep csvformat; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd not found. Install csvkit." >&2; exit 1; }
done

# Normalize potential CRLFs to avoid parsing surprises
tmp_csv="$(mktemp)"
tr -d '\r' < "$CSV" > "$tmp_csv"

# Core pipeline: select -> filter -> project -> TSV -> drop header
tmp_matches="$(mktemp)"
csvcut -t -c ingredients_text,product_name,code "$tmp_csv" \
| csvgrep -t -c ingredients_text -r "(?i)${INGREDIENT}" \
| csvcut -c product_name,code \
| csvformat -T \
| tail -n +2 \
| tee "$tmp_matches"

# Summary
count="$(wc -l < "$tmp_matches" | tr -d ' ')"
echo "----"
echo "Found ${count} product(s) containing: \"${INGREDIENT}\""

# Cleanup
rm -f "$tmp_csv" "$tmp_matches"
