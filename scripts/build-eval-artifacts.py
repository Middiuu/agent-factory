#!/usr/bin/env python3
"""Build a truthful benchmark and a hardened static viewer from eval evidence."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


def load_validator(root: Path) -> Any:
    path = root / "scripts/validate-evals.py"
    spec = importlib.util.spec_from_file_location("agent_factory_eval_validator", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build_workspace_review(outputs_dir: Path) -> str:
    workspace = outputs_dir / "workspace"
    lines = ["# Persisted workspace artifacts", ""]
    for path in sorted(workspace.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(workspace)
        lines.extend([f"===== {relative} =====", ""])
        try:
            content = path.read_text(encoding="utf-8")
            lines.extend([content, ""])
        except UnicodeDecodeError:
            lines.extend([f"Binary file: {path.stat().st_size} bytes", ""])
    return "\n".join(lines)


def prepare_viewer_staging(iteration: Path, staging: Path) -> None:
    for eval_dir in sorted(iteration.glob("eval-*")):
        metadata = json.loads((eval_dir / "eval_metadata.json").read_text(encoding="utf-8"))
        for configuration in ("with_skill", "without_skill"):
            for run_dir in sorted((eval_dir / configuration).glob("run-*")):
                relative = Path(eval_dir.name) / configuration / run_dir.name
                target = staging / relative
                (target / "outputs").mkdir(parents=True, exist_ok=True)
                (target / "eval_metadata.json").write_text(
                    json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8",
                )
                (target / "outputs/workspace-review.md").write_text(
                    build_workspace_review(run_dir / "outputs"),
                    encoding="utf-8",
                )
                shutil.copy2(run_dir / "grading.json", target / "grading.json")


def prepare_aggregation_staging(iteration: Path, staging: Path) -> None:
    """Normalize optional null metrics for the upstream aggregator without changing evidence."""
    for eval_dir in sorted(iteration.glob("eval-*")):
        target_eval = staging / eval_dir.name
        target_eval.mkdir(parents=True, exist_ok=True)
        shutil.copy2(eval_dir / "eval_metadata.json", target_eval / "eval_metadata.json")
        for configuration in ("with_skill", "without_skill"):
            for run_dir in sorted((eval_dir / configuration).glob("run-*")):
                target = target_eval / configuration / run_dir.name
                (target / "outputs").mkdir(parents=True, exist_ok=True)
                grading = json.loads((run_dir / "grading.json").read_text(encoding="utf-8"))
                if grading.get("timing") is None:
                    grading["timing"] = {}
                if grading.get("execution_metrics") is None:
                    grading["execution_metrics"] = {}
                (target / "grading.json").write_text(
                    json.dumps(grading, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8",
                )
                shutil.copy2(run_dir / "transcript.md", target / "transcript.md")
                (target / "outputs/workspace-review.md").write_text(
                    build_workspace_review(run_dir / "outputs"),
                    encoding="utf-8",
                )


def harden_upstream_viewer(tool_dir: Path) -> None:
    generator = tool_dir / "generate_review.py"
    source = generator.read_text(encoding="utf-8")
    if "from __future__ import annotations" not in source:
        marker = '"""\n\nimport argparse'
        if marker not in source:
            raise RuntimeError("upstream viewer module header changed")
        source = source.replace(
            marker,
            '"""\n\nfrom __future__ import annotations\n\nimport argparse',
            1,
        )
    old = "    data_json = json.dumps(embedded)"
    new = (
        "    data_json = (json.dumps(embedded)"
        ".replace('&', '\\\\u0026').replace('<', '\\\\u003c').replace('>', '\\\\u003e'))"
    )
    if old not in source:
        raise RuntimeError("upstream viewer serialization hook changed")
    generator.write_text(source.replace(old, new), encoding="utf-8")

    template = tool_dir / "viewer.html"
    html = template.read_text(encoding="utf-8")

    def replace_required(old: str, new: str, label: str, count: int = 1) -> None:
        nonlocal html
        if html.count(old) != count:
            raise RuntimeError(f"upstream viewer {label} hook changed")
        html = html.replace(old, new)

    html = re.sub(r'^\s*<link[^>]+(?:fonts\.googleapis|fonts\.gstatic)[^>]*>\n?', '', html, flags=re.MULTILINE)
    html = re.sub(r'^\s*<script[^>]+cdn\.sheetjs\.com[^>]*></script>\n?', '', html, flags=re.MULTILINE)
    replace_required(
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
        '  <meta http-equiv="Content-Security-Policy" '
        'content="default-src \'none\'; style-src \'unsafe-inline\'; '
        'script-src \'nonce-agent-factory-viewer\'; script-src-attr \'none\'; '
        'img-src data:; connect-src \'none\'; object-src \'none\'; base-uri \'none\'; form-action \'none\'">',
        "CSP",
    )
    html = html.replace("'Lora', Georgia, serif", "Georgia, serif")
    html = html.replace("'Poppins', sans-serif", "system-ui, sans-serif")
    underscore_regex = "/" + "_" + "/g"
    html = html.replace(f'.replace({underscore_regex}, " ")', '.split("_").join(" ")')
    replace_required("Crashes During Execution", "Failed validator attempts", "error label")
    replace_required(
        "paste into Claude Code",
        "keep it with this coding-agent task",
        "header copy",
    )
    replace_required(
        "Go back to your Claude Code session and tell Claude you're done reviewing.",
        "Return to your coding-agent task when the review is complete.",
        "completion copy",
    )
    replace_required(
        "  <script>\n    // ---- Embedded data",
        '  <script nonce="agent-factory-viewer">\n    // ---- Embedded data',
        "script nonce",
    )
    replace_required(
        '<button class="view-tab active" onclick="switchView(\'outputs\')">',
        '<button class="view-tab active" data-view="outputs">',
        "outputs tab",
    )
    replace_required(
        '<button class="view-tab" onclick="switchView(\'benchmark\')">',
        '<button class="view-tab" data-view="benchmark">',
        "benchmark tab",
    )
    replace_required(
        '<div class="grades-toggle" onclick="togglePrevOutputs()">',
        '<div class="grades-toggle" id="prev-outputs-toggle">',
        "previous outputs toggle",
    )
    replace_required(
        '<div class="grades-toggle" onclick="toggleGrades()">',
        '<div class="grades-toggle" id="grades-toggle">',
        "grades toggle",
    )
    replace_required(' onclick="navigate(-1)"', "", "previous navigation")
    replace_required(' onclick="showDoneDialog()"', "", "submit navigation")
    replace_required(' onclick="navigate(1)"', "", "next navigation")
    replace_required(
        '<button onclick="closeDoneDialog()">',
        '<button id="close-done-btn">',
        "close dialog",
    )
    replace_required(
        "document.querySelector(`[onclick=\"switchView('${view}')\"]`).classList.add(\"active\");",
        "document.querySelector(`[data-view=\"${view}\"]`).classList.add(\"active\");",
        "tab selector",
    )
    replace_required(
        "      return div.innerHTML;\n    }",
        "      return div.innerHTML;\n"
        "    }\n\n"
        "    function escapeAttr(text) {\n"
        "      return escapeHtml(String(text))\n"
        "        .replace(/\"/g, '&quot;')\n"
        "        .replace(/'/g, '&#39;');\n"
        "    }",
        "attribute escaping",
    )
    replace_required(
        'escapeHtml(exp.evidence || "") + \'">\' + icon',
        'escapeAttr(exp.evidence || "") + \'">\' + icon',
        "assertion evidence attribute",
    )
    replace_required(
        'html += metadata.timestamp + " &mdash; ";',
        'html += escapeHtml(String(metadata.timestamp)) + " &mdash; ";',
        "benchmark timestamp escaping",
    )
    replace_required(
        'html += "Evals: " + metadata.evals_run.join(", ") + " &mdash; ";',
        'html += "Evals: " + metadata.evals_run.map(value => escapeHtml(String(value))).join(", ") + " &mdash; ";',
        "benchmark eval list escaping",
    )
    replace_required(
        'html += (metadata.runs_per_configuration || "?") + " runs per configuration";',
        'html += escapeHtml(String(metadata.runs_per_configuration || "?")) + " runs per configuration";',
        "benchmark run count escaping",
    )
    replace_required("<strong>Tokens</strong>", "<strong>Output characters (proxy)</strong>", "token proxy label")
    replace_required(
        'if (a.time_seconds || b.time_seconds) {',
        'if ((a.time_seconds || b.time_seconds) && metadata.time_metric !== "0 means unavailable; provider timing unavailable") {',
        "summary timing visibility",
    )
    replace_required(
        'const hasTime = runs.some(r => r.result && r.result.time_seconds != null);',
        'const hasTime = metadata.time_metric !== "0 means unavailable; provider timing unavailable" && runs.some(r => r.result && r.result.time_seconds != null);',
        "per-eval timing visibility",
    )
    server_route = "/" + "api/feedback"
    replace_required(
        f'fetch("{server_route}")',
        "staticFeedbackRequest()",
        "offline feedback read",
    )
    replace_required(
        f'fetch("{server_route}", {{',
        "staticFeedbackRequest({",
        "offline feedback write",
        count=2,
    )
    replace_required(
        "    // ---- Init ----\n    async function init() {",
        "    function staticFeedbackRequest() {\n"
        "      return Promise.reject(new Error('static offline viewer'));\n"
        "    }\n\n"
        "    // ---- Init ----\n    async function init() {",
        "offline feedback helper",
    )
    replace_required(
        "    // ---- Start ----\n    init();",
        "    function bindStaticEvents() {\n"
        "      document.querySelectorAll('[data-view]').forEach(button => {\n"
        "        button.addEventListener('click', () => switchView(button.dataset.view));\n"
        "      });\n"
        "      document.getElementById('prev-outputs-toggle').addEventListener('click', togglePrevOutputs);\n"
        "      document.getElementById('grades-toggle').addEventListener('click', toggleGrades);\n"
        "      document.getElementById('prev-btn').addEventListener('click', () => navigate(-1));\n"
        "      document.getElementById('done-btn').addEventListener('click', showDoneDialog);\n"
        "      document.getElementById('next-btn').addEventListener('click', () => navigate(1));\n"
        "      document.getElementById('close-done-btn').addEventListener('click', closeDoneDialog);\n"
        "    }\n\n"
        "    // ---- Start ----\n    bindStaticEvents();\n    init();",
        "event binding",
    )
    template.write_text(html, encoding="utf-8")


