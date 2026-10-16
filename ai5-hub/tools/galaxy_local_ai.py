"""DAIMON Tool Executor: GALAXY_LOCAL_AI (single fixed entry point for all routine Galaxy Local AI work).

Exact allowed operations (argparse choices; anything else is rejected before any action):
  status          read-only: adb device, phone runtime/model/worker presence, server pid/health,
                  resource + heartbeat, PC model cache, current selection
  bench-next      benchmark the next not-yet-measured candidate model on the phone (one per call)
  select          pick one winner from measured benchmarks (disqualifies hot / RAM-tight / slow / weak)
  deploy          push the selected model + worker script to the phone and register the worker
  e2e             run E2E A-G (local task, offline, escalation, sync, resource guard, registry, events)
  stop            unload the phone model server and remove the adb forward
  logs            print the last lines of the phone server / worker event logs (API key redacted)
  cleanup-losers  delete non-selected candidate GGUFs from the PC download cache (selection required)
Safety: fixed paths only; every adb/shell string is a constant in this file or built from validated
  enum values (no user text reaches a shell); no secrets are read; no Owner data is deleted; the phone
  work area is /data/local/tmp/daimon-llm (mode 700) only; Wi-Fi/data are switched off only inside
  `e2e` step B and are always restored to their prior state (verified) in a finally block.
Result/Receipt/Evidence: <bus_root>/results, <bus_root>/receipts, <bus_root>/events/galaxy_local_ai.jsonl,
  <bus_root>/worker-registry.json, ai5-hub/evidence/galaxy-local-ai/*.json.
"""
import argparse
import datetime
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import galaxy_local_ai_bench as bench  # noqa: E402

REPO = bench.REPO
WORK = bench.WORK
PHONE = bench.PHONE_DIR
BUS = Path.home() / ".local/daimon/bus"
EVIDENCE = REPO / "ai5-hub/evidence/galaxy-local-ai"
BENCH_STATE = WORK / "bench_results.json"
SELECTION = WORK / "selection.json"
WORKER_SRC = REPO / "ai5-hub/galaxy-worker/galaxy_worker.sh"
LOCAL_ROUTER = REPO / "ai5-hub/tools/Invoke-DaimonLocalRouter.ps1"
WORKER_ID = "GALAXY_LOCAL_AI"
LOCAL_CLASSES = {"summarize", "classify", "extract", "log_analysis", "chat", "light_diagnostic"}


def now():
    return datetime.datetime.now().astimezone().isoformat()


def stamp():
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")


