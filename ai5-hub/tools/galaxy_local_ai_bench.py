"""GALAXY_LOCAL_AI on-device model benchmark.

Pushes the official llama.cpp android-arm64 build and one candidate GGUF at a time to the adb shell
scratch area (/data/local/tmp/daimon-llm, no app install, no settings change), starts llama-server
bound to 127.0.0.1 on the phone, reaches it through `adb forward`, and measures load time, speed,
peak RAM, thermal/battery deltas and auto-scored task quality. Each model file is removed from the
phone after its run. Prompts contain no secrets. Evidence JSON goes to
ai5-hub/evidence/galaxy-local-ai/.
"""
import datetime
import json
import os
import re
import secrets
import subprocess
import sys
import tarfile
import time
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ADB = str(Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk/platform-tools/adb.exe")
WORK = Path.home() / ".local/daimon/galaxy-local-ai"
PHONE_DIR = "/data/local/tmp/daimon-llm"
PORT_PHONE, PORT_PC = 8090, 18090
EVIDENCE_DIR = REPO / "ai5-hub/evidence/galaxy-local-ai"
API_KEY = secrets.token_hex(16)  # per-run; blocks other apps / browser pages on the phone from using the server
THERMAL_LIMIT_STATUS, BATTERY_TEMP_LIMIT_C = 2, 40.0

CANDIDATES = [
    "gemma-3-1b-it-Q4_K_M.gguf",
    "Qwen3-1.7B-Q4_K_M.gguf",
    "Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
    "gemma-3-4b-it-Q4_K_M.gguf",
    "Phi-4-mini-instruct-Q4_K_M.gguf",
]

LOG_SAMPLE = """2026-10-16 09:00:01 INFO worker started device=dynabook
2026-10-16 09:00:05 INFO task claimed id=T-100
2026-10-16 09:00:09 WARN retry 1/3 git pull timeout
2026-10-16 09:00:21 ERROR git pull failed: Could not resolve host github.com
2026-10-16 09:00:21 INFO task released id=T-100"""

# (name, messages, json_schema or None, scorer(text)->bool)
TESTS = [
    ("japanese_summary",
     "次の文章を日本語で1文に要約してください。\n"
     "富士通のPCとdynabookはRustDeskで接続され、クリップボードの双方向共有と切断後の再接続を確認した。"
     "原因はセッション内のクリップボード機能が止まっていたことで、設定を一度切って戻すことで直った。",
     None, lambda t: bool(re.search(r"[ぁ-ん]", t)) and ("クリップボード" in t) and len(t) < 160),
    ("json_schema",
     "次の依頼を分類してJSONで返してください：「dynabookのディスク空き容量を確認して」",
     {"type": "object", "properties": {"category": {"type": "string", "enum": ["diagnostic", "install", "delete", "publish", "chat"]},
      "risk": {"type": "string", "enum": ["low", "medium", "high"]}, "needs_owner": {"type": "boolean"}},
      "required": ["category", "risk", "needs_owner"]},
     lambda t: (lambda d: d.get("category") == "diagnostic" and d.get("needs_owner") is False)(json.loads(t))),
    ("task_classification",
     "次の作業は本人承認が必要ですか。「はい」か「いいえ」の一語だけで答えてください：\n本番サーバーのデータベースを全件削除する",
     None, lambda t: t.strip().startswith("はい")),
    ("task_classification_safe",
     "次の作業は本人承認が必要ですか。「はい」か「いいえ」の一語だけで答えてください：\nログファイルを読んでエラー件数を数える",
     None, lambda t: t.strip().startswith("いいえ")),
    ("log_analysis",
     "次のログで、作業が失敗した根本原因を日本語で1文で答えてください。\n" + LOG_SAMPLE,
     # must answer in Japanese (instruction following) and name the DNS / host-resolution cause
     None, lambda t: bool(re.search(r"[ぁ-んァ-ン]", t)) and bool(re.search(r"(名前解決|DNS|resolve|ホスト|github\.com)", t, re.I))),
    ("light_judgement",
     "電池残量15%で充電していないスマホで、重いAI処理を今すぐ実行すべきですか。理由を日本語で1文で。",
     # a clear "no" is required; the prompt's own words (充電していない / 実行) are removed first so an echo cannot pass
     None, lambda t: bool(re.search(r"(べきでは(ない|ありません)|避け|控え|延期|見送|待つ|充電してから|しない方が)",
                                    t.replace("充電していない", "")))),
    ("kana_order",
     "「りんご、バナナ、みかん」を五十音順に並べ、日本語で答えてください。",
     None, lambda t: (lambda o: all(i >= 0 for i in o) and o == sorted(o) and len(t) <= 200)(
         [t.find(w) for w in ("バナナ", "みかん", "りんご")])),
    ("faithful_summary",
     "次の報告を日本語で1文に要約してください。\nFUJITSUとdynabookの遠隔接続は正常で、Galaxyのローカル AI の導入準備が進んでいる。",
     # keeps the named entities, adds nothing that is not in the source
     None, lambda t: bool(re.search(r"(Galaxy|ギャラクシー)", t, re.I)) and bool(re.search(r"(dynabook|ダイナブック)", t, re.I))
     and not re.search(r"(ガジェット|スマートウォッチ|クラウド)", t)),
    ("light_code",
     "次のPythonコードの出力だけを答えてください。\nprint(sum(x*x for x in range(4)))",
     # "output only": a short answer whose number is 14
     None, lambda t: len(t.strip()) <= 20 and re.findall(r"\d+", t)[-1:] == ["14"]),
]


def rescore(record):
    """Re-apply the current scorers to stored outputs (outputs are stored up to 300 chars)."""
    scorers = {name: scorer for name, _, _, scorer in TESTS}
    for r in record.get("tests", []):
        if "output" in r and r["test"] in scorers:
            try:
                r["pass"] = bool(scorers[r["test"]](r["output"]))
            except Exception:
                r["pass"] = False
    record["quality_score"] = f"{sum(r['pass'] for r in record.get('tests', []))}/{len(TESTS)}"
    return record


def adb(*args, check=True, timeout=600):
    p = subprocess.run([ADB, *args], capture_output=True, timeout=timeout)
    out = p.stdout.decode("utf-8", "replace")
    if check and p.returncode != 0:
        raise RuntimeError(f"adb {' '.join(args)} failed: {p.stderr.decode('utf-8', 'replace')}")
    return out


def sh(cmd, check=True, timeout=600):
    return adb("shell", cmd, check=check, timeout=timeout)


def device_state():
    bat = sh("dumpsys battery")
    th = sh("dumpsys thermalservice")
    mem = sh("cat /proc/meminfo")
    g = lambda pat, s, f=float: (lambda m: f(m.group(1)) if m else None)(re.search(pat, s, re.M))
    return {
        "battery_level": g(r"^\s*level:\s*(\d+)", bat, int),
        "battery_temp_c": (g(r"^\s*temperature:\s*(\d+)", bat) or 0) / 10,
        "thermal_status": g(r"Thermal Status:\s*(\d+)", th, int),
        "mem_available_gib": round((g(r"^MemAvailable:\s+(\d+)", mem) or 0) / 1048576, 2),
    }


def wait_cool(max_wait_s=900):
    start = time.time()
    while True:
        st = device_state()
        if (st["thermal_status"] or 0) < THERMAL_LIMIT_STATUS and st["battery_temp_c"] < BATTERY_TEMP_LIMIT_C:
            return st, round(time.time() - start)
        if time.time() - start > max_wait_s:
            return st, -1
        time.sleep(30)


def push_runtime():
    tgz = WORK / "llama-b10536-bin-android-arm64.tar.gz"
    out = WORK / "android-runtime"
    if not out.exists():
        with tarfile.open(tgz) as t:
            t.extractall(out, filter="data")
    bindir = next(p.parent for p in out.rglob("llama-server"))
    sh(f"mkdir -p {PHONE_DIR}/bin")
    adb("push", str(bindir) + "/.", f"{PHONE_DIR}/bin/", timeout=900)
    sh(f"chmod 755 {PHONE_DIR}/bin/*")
    return sorted(p.name for p in bindir.iterdir())


def http(path, body=None, timeout=300):
    req = urllib.request.Request(f"http://127.0.0.1:{PORT_PC}{path}",
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json", "Authorization": f"Bearer {API_KEY}"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def run_model(model, threads):
    rec = {"model": model, "bytes": (WORK / "models" / model).stat().st_size}
    before, waited = wait_cool()
    rec["state_before"], rec["cooldown_wait_s"] = before, waited
    if waited < 0:
        rec["skipped"] = "THERMAL_GUARD"
        return rec
    adb("push", str(WORK / "models" / model), f"{PHONE_DIR}/model.gguf", timeout=1800)
    sh("pkill -f llama-server", check=False)  # a leftover server would hold the port with a different API key
    adb("forward", f"tcp:{PORT_PC}", f"tcp:{PORT_PHONE}")
    t0 = time.time()
    # `cd X && cmd > f &` backgrounds a subshell whose own stdout is the adb pipe, so adb shell never returns.
    # Background only the fully redirected command.
    sh(f"cd {PHONE_DIR} || exit 1; LD_LIBRARY_PATH={PHONE_DIR}/bin nohup bin/llama-server -m model.gguf "
       f"--host 127.0.0.1 --port {PORT_PHONE} -t {threads} -c 4096 --no-webui --api-key {API_KEY} "
       f"> server.log 2>&1 < /dev/null &", timeout=60)
    load_s = None
    for _ in range(600):
        try:
            if http("/health", timeout=5).get("status") == "ok":
                load_s = round(time.time() - t0, 2)
                break
        except Exception:
            pass
        time.sleep(0.5)
    rec["load_time_s"] = load_s
    if load_s is None:
        rec["error"] = sh(f"tail -n 20 {PHONE_DIR}/server.log", check=False)
        stop_server()
        return rec
    results, gen_tps, prompt_tps = [], [], []
    for name, prompt, schema, scorer in TESTS:
        body = {"messages": [{"role": "user", "content": prompt + ("\n/no_think" if "Qwen3-1.7B" in model else "")}],
                "temperature": 0, "max_tokens": 256, "repeat_penalty": 1.15}  # same decoding as the deployed worker
        if schema:
            body["response_format"] = {"type": "json_schema", "json_schema": {"name": "r", "schema": schema}}
        t1 = time.time()
        try:
            resp = http("/v1/chat/completions", body)
            text = resp["choices"][0]["message"]["content"] or ""
            text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
            timings = resp.get("timings", {})
            gen_tps.append(timings.get("predicted_per_second"))
            prompt_tps.append(timings.get("prompt_per_second"))
            try:
                ok = bool(scorer(text))
            except Exception:
                ok = False
            results.append({"test": name, "pass": ok, "latency_s": round(time.time() - t1, 2), "output": text[:300]})
        except Exception as e:
            results.append({"test": name, "pass": False, "error": str(e)[:200]})
    pid = sh("pidof llama-server", check=False).strip().split()
    if pid:
        hwm = re.search(r"VmHWM:\s+(\d+)", sh(f"cat /proc/{pid[0]}/status", check=False))
        rec["peak_rss_gib"] = round(int(hwm.group(1)) / 1048576, 2) if hwm else None
    rec["state_after"] = device_state()
    stop_server()
    vals = [v for v in gen_tps if v]
    rec["gen_tokens_per_s_median"] = round(sorted(vals)[len(vals) // 2], 1) if vals else None
    pv = [v for v in prompt_tps if v]
    rec["prompt_tokens_per_s_median"] = round(sorted(pv)[len(pv) // 2], 1) if pv else None
    rec["tests"] = results
    rec["quality_score"] = f"{sum(r['pass'] for r in results)}/{len(results)}"
    return rec


def stop_server():
    sh("pkill -f llama-server", check=False)
    sh(f"rm -f {PHONE_DIR}/model.gguf", check=False)
    adb("forward", "--remove", f"tcp:{PORT_PC}", check=False)


def main():
    only = sys.argv[1:] or CANDIDATES
    threads = int(os.environ.get("GALAXY_BENCH_THREADS", "6"))
    run = {"schema_version": 1, "test": "GALAXY_LOCAL_AI_BENCH", "started_at": datetime.datetime.now().astimezone().isoformat(),
           "runtime": "llama.cpp b10536 android-arm64 (official release, CPU)", "threads": threads,
           "device_props": {k: sh(f"getprop {k}").strip() for k in ("ro.product.model", "ro.soc.model", "ro.build.version.release")},
           "runtime_files": push_runtime(), "models": [], "secret_recorded": False}
    for m in only:
        print("RUN", m, flush=True)
        r = run_model(m, threads)
        run["models"].append(r)
        print(json.dumps({k: r.get(k) for k in ("model", "load_time_s", "gen_tokens_per_s_median", "peak_rss_gib", "quality_score", "skipped", "error")},
                         ensure_ascii=False), flush=True)
    run["finished_at"] = datetime.datetime.now().astimezone().isoformat()
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    path = EVIDENCE_DIR / f"GALAXY_BENCH_{datetime.datetime.now():%Y%m%d-%H%M%S}.json"
    path.write_text(json.dumps(run, ensure_ascii=False, indent=2), encoding="utf-8")
    print("EVIDENCE", path.relative_to(REPO))


if __name__ == "__main__":
    main()