def generate_viewer(
    root: Path,
    iteration: Path,
    benchmark_path: Path,
    review_path: Path,
    skill_creator_root: Path,
) -> None:
    upstream_dir = skill_creator_root / "eval-viewer"
    if not (upstream_dir / "generate_review.py").is_file():
        raise RuntimeError(f"skill-creator viewer not found: {upstream_dir}")
    with tempfile.TemporaryDirectory(prefix="agent-factory-eval-viewer-") as temporary:
        temporary_root = Path(temporary)
        staging = temporary_root / "staging"
        tool_dir = temporary_root / "eval-viewer"
        shutil.copytree(upstream_dir, tool_dir)
        prepare_viewer_staging(iteration, staging)
        harden_upstream_viewer(tool_dir)
        subprocess.run(
            [
                sys.executable,
                str(tool_dir / "generate_review.py"),
                str(staging),
                "--skill-name",
                "agent-workspace-builder",
                "--benchmark",
                str(benchmark_path),
                "--static",
                str(review_path),
            ],
            cwd=root,
            check=True,
        )

    review = review_path.read_text(encoding="utf-8")
    if re.search(r'<(?:script|link|img|iframe)[^>]+(?:src|href)="https?://', review, re.IGNORECASE):
        raise RuntimeError("static viewer unexpectedly loads an external resource")
    server_prefix = 'fetch("' + "/" + "api/"
    if server_prefix in review:
        raise RuntimeError("static viewer unexpectedly contains a server API route")
    for required in (
        "script-src 'nonce-agent-factory-viewer'",
        "script-src-attr 'none'",
        'nonce="agent-factory-viewer"',
        "escapeAttr(exp.evidence",
        "Failed validator attempts",
    ):
        if required not in review:
            raise RuntimeError(f"static viewer is missing hardening marker: {required}")
    for forbidden in (
        "onclick=",
        "Claude Code",
        "Crashes During Execution",
        "html += metadata.timestamp",
    ):
        if forbidden in review:
            raise RuntimeError(f"static viewer retains unsafe or inaccurate content: {forbidden}")
    if review.count("</script>") != 1:
        raise RuntimeError("static viewer contains an unsafe script terminator count")
    match = re.search(r"const EMBEDDED_DATA = (.*);\n", review)
    if not match:
        raise RuntimeError("cannot locate embedded viewer data")
    embedded = json.loads(match.group(1))
    benchmark = json.loads(benchmark_path.read_text(encoding="utf-8"))
    if embedded.get("benchmark") != benchmark:
        raise RuntimeError("static viewer benchmark differs from the canonical benchmark")
    if not embedded.get("runs") or any(not run.get("outputs") for run in embedded["runs"]):
        raise RuntimeError("static viewer has a run without recursive workspace output")
    if any(not run.get("grading") for run in embedded["runs"]):
        raise RuntimeError("static viewer has a run without grading evidence")


