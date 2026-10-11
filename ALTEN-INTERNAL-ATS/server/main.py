from fastapi import FastAPI, Depends, HTTPException

app = FastAPI(title="ATS Copilot Dashboard API", version="0.1.0")

def current_role() -> str:
    return "recruiter"

RBAC = {
    "recruiter": {"overview", "queue"},
    "hm":        {"overview", "pipeline", "queue", "rubric"},
    "hrd":       {"overview", "pipeline", "queue", "quality", "fairness", "governance", "rubric"},
    "dpo":       {"overview", "fairness", "governance", "rubric"},
    "mco":       {"overview", "pipeline", "queue", "quality", "operations", "rubric"},
}

def require(page: str):
    def _inner(role: str = Depends(current_role)):
        if page not in RBAC.get(role, set()):
            raise HTTPException(status_code=403, detail="forbidden")
        return role
    return _inner

@app.get("/dashboard/kpis")
def kpis(_=Depends(require("overview"))): return {"items": []}

@app.get("/dashboard/funnel")
def funnel(_=Depends(require("pipeline"))): return {"items": []}

@app.get("/dashboard/queue")
def queue(_=Depends(require("queue"))): return {"items": []}

@app.get("/dashboard/quality")
def quality(_=Depends(require("quality"))): return {"items": []}

@app.get("/dashboard/fairness")
def fairness(_=Depends(require("fairness"))): return {"items": []}

@app.get("/dashboard/operations")
def operations(_=Depends(require("operations"))): return {"items": []}
