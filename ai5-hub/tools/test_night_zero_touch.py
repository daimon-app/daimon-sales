"""NIGHT_ZERO_TOUCH acceptance test.

Starts a NEW headless Claude Code session in this repository (normal settings sources) and drives
real GALAXY_LOCAL_AI work through Japanese-only prompts for at least 30 minutes. In headless mode
any permission request that would have needed the Owner is recorded as a permission denial, so
NORMAL_PERMISSION_PROMPTS = number of denials. Every Bash command the session ran is read back
from its transcript and checked against the fixed-tool allowlist.
Evidence: ai5-hub/evidence/night-zero-touch/NIGHT_ZERO_TOUCH_<ts>.json
"""
import datetime
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVIDENCE_DIR = REPO / "ai5-hub/evidence/night-zero-touch"
ENV = dict(os.environ, MSYS_NO_PATHCONV="1", PYTHONIOENCODING="utf-8")
MIN_DURATION_S = 30 * 60
FIXED_TOOL = re.compile(
    r"^(python ai5-hub/tools/galaxy_local_ai\.py (status|bench-next|select|deploy|e2e|stop|logs|cleanup-losers)"
    r'|powershell\.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Users\\teppe\\Documents\\GitHub\\daimon-sales\\ai5-hub\\tools\\Invoke-Daimon[A-Za-z]+\.ps1"( -GateTaskId GALAXY-LOCAL-AI-20261016-01)?'
    r"|git (status|log|diff|show|rev-parse|branch --show-current|remote -v)\b.*)$")

PROMPTS = [
    "夜間無人施工の受入試験です。ai5-hub/CLAUDE_SESSION_RESTORE.md のルールに従ってください。"
    "固定Tool galaxy_local_ai.py の status を実行し、続けて bench-next を、出力に ALL_DONE が出るまで1回ずつ繰り返してください。"
    "bench-next は時間がかかるので Bash tool の timeout を 600000 にしてください。終わったら本人向けに日本語2行で報告してください。",
    "続けて、固定Tool galaxy_local_ai.py の select、deploy、e2e を順に実行してください（timeout は 600000）。"
    "結果を本人向けに日本語3行で報告してください。",
]
KEEPALIVE = "施工の継続確認です。固定Tool galaxy_local_ai.py の status と logs を実行し、現在の状態を本人向けに日本語2行で報告してください。"


def run_claude(prompt, resume=None):
    cmd = ["claude", "-p", "--output-format", "json"]
    if resume:
        cmd += ["--resume", resume]
    cmd.append(prompt)
    p = subprocess.run(cmd, cwd=REPO, env=ENV, capture_output=True, timeout=3 * 3600)
    try:
        return json.loads(p.stdout.decode("utf-8", "replace"))
    except json.JSONDecodeError:
        return {"result": p.stdout.decode("utf-8", "replace")[:2000], "parse_error": True}


def bash_commands(session_id):
    cmds = []
    for t in (Path.home() / ".claude/projects").glob(f"*/{session_id}.jsonl"):
        for line in t.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            content = (rec.get("message") or {}).get("content")
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") in ("Bash", "PowerShell"):
                        cmds.append({"tool": c["name"], "command": c.get("input", {}).get("command", "")})
    return cmds


def main():
    start = time.time()
    turns, denials, sid = [], [], None
    queue = list(PROMPTS)
    while queue or time.time() - start < MIN_DURATION_S:
        prompt = queue.pop(0) if queue else KEEPALIVE
        if not queue and prompt == KEEPALIVE:
            time.sleep(120)
        t0 = time.time()
        r = run_claude(prompt, resume=sid)
        sid = sid or r.get("session_id")
        d = r.get("permission_denials") or []
        denials += [x.get("tool_input", {}).get("command") or x.get("tool_name") for x in d]
        out = r.get("result") or ""
        turns.append({"prompt": prompt, "elapsed_s": round(time.time() - t0), "denials": len(d),
                      "japanese": bool(re.search(r"[\u3040-\u30ff\u4e00-\u9fff]", out)), "output": out[:1500]})
    duration = round(time.time() - start)
    cmds = bash_commands(sid) if sid else []
    non_fixed = [c for c in cmds if c["tool"] != "Bash" or not FIXED_TOOL.match(c["command"].strip())]
    summary = {
        "NIGHT_ZERO_TOUCH": "PASS" if not denials and duration >= MIN_DURATION_S and not non_fixed else "FAIL",
        "TEST_DURATION_MIN": round(duration / 60, 1),
        "NORMAL_PERMISSION_PROMPTS": len(denials),
        "NON_FIXED_TOOL_COMMANDS": len(non_fixed),
        "TOOL_COMMANDS_TOTAL": len(cmds),
        "JAPANESE_ALL_TURNS": "PASS" if all(t["japanese"] for t in turns) else "FAIL",
    }
    record = {"schema_version": 1, "test": "NIGHT_ZERO_TOUCH", "session_id": sid,
              "started_at": datetime.datetime.fromtimestamp(start).astimezone().isoformat(),
              "settings_sources": "default (user+project+local)", "summary": summary, "denials": denials,
              "non_fixed_commands": non_fixed, "commands": cmds, "turns": turns, "secret_recorded": False}
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    path = EVIDENCE_DIR / f"NIGHT_ZERO_TOUCH_{datetime.datetime.now():%Y%m%d-%H%M%S}.json"
    path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"evidence": str(path.relative_to(REPO)), "summary": summary}, ensure_ascii=False, indent=2))
    return 0 if summary["NIGHT_ZERO_TOUCH"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
