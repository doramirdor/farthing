import json, subprocess, time, os, sys
PROMPTS = json.load(open("/private/tmp/claude-501/prompts20.json"))
PROXY = "http://127.0.0.1:8787"
def run(prompt, via_proxy):
    env = dict(os.environ)
    if via_proxy: env["ANTHROPIC_BASE_URL"] = PROXY
    else: env.pop("ANTHROPIC_BASE_URL", None)
    t0 = time.time()
    p = subprocess.run(["claude","-p",prompt,"--model","opus",
        "--output-format","json","--allowedTools",""],
        env=env, capture_output=True, text=True)
    dt = time.time()-t0
    try: d = json.loads(p.stdout)
    except: return {"error": p.stdout[:200] or p.stderr[:200], "sec": dt}
    u = d.get("usage",{})
    return {"cost": d.get("total_cost_usd"), "sec": dt,
        "in": u.get("input_tokens"), "cc": u.get("cache_creation_input_tokens"),
        "cr": u.get("cache_read_input_tokens"), "out": u.get("output_tokens"),
        "result": (d.get("result") or "")[:400]}
res = []
for i, pr in enumerate(PROMPTS):
    row = {"i": i+1, "prompt": pr[:120]}
    row["base"] = run(pr, False)
    row["comp"] = run(pr, True)
    res.append(row)
    json.dump(res, open("/private/tmp/claude-501/results.json","w"), indent=1)
    b, c = row["base"], row["comp"]
    print(f"[{i+1}/20] base=${b.get('cost')} in={b.get('in')} cr={b.get('cr')} | comp=${c.get('cost')} in={c.get('in')} cr={c.get('cr')}", flush=True)
print("DONE", flush=True)
