#!/usr/bin/env bash

# Regression tests for semantic benchmark validation and eval evidence confinement.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/scripts/validate-evals.sh"
failures=0
runtime_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-factory-eval-tests.XXXXXX")"
trap 'rm -rf "$runtime_root"' EXIT

pass() { printf 'OK   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; failures=$((failures + 1)); }

assert_failure() {
  local root="$1"
  local marker="$2"
  local label="$3"
  local output
  local rc

  output="$(bash "$root/scripts/validate-evals.sh" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    pass "$label fails"
  else
    fail "$label should fail"
  fi
  if printf '%s\n' "$output" | grep -Fq "$marker"; then
    pass "$label reports the intended failure"
  else
    fail "$label missing marker: $marker"
  fi
}

if bash "$VALIDATOR" >/dev/null 2>&1; then
  pass 'persisted eval evidence validates'
else
  fail 'persisted eval evidence should validate before negative mutations'
fi

copy="$runtime_root/factory"
mkdir -p "$copy"
cp -R "$ROOT/." "$copy"
rm -rf "$copy/.git"

benchmark="$copy/skills/agent-workspace-builder/evals/runs/iteration-1/benchmark.json"
benchmark_backup="$runtime_root/benchmark.json"
cp "$benchmark" "$benchmark_backup"

python3 - "$benchmark" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["runs"].append(data["runs"][0])
path.write_text(json.dumps(data, indent=2) + "\n")
PY
assert_failure "$copy" 'benchmark run identities are unique' 'duplicate benchmark run'
cp "$benchmark_backup" "$benchmark"

python3 - "$benchmark" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["metadata"]["timestamp"] = '<img src=x onerror="alert(1)">'
path.write_text(json.dumps(data, indent=2) + "\n")
PY
assert_failure "$copy" 'benchmark timestamp matches the latest persisted run completion' 'injected benchmark timestamp'
cp "$benchmark_backup" "$benchmark"

notes="$copy/skills/agent-workspace-builder/evals/runs/iteration-1/analysis-notes.json"
notes_backup="$runtime_root/analysis-notes.json"
cp "$notes" "$notes_backup"
python3 - "$notes" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data.append("tampered analyzer note")
path.write_text(json.dumps(data, indent=2) + "\n")
PY
assert_failure "$copy" 'benchmark embeds the persisted analyzer notes exactly' 'tampered analyzer notes'
cp "$notes_backup" "$notes"

viewer="$copy/skills/agent-workspace-builder/evals/runs/iteration-1/review.html"
viewer_backup="$runtime_root/review.html"
cp "$viewer" "$viewer_backup"
python3 - "$viewer" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace("script-src-attr 'none'", "script-src-attr 'unsafe-inline'", 1))
PY
assert_failure "$copy" 'static viewer contains every hardening marker' 'weakened viewer CSP'
cp "$viewer_backup" "$viewer"

definitions="$copy/skills/agent-workspace-builder/evals/evals.json"
definitions_backup="$runtime_root/evals.json"
cp "$definitions" "$definitions_backup"
python3 - "$definitions" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["evals"][2]["files"] = ["../../../../../../etc/hosts"]
path.write_text(json.dumps(data, indent=2) + "\n")
PY
assert_failure "$copy" 'input is normalized and confined to evals/files' 'traversing eval input'
cp "$definitions_backup" "$definitions"

extra_eval="$copy/skills/agent-workspace-builder/evals/runs/iteration-1/eval-999-extra"
mkdir -p "$extra_eval"
assert_failure "$copy" 'iteration topology contains exactly the defined eval directories and derived artifacts' 'unexpected eval directory'
rm -rf "$extra_eval"

manifest="$copy/skills/agent-workspace-builder/evals/results/2026-07-11-paired-benchmark.json"
manifest_backup="$runtime_root/manifest.json"
cp "$manifest" "$manifest_backup"
python3 - "$manifest" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["source_commit_scope"] = "tampered"
path.write_text(json.dumps(data, indent=2) + "\n")
PY
assert_failure "$copy" 'exactly matches all canonically derived metadata and hashes' 'tampered manifest metadata'
cp "$manifest_backup" "$manifest"

