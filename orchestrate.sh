#!/bin/bash
# Midget C4 — live crew orchestrator.
# Runs on the HOST. Dispatches LLM agents inside containers with
# role-specific mount constraints. Requires ANTHROPIC_API_KEY.
#
# Flow:
#   1. Stage sample repo with deliberate defect + diff
#   2. Watchdog-midget: review diff, write tests, report verdict
#   3. Weaver-midget: review diff, analyse quality, report verdict
#   4. Sentinel-midget: review diff, scan for security, report verdict
#   5. Orchestrator: collect all reviews, print triangulated verdict
#
# Usage: make crew
#        ANTHROPIC_API_KEY must be set.

set -e

IMAGE="midget-poc"
VOL_REPO="crew-live-repo-$$"
VOL_JOBS="crew-live-jobs-$$"
CREW_DIR="$(cd "$(dirname "$0")" && pwd)/crew"

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "ERROR: ANTHROPIC_API_KEY not set" >&2
    exit 1
fi

cleanup() {
    docker volume rm "$VOL_REPO" "$VOL_JOBS" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo ""
echo "=== Live Crew Orchestration ==="
echo ""

# 1. Create volumes + stage defective repo
echo "--- Stage ---"
docker volume create "$VOL_REPO" >/dev/null 2>&1
docker volume create "$VOL_JOBS" >/dev/null 2>&1

docker run --rm --entrypoint bash -u root \
    -v "$VOL_REPO":/opt/repo \
    -v "$VOL_JOBS":/opt/jobs \
    "$IMAGE" \
    -c "mkdir -p /opt/jobs/artifacts /opt/jobs/incoming /opt/jobs/done && \
        chown -R 1000:1000 /opt/repo /opt/jobs"

# Sample code with off-by-one bug
docker run --rm -i --entrypoint bash \
    -v "$VOL_REPO":/opt/repo \
    "$IMAGE" \
    -c "cat > /opt/repo/calc.py" << 'PYEOF'
def average(numbers):
    """Return the average of a list of numbers."""
    total = sum(numbers)
    return total / (len(numbers) - 1)  # BUG: off-by-one, should be len(numbers)

def clamp(value, low, high):
    """Clamp value between low and high."""
    if value < low:
        return low
    if value > high:
        return high
    return value
PYEOF

docker run --rm -i --entrypoint bash \
    -v "$VOL_JOBS":/opt/jobs \
    "$IMAGE" \
    -c "cat > /opt/jobs/artifacts/diff.patch" << 'DIFFEOF'
--- /dev/null
+++ b/calc.py
@@ -0,0 +1,12 @@
+def average(numbers):
+    """Return the average of a list of numbers."""
+    total = sum(numbers)
+    return total / (len(numbers) - 1)  # BUG: off-by-one
+
+def clamp(value, low, high):
+    """Clamp value between low and high."""
+    if value < low:
+        return low
+    if value > high:
+        return high
+    return value
DIFFEOF

echo "  repo + diff staged"

# Helper: run an LLM crew member
run_crew() {
    local ROLE=$1
    local PROMPT_FILE=$2
    local REPO_MODE=$3  # "rw" or "ro"

    echo ""
    echo "--- $ROLE ---"

    local REPO_MOUNT="$VOL_REPO:/opt/repo"
    if [ "$REPO_MODE" = "ro" ]; then
        REPO_MOUNT="$VOL_REPO:/opt/repo:ro"
    fi

    # Copy the role prompt into the jobs volume
    docker run --rm -i --entrypoint bash \
        -v "$VOL_JOBS":/opt/jobs \
        "$IMAGE" \
        -c "cat > /opt/jobs/artifacts/${ROLE}-prompt.md" < "$PROMPT_FILE"

    # Run claude inside the container with the role prompt
    docker run --rm \
        -v "$REPO_MOUNT" \
        -v "$VOL_JOBS":/opt/jobs \
        -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
        -e MIDGET_JOBS_DIR=/opt/jobs \
        "$IMAGE" \
        bash -c "claude -p \"\$(cat /opt/jobs/artifacts/${ROLE}-prompt.md)

Here is the diff to review:

\$(cat /opt/jobs/artifacts/diff.patch)

Here is the source file:

\$(cat /opt/repo/calc.py)

Write your YAML review to /opt/jobs/artifacts/${ROLE}-review.yaml\" \
            --dangerously-skip-permissions \
            --allowedTools 'Bash Read Write' \
            2>&1"

    echo "  $ROLE complete"
}

# 2-4. Run crew members sequentially
run_crew "watchdog" "$CREW_DIR/watchdog.md" "ro"
run_crew "weaver"   "$CREW_DIR/weaver.md"   "ro"
run_crew "sentinel" "$CREW_DIR/sentinel.md" "ro"

# 5. Collect and display results
echo ""
echo "--- Triangulation ---"
echo ""

for ROLE in watchdog weaver sentinel; do
    echo "=== $ROLE ==="
    docker run --rm --entrypoint bash \
        -v "$VOL_JOBS":/opt/jobs \
        "$IMAGE" \
        -c "cat /opt/jobs/artifacts/${ROLE}-review.yaml 2>/dev/null || echo 'NO REVIEW FOUND'"
    echo ""
done

# Count verdicts
PASS_COUNT=0
FAIL_COUNT=0
MISSING_COUNT=0

for ROLE in watchdog weaver sentinel; do
    VERDICT=$(docker run --rm --entrypoint bash \
        -v "$VOL_JOBS":/opt/jobs \
        "$IMAGE" \
        -c "grep 'verdict:' /opt/jobs/artifacts/${ROLE}-review.yaml 2>/dev/null | head -1 | awk '{print \$2}'" 2>/dev/null)
    case "$VERDICT" in
        pass) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        fail) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        *) MISSING_COUNT=$((MISSING_COUNT + 1)) ;;
    esac
done

echo "=== Verdict ==="
echo "  pass: $PASS_COUNT  fail: $FAIL_COUNT  missing: $MISSING_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "  TRIANGULATED VERDICT: FAIL (defect detected by crew)"
elif [ "$MISSING_COUNT" -gt 0 ]; then
    echo "  TRIANGULATED VERDICT: INCOMPLETE ($MISSING_COUNT reviews missing)"
else
    echo "  TRIANGULATED VERDICT: PASS"
fi

echo ""
echo "Reviews saved to volume $VOL_JOBS at /opt/jobs/artifacts/"
echo "To inspect: docker run --rm --entrypoint bash -v $VOL_JOBS:/opt/jobs $IMAGE -c 'ls -la /opt/jobs/artifacts/'"
echo ""