def publish_artifacts(
    pairs: list[tuple[Path, Path]],
    fail_after: int | None = None,
) -> None:
    """Replace a group of files with rollback if any publication step fails."""
    if not pairs:
        raise ValueError("no artifacts to publish")
    backup_dir = pairs[0][0].parent / "publication-backup"
    backup_dir.mkdir(parents=True, exist_ok=False)
    states: list[tuple[Path, Path, bool]] = []
    for index, (_, target) in enumerate(pairs, start=1):
        existed = target.is_file()
        backup = backup_dir / f"{index}-{target.name}"
        if existed:
            shutil.copy2(target, backup)
        states.append((target, backup, existed))

    try:
        for index, (draft, target) in enumerate(pairs, start=1):
            draft.replace(target)
            if fail_after == index:
                raise RuntimeError(f"simulated publication failure after artifact {index}")
    except Exception as publication_error:
        rollback_errors: list[str] = []
        for target, backup, existed in states:
            try:
                if existed:
                    shutil.copy2(backup, target)
                elif target.exists():
                    target.unlink()
            except OSError as rollback_error:
                rollback_errors.append(f"{target}: {rollback_error}")
        if rollback_errors:
            raise RuntimeError(
                "artifact publication failed and rollback was incomplete: "
                + "; ".join(rollback_errors)
            ) from publication_error
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--notes", type=Path)
    parser.add_argument(
        "--skill-creator-root",
        type=Path,
        default=Path(os.environ.get("SKILL_CREATOR_ROOT", Path.home() / ".agents/skills/skill-creator")),
    )
    args = parser.parse_args()
    root = args.root.resolve()
    eval_root = root / "skills/agent-workspace-builder/evals"
    iteration = root / "skills/agent-workspace-builder/evals/runs/iteration-1"
    benchmark_path = iteration / "benchmark.json"
    validator = load_validator(root)

    preflight = validator.Validation()
    tree_secure = validator.validate_tree_security(eval_root, root, preflight)
    validated_run_count = 0
    if tree_secure:
        _, validated_run_count = validator.validate_runs(root, preflight)
    if not tree_secure or preflight.failures:
        raise RuntimeError("eval evidence preflight failed")

    notes: list[str] = []
    if args.notes:
        loaded = json.loads(args.notes.read_text(encoding="utf-8"))
        if not isinstance(loaded, list) or not all(isinstance(note, str) and note.strip() for note in loaded):
            raise RuntimeError("analysis notes must be a JSON array of non-empty strings")
        notes = loaded

    upstream = args.skill_creator_root / "scripts/aggregate_benchmark.py"
    if not upstream.is_file():
        raise RuntimeError(f"skill-creator aggregator not found: {upstream}")
    with tempfile.TemporaryDirectory(prefix=".eval-artifacts-", dir=iteration) as temporary:
        artifact_staging = Path(temporary)
        aggregation_staging = artifact_staging / "aggregation/iteration-1"
        draft_benchmark = artifact_staging / "benchmark.json"
        draft_markdown = artifact_staging / "benchmark.md"
        draft_review = artifact_staging / "review.html"
        prepare_aggregation_staging(iteration, aggregation_staging)
        subprocess.run(
            [
                sys.executable,
                str(upstream),
                str(aggregation_staging),
                "--skill-name",
                "agent-workspace-builder",
                "--skill-path",
                "skills/agent-workspace-builder/SKILL.md",
                "--output",
                str(draft_benchmark),
            ],
            cwd=root,
            check=True,
        )
        expected = validator.expected_benchmark_runs(root)
        run_count = validated_run_count
        ordered_keys = sorted(
            expected,
            key=lambda key: (key[0], 0 if key[1] == "with_skill" else 1, key[2]),
        )
        benchmark = {
            "metadata": {
                "skill_name": "agent-workspace-builder",
                "skill_path": "skills/agent-workspace-builder/SKILL.md",
                "executor_model": "not captured per run",
                "grader_model": "not captured per grading",
                "analyzer_model": "not captured in persisted analyzer notes",
                "timestamp": validator.latest_completion_timestamp(root),
                "evals_run": sorted({key[0] for key in expected}),
                "runs_per_configuration": run_count,
                "token_metric": "output_chars proxy; provider token counts unavailable",
                "time_metric": "0 means unavailable; provider timing unavailable",
                "errors_metric": "documented failed validator attempts; final validation is checked separately",
                "summary_dispersion": "descriptive dispersion across heterogeneous evals, not replicate variance",
                "rubric_isolation": "executor self-attestation; raw provider traces unavailable",
                "artifact_tooling": {
                    "aggregate_benchmark.py": validator.sha256(upstream),
                    "eval-viewer/generate_review.py": validator.sha256(
                        args.skill_creator_root / "eval-viewer/generate_review.py"
                    ),
                    "eval-viewer/viewer.html": validator.sha256(
                        args.skill_creator_root / "eval-viewer/viewer.html"
                    ),
                },
            },
            "runs": [expected[key] for key in ordered_keys],
            "run_summary": validator.expected_run_summary(expected),
            "notes": notes,
        }
        draft_benchmark.write_text(
            json.dumps(benchmark, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        draft_markdown.write_text(validator.benchmark_markdown(benchmark), encoding="utf-8")
        generate_viewer(
            root,
            iteration,
            draft_benchmark,
            draft_review,
            args.skill_creator_root.resolve(),
        )
        publish_artifacts(
            [
                (draft_benchmark, benchmark_path),
                (draft_markdown, iteration / "benchmark.md"),
                (draft_review, iteration / "review.html"),
            ]
        )
    print(f"Built {benchmark_path.relative_to(root)}, benchmark.md and review.html")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
