import json, subprocess, time, os
PROMPTS = json.load(open("/private/tmp/claude-501/prompts20.json"))
TERSE = ("scrooge terse-output layer. Lead with the answer or code. No preamble, "
         "no restating the question. Prefer code blocks and short lists over paragraphs. "
         "No wrap-up summary unless asked. Cut hedging and filler. One good example beats three. "
         "Revert to full prose only for security warnings, irreversible-action confirmations, "
         "or ambiguous multi-step plans.")
def run(prompt, terse):
    cmd = ["claude","-p",prompt,"--model","opus","--output-format","json","--allowedTools",""]
    if terse: cmd += ["--append-system-prompt", TERSE]
    t0=time.time()
    p=subprocess.run(cmd, capture_output=True, text=True)
    dt=time.time()-t0
    try: d=json.loads(p.stdout)
    except: return {"error":(p.stdout or p.stderr)[:200],"sec":dt}
    u=d.get("usage",{})
    return {"cost":d.get("total_cost_usd"),"sec":dt,"in":u.get("input_tokens"),
        "cc":u.get("cache_creation_input_tokens"),"cr":u.get("cache_read_input_tokens"),
        "out":u.get("output_tokens"),"result":(d.get("result") or "")[:400]}
res=[]
for i,pr in enumerate(PROMPTS):
    row={"i":i+1,"prompt":pr[:120]}
    row["base"]=run(pr, False)
    row["scrooge"]=run(pr, True)
    res.append(row)
    json.dump(res, open("/private/tmp/claude-501/scrooge_results.json","w"), indent=1)
    b,s=row["base"],row["scrooge"]
    print(f"[{i+1}/20] base=${b.get('cost')} out={b.get('out')} | scrooge=${s.get('cost')} out={s.get('out')}", flush=True)
print("DONE", flush=True)
