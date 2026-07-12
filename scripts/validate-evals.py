#!/usr/bin/env python3
"""Validate paired skill eval runs, grading, benchmark, and artifact hashes."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


CONFIGURATIONS = ("with_skill", "without_skill")
MANIFEST_REL = Path(
    "skills/agent-workspace-builder/evals/results/2026-07-11-paired-benchmark.json"
)


class Validation:
    def __init__(self) -> None:
        self.failures: list[str] = []

    def ok(self, condition: bool, message: str) -> None:
        if condition:
            print(f"OK   {message}")
        else:
            print(f"FAIL {message}", file=sys.stderr)
            self.failures.append(message)


def validate_tree_security(path: Path, root: Path, validation: Validation) -> bool:
    """Reject symlinks and paths resolving outside root before reading evidence."""
    if not path.is_dir():
        validation.ok(False, f"eval evidence directory exists: {path.relative_to(root)}")
        return False

    secure = True
    for candidate in [path, *sorted(path.rglob("*"))]:
        relative = candidate.relative_to(root)
        if candidate.is_symlink():
            validation.ok(False, f"eval evidence contains no symlink: {relative}")
            secure = False
            continue
        try:
            candidate.resolve().relative_to(root)
        except ValueError:
            validation.ok(False, f"eval evidence stays inside repository: {relative}")
            secure = False
    if secure:
        validation.ok(True, "eval evidence contains no symlinks and stays inside repository")
    return secure


def read_json(path: Path, validation: Validation) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        validation.ok(False, f"{path} is readable JSON ({exc})")
        return {}
    validation.ok(isinstance(value, dict), f"{path} contains a JSON object")
    return value if isinstance(value, dict) else {}


def read_json_array(path: Path, validation: Validation) -> list[Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        validation.ok(False, f"{path} is readable JSON ({exc})")
        return []
    validation.ok(isinstance(value, list), f"{path} contains a JSON array")
    return value if isinstance(value, list) else []


def is_utc_timestamp(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return False
    return parsed.strftime("%Y-%m-%dT%H:%M:%SZ") == value


def completion_timestamp(run: dict[str, Any]) -> Any:
    return run.get("completed_at_utc") or run.get("finished_at_utc")


def start_timestamp_is_documented(run: dict[str, Any]) -> bool:
    value = run.get("started_at_utc")
    if is_utc_timestamp(value):
        return True
    note = run.get("start_time_note")
    return (
        value is None
        and run.get("start_time_status") == "not_observed"
        and isinstance(note, str)
        and bool(note.strip())
    )


def latest_completion_timestamp(root: Path) -> str:
    iteration = root / "skills/agent-workspace-builder/evals/runs/iteration-1"
    values: list[str] = []
    for run_path in sorted(iteration.glob("eval-*/*/run-*/run.json")):
        run = json.loads(run_path.read_text(encoding="utf-8"))
        value = completion_timestamp(run)
        if not is_utc_timestamp(value):
            raise RuntimeError(f"invalid completion timestamp in {run_path.relative_to(root)}")
        values.append(value)
    if not values:
        raise RuntimeError("no persisted eval completion timestamp found")
    return max(values)


def resolve_eval_input(skill_root: Path, value: Any) -> Path | None:
    if not isinstance(value, str) or not value:
        return None
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts or relative.as_posix() != value:
        return None
    allowed_root = (skill_root / "evals/files").resolve()
    candidate = (skill_root / relative).resolve()
    try:
        candidate.relative_to(allowed_root)
    except ValueError:
        return None
    return candidate


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def calculate_stats(values: list[float]) -> dict[str, float]:
    if not values:
        return {"mean": 0.0, "stddev": 0.0, "min": 0.0, "max": 0.0}
    mean = sum(values) / len(values)
    if len(values) > 1:
        variance = sum((value - mean) ** 2 for value in values) / (len(values) - 1)
        stddev = math.sqrt(variance)
    else:
        stddev = 0.0
    return {
        "mean": round(mean, 4),
        "stddev": round(stddev, 4),
        "min": round(min(values), 4),
        "max": round(max(values), 4),
    }


def output_character_count(directory: Path) -> int:
    total = 0
    for path in sorted(directory.rglob("*")):
        if path.is_file():
            total += len(path.read_text(encoding="utf-8", errors="replace"))
    return total


def documented_failures(value: Any) -> int:
    if isinstance(value, dict):
        result = value.get("result")
        own = 1 if isinstance(result, str) and result.upper() in {"FAIL", "FAILED"} else 0
        return own + sum(documented_failures(child) for child in value.values())
    if isinstance(value, list):
        return sum(documented_failures(child) for child in value)
    return 0


def safe_relative_files(directory: Path, root: Path) -> list[Path]:
    files: list[Path] = []
    for path in sorted(directory.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"symlink is not allowed in eval evidence: {path.relative_to(root)}")
        if path.is_file():
            files.append(path)
    return files


def validation_exit_code(run: dict[str, Any]) -> int | None:
    block = run.get("validation")
    if not isinstance(block, dict):
        return None
    direct = block.get("exit_code")
    if isinstance(direct, int):
        return direct
    final = block.get("final")
    if isinstance(final, dict) and isinstance(final.get("exit_code"), int):
        return final["exit_code"]
    checkpoints = block.get("checkpoints")
    if isinstance(checkpoints, list) and checkpoints:
        final = checkpoints[-1]
        if isinstance(final, dict) and isinstance(final.get("exit_code"), int):
            return final["exit_code"]
    return None


def validate_grading(
    grading_path: Path, expectations: list[str], validation: Validation
) -> dict[str, Any]:
    grading = read_json(grading_path, validation)
    rows = grading.get("expectations")
    validation.ok(isinstance(rows, list), f"{grading_path} has an expectations array")
    if not isinstance(rows, list):
        return grading

    texts = [row.get("text") for row in rows if isinstance(row, dict)]
    validation.ok(texts == expectations, f"{grading_path} grades every current expectation in order")
    evidence_ok = all(
        isinstance(row, dict)
        and isinstance(row.get("passed"), bool)
        and isinstance(row.get("evidence"), str)
        and bool(row["evidence"].strip())
        for row in rows
    )
    validation.ok(evidence_ok, f"{grading_path} has boolean verdicts with evidence")

    passed = sum(1 for row in rows if isinstance(row, dict) and row.get("passed") is True)
    failed = len(rows) - passed
    summary = grading.get("summary")
    expected_rate = passed / len(rows) if rows else 0.0
    summary_ok = (
        isinstance(summary, dict)
        and summary.get("passed") == passed
        and summary.get("failed") == failed
        and summary.get("total") == len(rows)
        and isinstance(summary.get("pass_rate"), (int, float))
        and abs(float(summary["pass_rate"]) - expected_rate) < 0.011
    )
    validation.ok(summary_ok, f"{grading_path} summary matches its verdicts")
    return grading


def validate_iteration_topology(
    iteration: Path,
    eval_ids: list[int],
    validation: Validation,
) -> None:
    allowed_derived = {
        "analysis-notes.json",
        "benchmark.json",
        "benchmark.md",
        "review.html",
    }
    eval_dirs = [path for path in iteration.iterdir() if path.is_dir() and path.name.startswith("eval-")]
    unexpected_top = [
        path.name
        for path in iteration.iterdir()
        if path not in eval_dirs and path.name not in allowed_derived
    ]
    actual_ids: list[int] = []
    valid_names = True
    for eval_dir in eval_dirs:
        match = re.fullmatch(r"eval-([0-9]+)-[a-z0-9][a-z0-9-]*", eval_dir.name)
        if match is None:
            valid_names = False
            continue
        actual_ids.append(int(match.group(1)))
    validation.ok(
        not unexpected_top
        and valid_names
        and sorted(actual_ids) == sorted(eval_ids)
        and len(actual_ids) == len(set(actual_ids)),
        "iteration topology contains exactly the defined eval directories and derived artifacts",
    )

    for eval_dir in eval_dirs:
        allowed_eval_entries = {"eval_metadata.json", *CONFIGURATIONS}
        validation.ok(
            {path.name for path in eval_dir.iterdir()} == allowed_eval_entries,
            f"{eval_dir.name} contains only metadata and the two canonical configurations",
        )
        for configuration in CONFIGURATIONS:
            config_dir = eval_dir / configuration
            if not config_dir.is_dir():
                continue
            entries = list(config_dir.iterdir())
            run_dirs = [
                path
                for path in entries
                if path.is_dir() and re.fullmatch(r"run-[1-9][0-9]*", path.name)
            ]
            validation.ok(
                len(entries) == len(run_dirs),
                f"{eval_dir.name}/{configuration} contains only canonical run directories",
            )
            for run_dir in run_dirs:
                validation.ok(
                    {path.name for path in run_dir.iterdir()}
                    == {"grading.json", "outputs", "run.json", "transcript.md"},
                    f"{eval_dir.name}/{configuration}/{run_dir.name} contains only canonical run evidence",
                )


def validate_runs(root: Path, validation: Validation) -> tuple[list[int], int]:
    skill_root = root / "skills/agent-workspace-builder"
    eval_root = skill_root / "evals"
    definitions = read_json(eval_root / "evals.json", validation)
    validation.ok(
        definitions.get("skill_name") == "agent-workspace-builder",
        "evals.json skill_name matches the skill",
    )
    evals = definitions.get("evals")
    validation.ok(isinstance(evals, list) and bool(evals), "evals.json defines scenarios")
    if not isinstance(evals, list):
        return [], 0

    ids = [item.get("id") for item in evals if isinstance(item, dict)]
    validation.ok(
        all(isinstance(eval_id, int) for eval_id in ids) and len(ids) == len(set(ids)),
        "eval IDs are unique integers",
    )

    iteration = eval_root / "runs/iteration-1"
    validation.ok(iteration.is_dir(), "iteration-1 eval directory exists")
    if iteration.is_dir():
        validate_iteration_topology(
            iteration,
            [eval_id for eval_id in ids if isinstance(eval_id, int)],
            validation,
        )
    run_counts: list[int] = []

    for definition in evals:
        if not isinstance(definition, dict) or not isinstance(definition.get("id"), int):
            continue
        eval_id = definition["id"]
        prompt = definition.get("prompt")
        expectations = definition.get("expectations")
        files = definition.get("files", [])
        validation.ok(isinstance(prompt, str) and bool(prompt.strip()), f"eval {eval_id} has a prompt")
        validation.ok(
            isinstance(expectations, list)
            and bool(expectations)
            and all(isinstance(item, str) and item.strip() for item in expectations),
            f"eval {eval_id} has verifiable expectations",
        )
        if not isinstance(prompt, str) or not isinstance(expectations, list):
            continue
        validation.ok(isinstance(files, list), f"eval {eval_id} files is an array")
        if isinstance(files, list):
            for input_rel in files:
                input_path = resolve_eval_input(skill_root, input_rel)
                validation.ok(
                    input_path is not None,
                    f"eval {eval_id} input is normalized and confined to evals/files: {input_rel}",
                )
                validation.ok(
                    input_path is not None and input_path.exists(),
                    f"eval {eval_id} input exists: {input_rel}",
                )

        matches = sorted(iteration.glob(f"eval-{eval_id}-*"))
        validation.ok(len(matches) == 1, f"eval {eval_id} has exactly one run directory")
        if len(matches) != 1:
            continue
        eval_dir = matches[0]
        metadata = read_json(eval_dir / "eval_metadata.json", validation)
        validation.ok(metadata.get("eval_id") == eval_id, f"eval {eval_id} metadata ID matches")
        validation.ok(metadata.get("prompt") == prompt, f"eval {eval_id} metadata prompt matches")
        validation.ok(
            metadata.get("expected_output") == definition.get("expected_output"),
            f"eval {eval_id} metadata expected output matches",
        )
        validation.ok(
            metadata.get("assertions") == expectations,
            f"eval {eval_id} metadata expectations match evals.json",
        )

        config_runs: dict[str, list[int]] = {}
        for configuration in CONFIGURATIONS:
            config_dir = eval_dir / configuration
            runs: list[int] = []
            for run_dir in sorted(config_dir.glob("run-*")):
                try:
                    run_number = int(run_dir.name.removeprefix("run-"))
                except ValueError:
                    validation.ok(False, f"invalid run directory name: {run_dir.relative_to(root)}")
                    continue
                runs.append(run_number)
                run_path = run_dir / "run.json"
                transcript_path = run_dir / "transcript.md"
                outputs_dir = run_dir / "outputs"
                workspace = outputs_dir / "workspace"
                grading_path = run_dir / "grading.json"

                run = read_json(run_path, validation)
                validation.ok(run.get("schema_version") == 1, f"eval {eval_id} {configuration} run {run_number} schema version")
                validation.ok(run.get("eval_id") == eval_id, f"eval {eval_id} {configuration} run {run_number} ID")
                validation.ok(run.get("configuration") == configuration, f"eval {eval_id} {configuration} run {run_number} configuration")
                validation.ok(run.get("run_number") == run_number, f"eval {eval_id} {configuration} run {run_number} number")
                validation.ok(run.get("prompt") == prompt, f"eval {eval_id} {configuration} run {run_number} prompt")
                validation.ok(run.get("status") == "passed", f"eval {eval_id} {configuration} run {run_number} completed")
                validation.ok(
                    run.get("grading_status") == "completed_by_separate_grader",
                    f"eval {eval_id} {configuration} run {run_number} records separate grading completion",
                )
                validation.ok(
                    run.get("rubric_visibility")
                    == "not provided; eval definitions and prior evidence not read",
                    f"eval {eval_id} {configuration} run {run_number} documents rubric-hidden execution",
                )
                method = run.get("method")
                if configuration == "with_skill":
                    method_ok = method == "rubric_hidden_with_skill"
                else:
                    method_ok = method == "controlled_baseline" or (
                        isinstance(method, dict)
                        and method.get("kind") == "controlled_baseline"
                        and method.get("agent_workspace_builder_skill_used") is False
                    )
                validation.ok(
                    method_ok,
                    f"eval {eval_id} {configuration} run {run_number} records the intended execution method",
                )
                validation.ok(
                    start_timestamp_is_documented(run)
                    and is_utc_timestamp(completion_timestamp(run)),
                    f"eval {eval_id} {configuration} run {run_number} records canonical or explicitly unobserved timestamps",
                )
                validation.ok(validation_exit_code(run) == 0, f"eval {eval_id} {configuration} run {run_number} records validator exit 0")
                validation.ok(transcript_path.is_file(), f"eval {eval_id} {configuration} run {run_number} transcript exists")
                validation.ok(workspace.is_dir(), f"eval {eval_id} {configuration} run {run_number} workspace exists")

                artifacts = run.get("artifacts")
                artifacts_ok = isinstance(artifacts, list) and bool(artifacts)
                if artifacts_ok:
                    for artifact in artifacts:
                        candidate = (run_dir / str(artifact)).resolve()
                        try:
                            candidate.relative_to(run_dir.resolve())
                        except ValueError:
                            artifacts_ok = False
                            break
                        if not candidate.exists():
                            artifacts_ok = False
                            break
                validation.ok(artifacts_ok, f"eval {eval_id} {configuration} run {run_number} artifacts resolve inside the run")

                if workspace.is_dir():
                    command = [
                        "bash",
                        "scripts/validate-workspace.sh",
                        str(workspace.relative_to(root)),
                    ]
                    completed = subprocess.run(
                        command,
                        cwd=root,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        check=False,
                    )
                    validation.ok(
                        completed.returncode == 0,
                        f"eval {eval_id} {configuration} run {run_number} workspace passes current validator",
                    )
                validate_grading(grading_path, expectations, validation)
            config_runs[configuration] = runs
            validation.ok(bool(runs), f"eval {eval_id} has at least one {configuration} run")

        validation.ok(
            config_runs.get("with_skill") == config_runs.get("without_skill"),
            f"eval {eval_id} has paired run numbers",
        )
        run_counts.append(len(config_runs.get("with_skill", [])))

    validation.ok(bool(run_counts) and len(set(run_counts)) == 1, "every eval has the same run count")
    return [eval_id for eval_id in ids if isinstance(eval_id, int)], run_counts[0] if run_counts else 0


def evidence_files(root: Path) -> list[Path]:
    skill_root = root / "skills/agent-workspace-builder"
    eval_root = skill_root / "evals"
    paths = [
        root / "AGENTS.md",
        skill_root / "SKILL.md",
        eval_root / "evals.json",
        root / "scripts/build-eval-artifacts.py",
        root / "scripts/build-eval-artifacts.sh",
        root / "scripts/test-evals.sh",
        root / "scripts/discover.sh",
        root / "scripts/validate-evals.py",
        root / "scripts/validate-evals.sh",
        root / "scripts/validate-workspace.sh",
    ]
    paths.extend(safe_relative_files(skill_root / "references", root))
    paths.extend(safe_relative_files(root / "templates", root))
    definitions = json.loads((eval_root / "evals.json").read_text(encoding="utf-8"))
    for definition in definitions["evals"]:
        for input_rel in definition.get("files", []):
            input_path = resolve_eval_input(skill_root, input_rel)
            if input_path is None:
                continue
            paths.extend(safe_relative_files(input_path, root) if input_path.is_dir() else [input_path])
    iteration = eval_root / "runs/iteration-1"
    for eval_dir in sorted(iteration.glob("eval-*")):
        metadata = eval_dir / "eval_metadata.json"
        if metadata.is_file():
            paths.append(metadata)
        for configuration in CONFIGURATIONS:
            for run_dir in sorted((eval_dir / configuration).glob("run-*")):
                for name in ("run.json", "transcript.md", "grading.json"):
                    paths.append(run_dir / name)
                paths.extend(safe_relative_files(run_dir / "outputs", root))
    for name in ("analysis-notes.json", "benchmark.json", "benchmark.md", "review.html"):
        paths.append(iteration / name)
    return sorted(set(paths))


def expected_benchmark_runs(root: Path) -> dict[tuple[int, str, int], dict[str, Any]]:
    eval_root = root / "skills/agent-workspace-builder/evals"
    definitions = json.loads((eval_root / "evals.json").read_text(encoding="utf-8"))
    names: dict[int, str] = {}
    iteration = eval_root / "runs/iteration-1"
    for eval_dir in sorted(iteration.glob("eval-*")):
        metadata = json.loads((eval_dir / "eval_metadata.json").read_text(encoding="utf-8"))
        names[int(metadata["eval_id"])] = str(metadata["eval_name"])

    expected: dict[tuple[int, str, int], dict[str, Any]] = {}
    for definition in definitions["evals"]:
        eval_id = int(definition["id"])
        eval_dir = next(iter(sorted(iteration.glob(f"eval-{eval_id}-*"))))
        for configuration in CONFIGURATIONS:
            for run_dir in sorted((eval_dir / configuration).glob("run-*")):
                run_number = int(run_dir.name.removeprefix("run-"))
                grading = json.loads((run_dir / "grading.json").read_text(encoding="utf-8"))
                run_data = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
                summary = grading["summary"]
                timing = grading.get("timing") or {}
                time_seconds = timing.get("total_duration_seconds")
                if not isinstance(time_seconds, (int, float)):
                    time_seconds = 0.0
                tokens = output_character_count(run_dir / "outputs")
                tool_calls = 0
                errors = documented_failures(run_data.get("validation", {}))
                key = (eval_id, configuration, run_number)
                expected[key] = {
                    "eval_id": eval_id,
                    "eval_name": names[eval_id],
                    "configuration": configuration,
                    "run_number": run_number,
                    "result": {
                        "pass_rate": summary["pass_rate"],
                        "passed": summary["passed"],
                        "failed": summary["failed"],
                        "total": summary["total"],
                        "time_seconds": time_seconds,
                        "tokens": tokens,
                        "tool_calls": tool_calls,
                        "errors": errors,
                    },
                    "expectations": grading["expectations"],
                    "notes": [
                        *grading.get("user_notes_summary", {}).get("uncertainties", []),
                        *grading.get("user_notes_summary", {}).get("needs_review", []),
                        *grading.get("user_notes_summary", {}).get("workarounds", []),
                    ],
                }
    return expected


def expected_run_summary(expected: dict[tuple[int, str, int], dict[str, Any]]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for configuration in CONFIGURATIONS:
        rows = [row for key, row in expected.items() if key[1] == configuration]
        summary[configuration] = {
            "pass_rate": calculate_stats([float(row["result"]["pass_rate"]) for row in rows]),
            "time_seconds": calculate_stats([float(row["result"]["time_seconds"]) for row in rows]),
            "tokens": calculate_stats([float(row["result"]["tokens"]) for row in rows]),
        }
    with_skill = summary["with_skill"]
    without_skill = summary["without_skill"]
    summary["delta"] = {
        "pass_rate": f"{with_skill['pass_rate']['mean'] - without_skill['pass_rate']['mean']:+.2f}",
        "time_seconds": f"{with_skill['time_seconds']['mean'] - without_skill['time_seconds']['mean']:+.1f}",
        "tokens": f"{with_skill['tokens']['mean'] - without_skill['tokens']['mean']:+.0f}",
    }
    return summary


def benchmark_markdown(benchmark: dict[str, Any]) -> str:
    metadata = benchmark["metadata"]
    summary = benchmark["run_summary"]
    lines = [
        "# Skill Benchmark: agent-workspace-builder",
        "",
        "**Evidence class**: exploratory paired evidence",
        f"**Executor model**: {metadata['executor_model']}",
        f"**Grader model**: {metadata['grader_model']}",
        f"**Analyzer model**: {metadata['analyzer_model']}",
        f"**Evidence timestamp**: {metadata['timestamp']}",
        f"**Evals**: {', '.join(map(str, metadata['evals_run']))}",
        f"**Runs per configuration**: {metadata['runs_per_configuration']}",
        "",
        "## Summary",
        "",
        "| Metric | With skill | Without skill | Delta |",
        "|---|---:|---:|---:|",
    ]
    with_skill = summary["with_skill"]
    without_skill = summary["without_skill"]
    delta = summary["delta"]
    lines.append(
        "| Pass rate | "
        f"{with_skill['pass_rate']['mean'] * 100:.1f}% | "
        f"{without_skill['pass_rate']['mean'] * 100:.1f}% | "
        f"{float(delta['pass_rate']) * 100:+.1f} pp |"
    )
    lines.append(
        "| Output characters (token proxy) | "
        f"{with_skill['tokens']['mean']:.0f} | "
        f"{without_skill['tokens']['mean']:.0f} | "
        f"{delta['tokens']} |"
    )
    lines.extend(
        [
            "| Provider timing | not captured | not captured | — |",
            "",
            "The reported standard deviation is descriptive dispersion across heterogeneous eval scenarios, not replicate variance.",
            "",
            "## Per-eval results",
            "",
            "| Eval | Configuration | Passed | Total | Pass rate |",
            "|---:|---|---:|---:|---:|",
        ]
    )
    for row in benchmark["runs"]:
        result = row["result"]
        lines.append(
            f"| {row['eval_id']} — {row['eval_name']} | {row['configuration']} | "
            f"{result['passed']} | {result['total']} | {result['pass_rate'] * 100:.1f}% |"
        )
    lines.extend(["", "## Analysis notes", ""])
    lines.extend(f"- {note}" for note in benchmark["notes"])
    lines.extend(
        [
            "",
            "## Method and metric limits",
            "",
            "Provider model identifiers, token counts, tool-call counts and wall-clock duration were not captured and are not inferred. "
            "The `tokens` field required by the standard viewer contains output character counts as a deterministic proxy; "
            "`time_seconds: 0` means unavailable, not zero execution time.",
            "",
            "There is one run per configuration. Transcripts are manually persisted execution summaries rather than raw provider traces, "
            "so execution isolation and complete tool history are not independently provable.",
            "",
        ]
    )
    return "\n".join(lines)


def workspace_review(outputs_dir: Path) -> str:
    workspace = outputs_dir / "workspace"
    lines = ["# Persisted workspace artifacts", ""]
    for path in sorted(workspace.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(workspace)
        lines.extend([f"===== {relative} =====", ""])
        try:
            lines.extend([path.read_text(encoding="utf-8"), ""])
        except UnicodeDecodeError:
            lines.extend([f"Binary file: {path.stat().st_size} bytes", ""])
    return "\n".join(lines)


def expected_viewer_runs(root: Path) -> list[dict[str, Any]]:
    iteration = root / "skills/agent-workspace-builder/evals/runs/iteration-1"
    rows: list[dict[str, Any]] = []
    for eval_dir in sorted(iteration.glob("eval-*")):
        metadata = json.loads((eval_dir / "eval_metadata.json").read_text(encoding="utf-8"))
        for configuration in CONFIGURATIONS:
            for run_dir in sorted((eval_dir / configuration).glob("run-*")):
                rows.append(
                    {
                        "id": f"{eval_dir.name}-{configuration}-{run_dir.name}",
                        "prompt": metadata["prompt"],
                        "eval_id": metadata["eval_id"],
                        "outputs": [
                            {
                                "name": "workspace-review.md",
                                "type": "text",
                                "content": workspace_review(run_dir / "outputs"),
                            }
                        ],
                        "grading": json.loads(
                            (run_dir / "grading.json").read_text(encoding="utf-8")
                        ),
                    }
                )
    return sorted(rows, key=lambda row: (row["eval_id"], row["id"]))


def validate_viewer(
    root: Path,
    benchmark: dict[str, Any],
    validation: Validation,
) -> None:
    path = root / "skills/agent-workspace-builder/evals/runs/iteration-1/review.html"
    validation.ok(path.is_file(), "static eval review viewer exists")
    if not path.is_file():
        return
    review = path.read_text(encoding="utf-8")
    required = (
        "script-src 'nonce-agent-factory-viewer'",
        "script-src-attr 'none'",
        'nonce="agent-factory-viewer"',
        "escapeAttr(exp.evidence",
        "Failed validator attempts",
    )
    forbidden = (
        "onclick=",
        "Claude Code",
        "Crashes During Execution",
        "html += metadata.timestamp",
        'fetch("/api/',
    )
    validation.ok(all(marker in review for marker in required), "static viewer contains every hardening marker")
    validation.ok(all(marker not in review for marker in forbidden), "static viewer omits unsafe, server-only, and inaccurate content")
    validation.ok(review.count("</script>") == 1, "static viewer has exactly one script terminator")
    match = re.search(r"const EMBEDDED_DATA = (.*);\n", review)
    embedded: dict[str, Any] = {}
    if match:
        try:
            value = json.loads(match.group(1))
            if isinstance(value, dict):
                embedded = value
        except json.JSONDecodeError:
            pass
    validation.ok(bool(embedded), "static viewer contains readable embedded JSON")
    if not embedded:
        return
    validation.ok(embedded.get("skill_name") == "agent-workspace-builder", "static viewer skill name matches")
    validation.ok(embedded.get("benchmark") == benchmark, "static viewer embeds the canonical benchmark exactly")
    validation.ok(embedded.get("runs") == expected_viewer_runs(root), "static viewer embeds every recursive output and grading exactly")


def validate_benchmark(root: Path, eval_ids: list[int], run_count: int, validation: Validation) -> None:
    iteration = root / "skills/agent-workspace-builder/evals/runs/iteration-1"
    benchmark = read_json(iteration / "benchmark.json", validation)
    metadata = benchmark.get("metadata")
    validation.ok(isinstance(metadata, dict), "benchmark metadata exists")
    if isinstance(metadata, dict):
        validation.ok(metadata.get("skill_name") == "agent-workspace-builder", "benchmark skill name matches")
        validation.ok(metadata.get("evals_run") == eval_ids, "benchmark includes every eval")
        validation.ok(metadata.get("runs_per_configuration") == run_count, "benchmark run count is truthful")
        skill_path = metadata.get("skill_path")
        validation.ok(
            isinstance(skill_path, str) and not Path(skill_path).is_absolute(),
            "benchmark skill path is repository-relative",
        )
        expected_provenance = {
            "executor_model": "not captured per run",
            "grader_model": "not captured per grading",
            "analyzer_model": "not captured in persisted analyzer notes",
        }
        validation.ok(
            all(metadata.get(field) == value for field, value in expected_provenance.items()),
            "benchmark does not invent executor, grader, or analyzer model identifiers",
        )
        validation.ok(
            metadata.get("timestamp") == latest_completion_timestamp(root),
            "benchmark timestamp matches the latest persisted run completion",
        )
        validation.ok(
            metadata.get("summary_dispersion")
            == "descriptive dispersion across heterogeneous evals, not replicate variance",
            "benchmark labels cross-eval dispersion without implying replicate variance",
        )
        validation.ok(
            metadata.get("rubric_isolation")
            == "executor self-attestation; raw provider traces unavailable",
            "benchmark states the evidentiary limit of rubric isolation",
        )
        tooling = metadata.get("artifact_tooling")
        tooling_ok = (
            isinstance(tooling, dict)
            and set(tooling)
            == {
                "aggregate_benchmark.py",
                "eval-viewer/generate_review.py",
                "eval-viewer/viewer.html",
            }
            and all(
                isinstance(value, str)
                and len(value) == 64
                and all(character in "0123456789abcdef" for character in value)
                for value in tooling.values()
            )
        )
        validation.ok(tooling_ok, "benchmark records SHA-256 provenance for upstream artifact tooling")
    runs = benchmark.get("runs")
    expected_runs = len(eval_ids) * len(CONFIGURATIONS) * run_count
    validation.ok(isinstance(runs, list) and len(runs) == expected_runs, "benchmark contains every paired run")
    expected = expected_benchmark_runs(root)
    actual: dict[tuple[int, str, int], dict[str, Any]] = {}
    duplicate = False
    if isinstance(runs, list):
        for row in runs:
            if not isinstance(row, dict):
                continue
            key = (row.get("eval_id"), row.get("configuration"), row.get("run_number"))
            if key in actual:
                duplicate = True
            actual[key] = row
    validation.ok(not duplicate, "benchmark run identities are unique")
    validation.ok(set(actual) == set(expected), "benchmark run identities match persisted runs")
    validation.ok(
        set(actual) == set(expected) and all(actual[key] == expected[key] for key in expected),
        "benchmark run results and expectations match grading evidence",
    )
    validation.ok(
        benchmark.get("run_summary") == expected_run_summary(expected),
        "benchmark summary is derived from persisted grading evidence",
    )
    notes = benchmark.get("notes")
    validation.ok(
        isinstance(notes, list)
        and bool(notes)
        and all(isinstance(note, str) and note.strip() for note in notes),
        "benchmark analyzer notes are a non-empty list of non-empty strings",
    )
    analysis_path = iteration / "analysis-notes.json"
    analysis_notes = read_json_array(analysis_path, validation)
    validation.ok(analysis_notes == notes, "benchmark embeds the persisted analyzer notes exactly")
    markdown_path = iteration / "benchmark.md"
    validation.ok(markdown_path.is_file(), "benchmark Markdown summary exists")
    if markdown_path.is_file():
        validation.ok(
            markdown_path.read_text(encoding="utf-8") == benchmark_markdown(benchmark),
            "benchmark Markdown is derived exactly from the canonical benchmark",
        )
    validate_viewer(root, benchmark, validation)


def skill_source_commit(root: Path) -> str:
    completed = subprocess.run(
        [
            "git",
            "log",
            "-1",
            "--format=%H",
            "--",
            "skills/agent-workspace-builder/SKILL.md",
        ],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    source = completed.stdout.strip()
    if len(source) != 40 or any(character not in "0123456789abcdef" for character in source):
        raise RuntimeError("cannot determine the full source commit for the evaluated skill")
    return source


def manifest_payload(
    root: Path,
    eval_ids: list[int],
    run_count: int,
    source_commit: str | None = None,
) -> dict[str, Any]:
    source = source_commit if source_commit is not None else skill_source_commit(root)
    if len(source) != 40 or any(character not in "0123456789abcdef" for character in source):
        raise RuntimeError("invalid source commit for eval manifest")
    files = {
        str(path.relative_to(root)): sha256(path)
        for path in evidence_files(root)
        if path.is_file()
    }
    return {
        "schema_version": 1,
        "evidence_class": "exploratory hash-verifiable paired evidence",
        "evidence_verifiable": True,
        "execution_reproducible": False,
        "skill": "agent-workspace-builder",
        "source_commit": source,
        "source_commit_scope": "latest commit affecting SKILL.md; current dependencies are captured by file hashes",
        "evidence_completed_at_utc": latest_completion_timestamp(root),
        "eval_ids": eval_ids,
        "configurations": list(CONFIGURATIONS),
        "runs_per_configuration": run_count,
        "files": files,
        "reproduction": {
            "validator_command": "bash scripts/validate-evals.sh",
            "benchmark_directory": "skills/agent-workspace-builder/evals/runs/iteration-1",
            "scope": "deterministic verification of persisted evidence and derived artifacts",
        },
        "limitations": [
            "Model identifiers, provider token counts and tool-call counts were not exposed by the executor and are not inferred.",
            "One run per configuration measures scenario coverage but not statistical variance.",
            "Evaluation execution is nondeterministic; only persisted evidence and derived results are hash-verifiable.",
            "Transcripts are concise manually persisted execution summaries, not raw provider traces; rubric isolation and complete tool-call history are not independently provable.",
            "Synthetic eval workspaces do not count as real-project evidence for blueprint promotion."
        ],
    }


def validate_manifest(root: Path, eval_ids: list[int], run_count: int, validation: Validation) -> None:
    manifest_path = root / MANIFEST_REL
    manifest = read_json(manifest_path, validation)
    validation.ok(
        manifest.get("evidence_verifiable") is True,
        "eval result manifest marks persisted evidence as hash-verifiable",
    )
    validation.ok(
        manifest.get("execution_reproducible") is False,
        "eval result manifest distinguishes evidence verification from nondeterministic execution",
    )
    source_commit = manifest.get("source_commit")
    validation.ok(
        isinstance(source_commit, str)
        and len(source_commit) == 40
        and all(character in "0123456789abcdef" for character in source_commit),
        "eval result manifest records a full source commit",
    )
    validation.ok(manifest.get("eval_ids") == eval_ids, "eval result manifest includes every eval")
    validation.ok(manifest.get("runs_per_configuration") == run_count, "eval result manifest run count matches")
    stored = manifest.get("files")
    validation.ok(isinstance(stored, dict) and bool(stored), "eval result manifest contains file hashes")
    if not isinstance(stored, dict):
        return
    if isinstance(source_commit, str) and len(source_commit) == 40:
        try:
            canonical = manifest_payload(root, eval_ids, run_count)
        except RuntimeError:
            canonical = manifest_payload(root, eval_ids, run_count, source_commit)
        validation.ok(
            manifest == canonical,
            "eval result manifest exactly matches all canonically derived metadata and hashes",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--runs-only", action="store_true")
    parser.add_argument("--write-manifest", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    validation = Validation()
    eval_root = root / "skills/agent-workspace-builder/evals"
    if not validate_tree_security(eval_root, root, validation):
        print(f"\nEval validation failed with {len(validation.failures)} issue(s).", file=sys.stderr)
        return 1
    eval_ids, run_count = validate_runs(root, validation)

    if not args.runs_only:
        validate_benchmark(root, eval_ids, run_count, validation)
        if args.write_manifest and not validation.failures:
            manifest_path = root / MANIFEST_REL
            manifest_path.parent.mkdir(parents=True, exist_ok=True)
            manifest_path.write_text(
                json.dumps(manifest_payload(root, eval_ids, run_count), indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
            print(f"OK   wrote {manifest_path.relative_to(root)}")
        validate_manifest(root, eval_ids, run_count, validation)

    if validation.failures:
        print(f"\nEval validation failed with {len(validation.failures)} issue(s).", file=sys.stderr)
        return 1
    print("\nEval validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