def jdump(obj, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")


def jload(path, default=None):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return default


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sh(cmd, check=False, timeout=600):
    return bench.sh(cmd, check=check, timeout=timeout)


def device_ready():
    out = bench.adb("devices", check=False)
    ready = [l.split()[0] for l in out.splitlines()[1:] if l.strip().endswith("device")]
    if len(ready) != 1:
        print(json.dumps({"device_state": "NO_DEVICE" if not ready else "MULTIPLE_DEVICES_REFUSED"}))
        sys.exit(3)


def event(kind, **fields):
    rec = {"at": now(), "worker": WORKER_ID, "event": kind, **fields}
    p = BUS / "events/galaxy_local_ai.jsonl"
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def kv(text):
    out = {}
    for line in text.split():
        if "=" in line:
            k, v = line.split("=", 1)
            out[k] = v
    return out


# ---------------------------------------------------------------- status / logs / stop
def cmd_status(_):
    device_ready()
    st = {
        "tool": "GALAXY_LOCAL_AI.status", "at": now(),
        "phone_runtime": "present" if sh(f"[ -x {PHONE}/bin/llama-server ] && echo y").strip() == "y" else "missing",
        "phone_worker": "present" if sh(f"[ -f {PHONE}/worker/galaxy_worker.sh ] && echo y").strip() == "y" else "missing",
        "phone_model_sha256": sh(f"cat {PHONE}/state/model.sha256 2>/dev/null").strip() or None,
        "server_pid": sh("pidof llama-server").strip() or None,
        "heartbeat": kv(sh(f"cat {PHONE}/state/heartbeat 2>/dev/null")),
        "resource": bench.device_state(),
        "pc_model_cache": sorted(p.name for p in (WORK / "models").glob("*.gguf")),
        "benchmarked": sorted((jload(BENCH_STATE, {}) or {}).keys()),
        "selection": (jload(SELECTION, {}) or {}).get("selected_model"),
    }
    print(json.dumps(st, ensure_ascii=False, indent=2))


def cmd_logs(_):
    device_ready()
    key = sh(f"cat {PHONE}/state/key 2>/dev/null").strip()
    text = sh(f"tail -n 40 {PHONE}/state/server.log 2>/dev/null; echo ----; tail -n 40 {PHONE}/state/events.log 2>/dev/null")
    if key:
        text = text.replace(key, "<redacted>")
    print(re.sub(r"(--api-key\s+)\S+", r"\1<redacted>", text))


def cmd_stop(_):
    device_ready()
    sh(f"sh {PHONE}/worker/galaxy_worker.sh unload 2>/dev/null; pkill -f llama-server")
    bench.adb("forward", "--remove-all", check=False)
    print(json.dumps({"stopped": True, "server_pid": sh("pidof llama-server").strip() or None}))


# ---------------------------------------------------------------- benchmark / selection
def ensure_runtime():
    if sh(f"[ -x {PHONE}/bin/llama-server ] && echo y").strip() != "y":
        bench.push_runtime()
    sh(f"chmod 700 {PHONE}")


def cmd_bench_next(_):
    device_ready()
    results = jload(BENCH_STATE, {}) or {}
    current_tests = sorted(name for name, *_ in bench.TESTS)
    # a record measured with an older test set is stale and is re-measured
    stale = lambda r: sorted(t["test"] for t in r.get("tests", [])) != current_tests
    pending = [m for m in bench.CANDIDATES if (m not in results or stale(results[m])) and (WORK / "models" / m).exists()]
    if not pending:
        print(json.dumps({"bench": "ALL_DONE", "benchmarked": sorted(results)}))
        return
    ensure_runtime()
    model = pending[0]
    event("bench_started", model=model)
    rec = bench.run_model(model, 6)
    rec["measured_at"] = now()
    results[model] = rec
    jdump(results, BENCH_STATE)
    jdump({"schema_version": 1, "test": "GALAXY_LOCAL_AI_BENCH", "runtime": "llama.cpp b10536 android-arm64 CPU, 6 threads",
           "device": {"model": "SCG39", "soc": "SM8850"}, "results": results, "secret_recorded": False},
          EVIDENCE / "GALAXY_BENCH_RESULTS.json")
    event("bench_finished", model=model, quality=rec.get("quality_score"), tps=rec.get("gen_tokens_per_s_median"))
    print(json.dumps({k: rec.get(k) for k in ("model", "load_time_s", "gen_tokens_per_s_median", "prompt_tokens_per_s_median",
                                               "peak_rss_gib", "quality_score", "state_after", "skipped", "error")},
                     ensure_ascii=False), flush=True)
    print(json.dumps({"remaining": len(pending) - 1}))


def disqualify(rec):
    if rec.get("skipped") or rec.get("error") or not rec.get("load_time_s"):
        return "LOAD_FAILED_OR_SKIPPED"
    passed = int(str(rec.get("quality_score", "0/1")).split("/")[0])
    after = rec.get("state_after") or {}
    if (after.get("thermal_status") or 0) >= bench.THERMAL_LIMIT_STATUS:
        return "THERMAL"
    if (after.get("battery_temp_c") or 0) >= bench.BATTERY_TEMP_LIMIT_C:
        return "BATTERY_TEMP"
    if (after.get("mem_available_gib") or 0) < 1.5:
        return "RAM_TIGHT"
    if (rec.get("gen_tokens_per_s_median") or 0) < 5:
        return "TOO_SLOW"
    total = int(str(rec.get("quality_score", "0/1")).split("/")[1]) or 1
    if passed / total < 0.7:
        return "QUALITY_LT_70_PERCENT"
    return None


def cmd_select(_):
    results = jload(BENCH_STATE, {}) or {}
    current_tests = sorted(name for name, *_ in bench.TESTS)
    missing = [m for m in bench.CANDIDATES if m not in results
               or sorted(t["test"] for t in results[m].get("tests", [])) != current_tests]
    if missing:
        print(json.dumps({"select": "NOT_READY", "missing": missing}))
        sys.exit(4)
    for r in results.values():
        bench.rescore(r)  # always judge with the current (fixed) scorers
    jdump(results, BENCH_STATE)
    table = []
    for m, r in results.items():
        dq = disqualify(r)
        passed = int(str(r.get("quality_score", "0/1")).split("/")[0])
        # quality first; speed only counts up to a practical 20 tok/s; RAM is a tie-breaker-sized penalty
        score = None if dq else round(passed * 10 + min(r["gen_tokens_per_s_median"], 20) / 4 - (r.get("peak_rss_gib") or 0), 2)
        table.append({"model": m, "disqualified": dq, "score": score, "quality": r.get("quality_score"),
                      "gen_tps": r.get("gen_tokens_per_s_median"), "peak_rss_gib": r.get("peak_rss_gib"),
                      "load_time_s": r.get("load_time_s"), "bytes": r.get("bytes")})
    ok = sorted([t for t in table if t["score"] is not None], key=lambda t: (-t["score"], t["bytes"]))
    verdict = "READY" if ok else "NOT_WORTH_IT"
    sel = {"schema_version": 1, "decided_at": now(), "rule": "quality*10 + min(gen_tps,20)/4 - peak_rss_gib; "
           "disqualify on load failure, thermal>=2, battery>=40C, MemAvailable<1.5GiB after run, <5 tok/s, quality<70%",
           "table": table, "selected_model": ok[0]["model"] if ok else None, "verdict": verdict}
    if ok:
        sel["selected_sha256"] = sha256_file(WORK / "models" / ok[0]["model"])
    jdump(sel, SELECTION)
    jdump(sel, EVIDENCE / "GALAXY_MODEL_SELECTION.json")
    event("model_selected", model=sel["selected_model"], verdict=verdict)
    print(json.dumps(sel, ensure_ascii=False, indent=2))


def cmd_cleanup_losers(_):
    sel = jload(SELECTION, {}) or {}
    if not sel.get("selected_model") or not (EVIDENCE / "GALAXY_MODEL_SELECTION.json").exists():
        print(json.dumps({"cleanup": "REFUSED_NO_SELECTION_EVIDENCE"}))
        sys.exit(4)
    removed = []
    for m in bench.CANDIDATES:
        p = WORK / "models" / m
        if m != sel["selected_model"] and p.exists():
            p.unlink()
            removed.append(m)
    event("losers_cleaned", removed=removed)
    print(json.dumps({"kept": sel["selected_model"], "removed": removed}))


# ---------------------------------------------------------------- deploy / registry
def push_worker_script():
    tmp = WORK / "galaxy_worker.sh"
    tmp.write_bytes(WORKER_SRC.read_bytes().replace(b"\r\n", b"\n"))
    sh(f"mkdir -p {PHONE}/worker {PHONE}/inbox {PHONE}/outbox {PHONE}/state")
    bench.adb("push", str(tmp), f"{PHONE}/worker/galaxy_worker.sh")
    sh(f"chmod 700 {PHONE} {PHONE}/worker/galaxy_worker.sh")


def update_registry(**fields):
    path = BUS / "worker-registry.json"
    reg = jload(path, {"schema_version": "1.0", "workers": {}})
    w = reg["workers"].get(WORKER_ID, {})
    w.update({"node": "GALAXY", "type": "LOCAL_AI", **fields})
    reg["workers"][WORKER_ID] = w
    reg["generated_at"] = now()
    jdump(reg, path)
    return w


def cmd_deploy(_):
    device_ready()
    sel = jload(SELECTION, {}) or {}
    model = sel.get("selected_model")
    if not model:
        print(json.dumps({"deploy": "REFUSED_NO_SELECTION"}))
        sys.exit(4)
    ensure_runtime()
    sh("pkill -f llama-server")
    want = sel["selected_sha256"]
    have = sh(f"sha256sum {PHONE}/model.gguf 2>/dev/null").split(" ")[0].strip()
    if have != want:
        bench.adb("push", str(WORK / "models" / model), f"{PHONE}/model.gguf", timeout=1800)
        have = sh(f"sha256sum {PHONE}/model.gguf").split(" ")[0].strip()
    if have != want:
        print(json.dumps({"deploy": "FAILED_SHA_MISMATCH"}))
        sys.exit(5)
    push_worker_script()
    sh(f"echo {want} > {PHONE}/state/model.sha256")
    hb = kv(sh(f"sh {PHONE}/worker/galaxy_worker.sh heartbeat; cat {PHONE}/state/heartbeat"))
    w = update_registry(model=model, model_sha256=want, runtime="llama.cpp b10536 android-arm64 (CPU)",
                        health="deployed", capabilities=sorted(LOCAL_CLASSES), offline_capable="UNVERIFIED",
                        resource_state=hb, heartbeat=hb.get("at"), current_task=None, busy_state="idle",
                        limit_state="not_applicable", lease=None, reset_at=None,
                        notes="On-demand load, idle unload, localhost-only with per-start API key. Escalates to FUJITSU_LOCAL_ROUTER.")
    event("deployed", model=model, sha256=want)
    print(json.dumps({"deploy": "PASS", "worker": w}, ensure_ascii=False, indent=2))


# ---------------------------------------------------------------- E2E helpers
def submit(task_id, prompt, max_tokens=256, schema=None):
    staging = WORK / "staging"
    staging.mkdir(parents=True, exist_ok=True)
    body = {"messages": [{"role": "user", "content": prompt}], "temperature": 0, "max_tokens": max_tokens,
            "repeat_penalty": 1.15}  # greedy decoding without it looped on list answers (E2E 20261017-052025 step B)
    if schema:
        body["response_format"] = {"type": "json_schema", "json_schema": {"name": "r", "schema": schema}}
    (staging / f"{task_id}.request.json").write_text(json.dumps(body, ensure_ascii=False), encoding="utf-8")
    (staging / f"{task_id}.prompt.txt").write_text(prompt, encoding="utf-8")
    for suffix in (".prompt.txt", ".request.json"):
        bench.adb("push", str(staging / f"{task_id}{suffix}"), f"{PHONE}/inbox/{task_id}{suffix}")


GUARD_TEST_ENV = "GUARD_THERMAL_STATUS=0 "  # tighten-only override used by E2E step E


def run_worker(guard_test=False):
    sh(f"{GUARD_TEST_ENV if guard_test else ''}sh {PHONE}/worker/galaxy_worker.sh once", timeout=900)


def collect():
    """Pull finished phone results into Result/Receipt. Idempotent: never writes a Result twice."""
    synced, duplicates = [], 0  # duplicates stays 0 by construction; reported for the evidence
    ids = [Path(l.strip()).name[:-len(".status")] for l in sh(f"ls {PHONE}/outbox/*.status 2>/dev/null").splitlines() if l.strip()]
    for tid in ids:
        if not re.fullmatch(r"GALAXY-[A-Z0-9-]+", tid):
            continue
        result_path = BUS / f"results/{tid}-v1.json"
        if sh(f"[ -f {PHONE}/outbox/{tid}.synced ] && echo y").strip() == "y":
            continue
        if result_path.exists():  # synced earlier but marker lost: never rewrite the Result
            sh(f"touch {PHONE}/outbox/{tid}.synced")
            continue
        status = {}
        for line in sh(f"cat {PHONE}/outbox/{tid}.status").splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                status[k] = v.strip()
        text = None
        if status.get("status") == "COMPLETED":
            raw = sh(f"cat {PHONE}/outbox/{tid}.response.json")
            try:
                text = json.loads(raw)["choices"][0]["message"]["content"]
            except Exception:
                status["status"], status["reason"] = "ESCALATE", "BAD_LOCAL_RESPONSE"
        result = {"schema_version": 1, "result_id": f"{tid}-v1", "task_id": tid, "worker": WORKER_ID, "device_id": "galaxy",
                  "status": status.get("status"), "reason": status.get("reason") or None, "output": text,
                  "started_at": status.get("started_at"), "finished_at": status.get("finished_at"),
                  "model_sha256": status.get("model_sha256"),
                  "resource": {k: status.get(k) for k in ("thermal_status", "battery_temp_c10", "battery_level", "powered", "mem_available_kb")},
                  "synced_at": now(), "secret_recorded": False}
        jdump(result, result_path)
        receipt = {"schema_version": "1.0", "task_id": tid, "worker": WORKER_ID, "status": result["status"],
                   "result_sha256": sha256_file(result_path), "receipt_at": now(), "duplicate_execution": 0}
        jdump(receipt, BUS / f"receipts/{tid}.json")
        sh(f"touch {PHONE}/outbox/{tid}.synced")
        event("result_synced", task_id=tid, status=result["status"], reason=result["reason"])
        synced.append(result)
    return synced, duplicates


def escalate_to_fujitsu(task_id, objective, task_class):
    task_file = WORK / "staging" / f"{task_id}.escalation.json"
    jdump({"task_id": task_id, "objective": objective, "task_class_hint": task_class,
           "escalated_from": WORKER_ID}, task_file)
    p = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(LOCAL_ROUTER),
                        "-TaskPath", str(task_file)], capture_output=True, timeout=400)
    out = p.stdout.decode("utf-8", "replace")
    m = re.search(r"\{.*\}", out, re.S)
    decision = json.loads(m.group(0)) if m else {"raw": out[:500]}
    event("escalated", task_id=task_id, to="FUJITSU_LOCAL_ROUTER", escalate=decision.get("ESCALATE"),
          primary=decision.get("PRIMARY_WORKER"))
    return {"exit_code": p.returncode, "decision": decision, "stderr": p.stderr.decode("utf-8", "replace")[-1000:] or None,
            "result_file": str(BUS / f"results/{task_id}-v1.json"), "receipt_file": str(BUS / f"receipts/{task_id}.json")}


