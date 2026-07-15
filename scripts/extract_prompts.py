import json, glob, re, os
files = glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"), recursive=True)
seen=set(); out=[]
kw = re.compile(r'\b(fix|refactor|implement|add|bug|error|function|test|debug|why|typescript|python|class|api|null|async|import|compile|type|build)\b', re.I)
for f in files:
    try: lines=open(f,encoding="utf-8").read().splitlines()
    except: continue
    for ln in lines:
        try: o=json.loads(ln)
        except: continue
        if o.get("type")!="user": continue
        m=o.get("message",{})
        c=m.get("content")
        if isinstance(c,list):
            c="".join(p.get("text","") for p in c if isinstance(p,dict) and p.get("type")=="text")
        if not isinstance(c,str): continue
        c=c.strip()
        # skip tool results, hooks, system noise, pastes
        if not c or c.startswith("<") or "tool_result" in c or "system-reminder" in c: continue
        if len(c)<25 or len(c)>600: continue
        if not kw.search(c): continue
        key=c[:80].lower()
        if key in seen: continue
        seen.add(key); out.append(c)
        if len(out)>=200: break
    if len(out)>=200: break
# take a spread of 20
import math
pick=[out[i] for i in range(0,len(out),max(1,len(out)//20))][:20]
json.dump(pick, open("/private/tmp/claude-501/prompts20.json","w"), indent=1)
print(f"candidates={len(out)} picked={len(pick)}")
for i,p in enumerate(pick): print(f"[{i+1}] {p[:90].replace(chr(10),' ')}")
