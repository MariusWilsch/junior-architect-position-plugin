#!/bin/bash
# Hippocampus publishing verification script.
#
# Monitors both GitHub Action workflows sequentially, verifies the published
# URL via curl, and opens the browser on success.
#
# Usage: verify_publish.sh <tier> <filename>
#   tier:     "global" or "project/name"
#   filename: filename without .md extension (e.g., "my-guide")
#
# Exit codes:
#   0 = published and verified
#   1 = argument error
#   2 = workflow 1 failed
#   3 = workflow 2 failed
#   4 = curl verification failed

set -euo pipefail

POLL_INTERVAL=15
MAX_POLLS=12  # 12 * 15s = 3 minutes per workflow
HIPPOCAMPUS_ROOT="$HOME/.claude/hippocampus"

# --- Argument validation ---
if [ $# -lt 2 ]; then
  echo "Usage: verify_publish.sh <tier> <filename>"
  echo "  tier:     global | project/name"
  echo "  filename: without .md extension"
  exit 1
fi

TIER="$1"
FILENAME="${2%.md}"  # Strip .md if provided
URL="https://mariuswilsch.github.io/public-wilsch-ai-pages/${TIER}/${FILENAME}"
FILE_PATH="${TIER}/${FILENAME}.md"

# --- Capture pre-deploy etag (before any changes are pushed) ---
PRE_ETAG=$(curl -sI "${URL}?bust=pre-$(date +%s)" 2>/dev/null | grep -i "^etag:" | tr -d '\r' || echo "")
echo "Pre-deploy etag: ${PRE_ETAG:-none (new file)}"

# --- Step 0: Commit and push hippocampus changes ---
echo "Committing and pushing hippocampus changes..."
cd "$HIPPOCAMPUS_ROOT"

# Stage only the target file (avoid committing unrelated changes)
if git diff --quiet -- "$FILE_PATH" && git diff --cached --quiet -- "$FILE_PATH" && ! git ls-files --others --exclude-standard | grep -q "^${FILE_PATH}$"; then
  echo "  No changes to ${FILE_PATH} — skipping commit."
else
  git add "$FILE_PATH"
  git commit -m "docs: publish ${TIER}/${FILENAME}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
  COMMIT_HASH=$(git rev-parse --short HEAD)
  COMMIT_URL="https://github.com/veloxforce/claude-user-configs/commit/${COMMIT_HASH}"
  echo "  Committed: ${FILE_PATH}"
  echo "  Commit: ${COMMIT_URL}"
fi

git push origin HEAD
echo "  Pushed to origin."

# --- Helper: poll a workflow until complete ---
poll_workflow() {
  local repo="$1"
  local workflow_name="$2"
  local label="$3"
  local fail_code="$4"

  echo "Monitoring ${label}..."
  echo "  Repo: ${repo}"
  echo "  Workflow: ${workflow_name}"

  for i in $(seq 1 $MAX_POLLS); do
    local result
    result=$(gh run list --repo "$repo" --workflow "$workflow_name" --limit 1 --json status,conclusion 2>/dev/null)

    local status conclusion
    status=$(echo "$result" | jq -r '.[0].status // "unknown"')
    conclusion=$(echo "$result" | jq -r '.[0].conclusion // "null"')

    if [ "$status" = "completed" ]; then
      if [ "$conclusion" = "success" ]; then
        echo "  ${label} completed successfully."
        return 0
      else
        echo "  ${label} FAILED (conclusion: ${conclusion})"
        exit "$fail_code"
      fi
    fi

    echo "  Poll ${i}/${MAX_POLLS}: status=${status} (waiting ${POLL_INTERVAL}s...)"
    sleep "$POLL_INTERVAL"
  done

  echo "  ${label} timed out after $((MAX_POLLS * POLL_INTERVAL))s"
  exit "$fail_code"
}

# --- Step 1: Monitor Workflow 1 (content sync) ---
poll_workflow \
  "veloxforce/claude-user-configs" \
  "Publish Hippocampus to GitHub Pages" \
  "Workflow 1 (content sync)" \
  2

# --- Step 2: Monitor Workflow 2 (Jekyll deploy) ---
poll_workflow \
  "MariusWilsch/public-wilsch-ai-pages" \
  "Deploy to GitHub Pages" \
  "Workflow 2 (Jekyll deploy)" \
  3

# --- Step 3: Verify content freshness (bypass CDN cache) ---
echo "Verifying published content is fresh..."
echo "  URL: ${URL}"

MAX_RETRIES=6
RETRY_DELAY=15
VERIFIED=false

for attempt in $(seq 1 $MAX_RETRIES); do
  # Cache-bust: unique query string forces Fastly to fetch from origin
  BUST="?v=$(date +%s)"
  HEADERS=$(curl -sI "${URL}${BUST}" 2>/dev/null)
  HTTP_CODE=$(echo "$HEADERS" | head -1 | awk '{print $2}')
  ETAG=$(echo "$HEADERS" | grep -i "^etag:" | tr -d '\r' || echo "")

  if [ "$HTTP_CODE" = "200" ]; then
    # Check if etag changed (content is fresh) or if this is a new file (no pre-etag)
    if [ -z "$PRE_ETAG" ] || [ "$ETAG" != "$PRE_ETAG" ]; then
      echo "  Verified: HTTP ${HTTP_CODE} (content fresh — etag changed)"
      echo "  New etag: ${ETAG}"
      VERIFIED=true
      break
    fi
  fi

  if [ "$attempt" -lt "$MAX_RETRIES" ]; then
    echo "  Attempt ${attempt}/${MAX_RETRIES}: HTTP ${HTTP_CODE} etag=${ETAG:-none} (waiting ${RETRY_DELAY}s for origin update...)"
    sleep "$RETRY_DELAY"
  else
    if [ "$HTTP_CODE" = "200" ]; then
      echo "  Warning: HTTP 200 but etag unchanged after ${MAX_RETRIES} attempts — CDN may be stale"
      echo "  Opening anyway (content may take up to 10 min to propagate)"
      VERIFIED=true
    else
      echo "  FAILED after ${MAX_RETRIES} attempts: HTTP ${HTTP_CODE}"
      echo "  Check: Is the URL path correct? Did both workflows complete?"
      exit 4
    fi
  fi
done

# --- Step 4: Auto-open browser (commit + published URL) ---
echo "Opening in browser..."
sleep 1
if [ -n "${COMMIT_URL:-}" ]; then
  open "$COMMIT_URL"
  echo "  Opened commit: ${COMMIT_URL}"
fi
open "$URL"
echo "  Opened published: ${URL}"

echo ""
echo "Published successfully: ${URL}"
if [ -n "${COMMIT_URL:-}" ]; then
  echo "Commit: ${COMMIT_URL}"
fi