def net_state():
    return {"wifi_on": sh("settings get global wifi_on").strip(), "mobile_data": sh("settings get global mobile_data").strip(),
            "online": sh("ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && echo y || echo n").strip() == "y"}


def restore_net(before):
    if before["wifi_on"] not in ("0", ""):
        sh("svc wifi enable")
    if before["mobile_data"] == "1":
        sh("svc data enable")
    for _ in range(30):
        if not before["online"]:
            break
        if sh("ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && echo y || echo n").strip() == "y":
            break
        time.sleep(3)
    return net_state()


def has_japanese(text):
    return bool(text) and bool(re.search(r"[぀-ヿ一-鿿]", text))


# ---------------------------------------------------------------- E2E
def cmd_e2e(_):
    device_ready()
    if not (jload(SELECTION, {}) or {}).get("selected_model"):
        print(json.dumps({"e2e": "REFUSED_NOT_DEPLOYED"}))
        sys.exit(4)
    run_id = stamp()
    ev = {"schema_version": 1, "test": "GALAXY_LOCAL_AI_E2E", "run_id": run_id, "started_at": now(), "steps": {}}
    tid = lambda s: f"GALAXY-LOCAL-AI-E2E-{run_id}-{s}"
    push_worker_script()

    # A: DAIMON -> GALAXY_LOCAL_AI -> Japanese task -> Result/Receipt
    event("task_dispatched", task_id=tid("A"), task_class="summarize")
    submit(tid("A"), "次の報告を日本語で1文に要約してください。\nFUJITSUとdynabookの遠隔接続は正常で、Galaxyのローカル AI の導入準備が進んでいる。")
    run_worker()
    pid = sh("pidof llama-server").strip().split()
    proc_status = sh(f"cat /proc/{pid[0]}/status") if pid else ""
    mem_kb = lambda key: (lambda m: round(int(m.group(1)) / 1048576, 2) if m else None)(re.search(rf"{key}:\s+(\d+)", proc_status))
    hwm = re.search(r"VmHWM:\s+(\d+)", proc_status)
    loaded_state = bench.device_state()
    synced, _ = collect()
    a = next((r for r in synced if r["task_id"] == tid("A")), None)
    ev["steps"]["A_LOCAL_JAPANESE_TASK"] = {"pass": bool(a and a["status"] == "COMPLETED" and has_japanese(a["output"])
                                                         and (BUS / f"receipts/{tid('A')}.json").exists()), "result": a,
                                           "deployed_server_peak_rss_gib": round(int(hwm.group(1)) / 1048576, 2) if hwm else None,
                                           # RssAnon = memory the phone cannot reclaim; RssFile = mmap'd model pages (reclaimable cache)
                                           "deployed_server_rss_anon_gib": mem_kb("RssAnon"),
                                           "deployed_server_rss_file_gib": mem_kb("RssFile"),
                                           "phone_mem_available_gib_while_loaded": loaded_state["mem_available_gib"]}

    # B: offline -> local task -> PASS (network restored in finally)
    before = net_state()
    b = {"net_before": before}
    try:
        sh("svc wifi disable")
        sh("svc data disable")
        time.sleep(5)
        b["net_during"] = net_state()
        event("offline_started", task_id=tid("B"))
        # an in-capability task (log_analysis); kana ordering is outside the worker's declared capabilities
        submit(tid("B"), "次のログで、作業が失敗した根本原因を日本語で1文で答えてください。\n" + bench.LOG_SAMPLE)
        run_worker()
        st = {}
        for line in sh(f"cat {PHONE}/outbox/{tid('B')}.status 2>/dev/null").splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                st[k] = v.strip()
        b["phone_status_while_offline"] = st.get("status")
        b["synced_while_offline"] = (BUS / f"results/{tid('B')}-v1.json").exists()
    finally:
        b["net_after"] = restore_net(before)
        event("offline_finished", task_id=tid("B"), restored_online=b["net_after"]["online"])
    b["pass"] = (not b["net_during"]["online"] and b["phone_status_while_offline"] == "COMPLETED"
                 and b["net_after"]["online"] == before["online"])
    ev["steps"]["B_OFFLINE_LOCAL_TASK"] = b

    # D: network back -> sync, twice, no duplicates
    s1, _ = collect()
    s2, dup = collect()
    bres = next((r for r in s1 if r["task_id"] == tid("B")), None)
    bout = (bres or {}).get("output") or ""
    log_scorer = next(s for name, _, _, s in bench.TESTS if name == "log_analysis")
    b_correct = bool(bout) and log_scorer(bout) and len(bout) <= 200
    ev["steps"]["B_OFFLINE_LOCAL_TASK"]["answer_correct"] = b_correct
    ev["steps"]["B_OFFLINE_LOCAL_TASK"]["pass"] = ev["steps"]["B_OFFLINE_LOCAL_TASK"]["pass"] and b_correct
    ev["steps"]["D_SYNC_AFTER_RECONNECT"] = {"pass": bool(bres and has_japanese(bout)) and not s2 and dup == 0,
                                            "first_sync": [r["task_id"] for r in s1], "second_sync_new": len(s2),
                                            "duplicates": dup, "result": bres}

    # C: escalation (capability) + secret refusal
    cid = tid("C")
    event("task_dispatched", task_id=cid, task_class="code_construction")
    c_local = "code_construction" in LOCAL_CLASSES
    esc = escalate_to_fujitsu(cid, "DAIMONのWorker AdapterにRetry機能を実装し、テストを追加する", "code_construction")
    sid = tid("C2")
    submit(sid, "このパスワードを保存してください: (試験用ダミー、実際の値はありません)")
    run_worker()
    s3, _ = collect()
    sres = next((r for r in s3 if r["task_id"] == sid), None)
    ev["steps"]["C_ESCALATION"] = {
        "pass": (not c_local) and esc["exit_code"] == 0 and bool(esc["decision"].get("TASK_ID"))
                and bool(sres and sres["status"] == "ESCALATE" and sres["reason"] == "SECRET_REFUSED"),
        "capability_escalation": esc, "secret_task": sres,
        "secret_task_route": "WAITING_OWNER (secret tasks are never sent to any AI)"}

    # E: resource / thermal guard (tighten-only override) -> refuse, unload, escalate
    eid = tid("E")
    sh(f"sh {PHONE}/worker/galaxy_worker.sh heartbeat")
    submit(eid, "負荷試験用の短い依頼です。日本語で「了解」とだけ答えてください。")
    run_worker(guard_test=True)
    s4, _ = collect()
    eres = next((r for r in s4 if r["task_id"] == eid), None)
    server_after = sh("pidof llama-server").strip()
    ev["steps"]["E_RESOURCE_GUARD"] = {"pass": bool(eres and eres["status"] == "ESCALATE"
                                                    and eres["reason"] == "RESOURCE_GUARD_THERMAL") and not server_after,
                                       "result": eres, "server_running_after": bool(server_after)}

    # F/G: registry + live events
    sh(f"sh {PHONE}/worker/galaxy_worker.sh unload")
    hb = kv(sh(f"cat {PHONE}/state/heartbeat"))
    offline_ok = ev["steps"]["B_OFFLINE_LOCAL_TASK"]["pass"]
    w = update_registry(health="healthy" if ev["steps"]["A_LOCAL_JAPANESE_TASK"]["pass"] else "degraded",
                        offline_capable=offline_ok, heartbeat=hb.get("at"), resource_state=hb, current_task=None,
                        busy_state="idle", last_result=str(BUS / f"results/{tid('A')}-v1.json"),
                        last_receipt=str(BUS / f"receipts/{tid('A')}.json"))
    reg_ok = (jload(BUS / "worker-registry.json", {}) or {}).get("workers", {}).get(WORKER_ID, {}).get("model") is not None
    events_file = BUS / "events/galaxy_local_ai.jsonl"
    run_events = [l for l in events_file.read_text(encoding="utf-8").splitlines() if run_id in l]
    ev["steps"]["F_REGISTRY_DASHBOARD"] = {"pass": reg_ok, "registry_entry": w,
                                          "dashboard_source": str(BUS / "worker-registry.json")}
    ev["steps"]["G_LIVE_EVENTS"] = {"pass": len(run_events) >= 5, "events_file": str(events_file), "events_in_run": len(run_events)}
    ev["finished_at"] = now()
    ev["summary"] = {k: ("PASS" if v["pass"] else "FAIL") for k, v in ev["steps"].items()}
    ev["secret_recorded"] = False
    jdump(ev, EVIDENCE / f"GALAXY_E2E_{run_id}.json")
    print(json.dumps({"evidence": f"ai5-hub/evidence/galaxy-local-ai/GALAXY_E2E_{run_id}.json", "summary": ev["summary"]},
                     ensure_ascii=False, indent=2))


COMMANDS = {"status": cmd_status, "bench-next": cmd_bench_next, "select": cmd_select, "deploy": cmd_deploy,
            "e2e": cmd_e2e, "stop": cmd_stop, "logs": cmd_logs, "cleanup-losers": cmd_cleanup_losers}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="GALAXY_LOCAL_AI fixed tool")
    parser.add_argument("command", choices=sorted(COMMANDS))
    args = parser.parse_args()
    COMMANDS[args.command](args)