python3 - "$benchmark" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["runs"][0]["result"]["passed"] += 1
path.write_text(json.dumps(data, indent=2) + "\n")
PY
assert_failure "$copy" 'benchmark run results and expectations match grading evidence' 'tampered benchmark score'
cp "$benchmark_backup" "$benchmark"

python3 - "$benchmark" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["run_summary"]["with_skill"]["pass_rate"]["mean"] = 0
path.write_text(json.dumps(data, indent=2) + "\n")
PY
assert_failure "$copy" 'benchmark summary is derived from persisted grading evidence' 'tampered benchmark summary'
cp "$benchmark_backup" "$benchmark"

transcript="$copy/skills/agent-workspace-builder/evals/runs/iteration-1/eval-1-minimal-native/with_skill/run-1/transcript.md"
mv "$transcript" "$transcript.real"
external_root="/etc"
ln -s "$external_root/hosts" "$transcript"
assert_failure "$copy" 'eval evidence contains no symlink' 'symlinked eval evidence'
rm "$transcript"
mv "$transcript.real" "$transcript"

bad_notes="$runtime_root/bad-notes.json"
python3 - "$bad_notes" <<'PY'
import sys
from pathlib import Path

Path(sys.argv[1]).write_text('{"not": "an array"}\n')
PY
artifact_hashes_before="$(shasum -a 256 \
  "$ROOT/skills/agent-workspace-builder/evals/runs/iteration-1/benchmark.json" \
  "$ROOT/skills/agent-workspace-builder/evals/runs/iteration-1/benchmark.md" \
  "$ROOT/skills/agent-workspace-builder/evals/runs/iteration-1/review.html")"
if bash "$ROOT/scripts/build-eval-artifacts.sh" --notes "$bad_notes" >/dev/null 2>&1; then
  fail 'invalid analyzer notes should fail artifact generation'
else
  pass 'invalid analyzer notes fail artifact generation'
fi
artifact_hashes_after="$(shasum -a 256 \
  "$ROOT/skills/agent-workspace-builder/evals/runs/iteration-1/benchmark.json" \
  "$ROOT/skills/agent-workspace-builder/evals/runs/iteration-1/benchmark.md" \
  "$ROOT/skills/agent-workspace-builder/evals/runs/iteration-1/review.html")"
if [ "$artifact_hashes_before" = "$artifact_hashes_after" ]; then
  pass 'failed artifact generation leaves persisted artifacts unchanged'
else
  fail 'failed artifact generation changed persisted artifacts'
fi

if python3 - "$ROOT" "$runtime_root" <<'PY'
import importlib.util
import sys
from pathlib import Path

root = Path(sys.argv[1])
test_root = Path(sys.argv[2]) / "artifact-publication"
draft_root = test_root / "draft"
target_root = test_root / "target"
draft_root.mkdir(parents=True)
target_root.mkdir(parents=True)

spec = importlib.util.spec_from_file_location(
    "eval_artifact_builder", root / "scripts/build-eval-artifacts.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

pairs = []
for index in range(1, 4):
    draft = draft_root / f"artifact-{index}.txt"
    target = target_root / f"artifact-{index}.txt"
    draft.write_text(f"new-{index}\n")
    target.write_text(f"old-{index}\n")
    pairs.append((draft, target))

try:
    module.publish_artifacts(pairs, fail_after=1)
except RuntimeError as exc:
    if "simulated publication failure" not in str(exc):
        raise
else:
    raise SystemExit("simulated publication failure was not raised")

for index, (_, target) in enumerate(pairs, start=1):
    if target.read_text() != f"old-{index}\n":
        raise SystemExit(f"artifact {index} was not rolled back")
PY
then
  pass 'mid-publication failure rolls back every eval artifact'
else
  fail 'mid-publication failure should roll back every eval artifact'
fi

if [ "$failures" -ne 0 ]; then
  printf '\nEval regression tests failed with %s issue(s).\n' "$failures" >&2
  exit 1
fi

printf '\nEval regression tests passed.\n'
