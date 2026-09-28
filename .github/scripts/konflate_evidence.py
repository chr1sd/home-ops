#!/usr/bin/env python3
"""Evidence provider for the AI PR review: konflate's rendered Flux diff.

Called by misospace/pr-reviewer-action (see .github/konflate-evidence-providers.json)
with PR_NUMBER in the environment. Talks to konflate's read-only MCP endpoint
over the in-cluster Service (KONFLATE_MCP_URL) and prints the action's
evidence-provider JSON contract on stdout:

  {"severity": "info", "findings": [{"severity", "message", "source"}]}

Advisory, never a gate: on any failure, a render that already failed, or a render
still pending after the wait budget, it emits an empty findings list and exits 0.
Adapted from joryirving/home-ops .github/scripts/konflate_evidence.py.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get("KONFLATE_MCP_URL", "http://konflate.flux-system.svc.cluster.local:8080/mcp")
PUBLIC_URL = os.environ.get("KONFLATE_PUBLIC_URL", "https://konflate.dovis.me").rstrip("/")
PR = os.environ.get("PR_NUMBER", "").strip()
# konflate renders on the same pull_request webhook that starts this review, so the
# first get_pr_diff often lands before konflate has even listed the PR. Poll until
# the render appears rather than giving up on that first answer. The loop spends at
# most WAIT_SEC waiting plus one more round trip, which must stay under the
# provider's timeout_sec in .github/konflate-evidence-providers.json (150s) — past
# that the action kills the provider and the review loses the evidence entirely.
WAIT_SEC = int(os.environ.get("KONFLATE_WAIT_SEC", "120"))
POLL_SEC = 10
SID = None

# konflate flags every "no usable diff" answer with MCP's isError and puts a short
# plain sentence in the content (konflate internal/server/mcp.go); a real diff comes
# back without the flag. Trusting the flag beats substring-matching the response:
# phrases like "is tracked" occur in ordinary manifest YAML, and scanning the diff
# body for them threw real evidence away.
#
# Only a failed render is terminal — it will not succeed on a retry. The other two
# answers resolve on their own and are what the poll loop waits for:
#   "No pull request #N is tracked."                     konflate has not listed it yet
#   "PR #N has no rendered diff yet (status "pending")"  queued, or a worker is on it
_TERMINAL = ("failed to render", 'status "error"')


def emit(findings, severity="info"):
    print(json.dumps({"severity": severity, "findings": findings}))
    sys.exit(0)


def call(method, params=None, notif=False):
    global SID
    body = {"jsonrpc": "2.0", "method": method}
    if not notif:
        body["id"] = 1
    if params is not None:
        body["params"] = params
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json, text/event-stream")
    req.add_header("User-Agent", "ai-pr-reviewer-konflate/1.0")
    if SID:
        req.add_header("Mcp-Session-Id", SID)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            sid = r.headers.get("Mcp-Session-Id")
            if sid:
                SID = sid
            raw = r.read().decode()
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:200].replace("\n", " ")
        raise RuntimeError(f"HTTP {e.code} from {URL}: {detail}") from None
    if notif:
        return None
    # streamable HTTP: the JSON-RPC result arrives as an SSE data: line
    for line in raw.splitlines():
        if line.startswith("data:"):
            return json.loads(line[5:].strip())
    return None


def text(resp):
    out = []
    for c in (resp or {}).get("result", {}).get("content", []):
        if c.get("type") == "text":
            out.append(c["text"])
    return "\n".join(out).strip()


def is_error(resp):
    return bool((resp or {}).get("result", {}).get("isError"))


def is_terminal(t):
    low = (t or "").lower()
    return any(s in low for s in _TERMINAL)


def main():
    if not PR.isdigit():
        emit([])
    try:
        call("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                            "clientInfo": {"name": "konflate-evidence", "version": "0"}})
        call("notifications/initialized", notif=True)
        deadline = time.monotonic() + WAIT_SEC
        while True:
            resp = call("tools/call", {"name": "get_pr_diff", "arguments": {"number": int(PR)}})
            if not is_error(resp):
                break
            note = text(resp)
            remaining = deadline - time.monotonic()
            if is_terminal(note) or remaining <= 0:
                print(f"konflate evidence provider: no rendered diff for PR {PR} ({note[:120]!r})",
                      file=sys.stderr)
                emit([])
            # clamped so the last wait cannot overshoot the budget by a whole POLL_SEC
            time.sleep(min(POLL_SEC, remaining))
        diff = text(resp)
        summary_resp = call("tools/call", {"name": "get_pr_summary", "arguments": {"number": int(PR)}})
    except Exception as exc:  # advisory: never fail the review
        print(f"konflate evidence provider: {exc}", file=sys.stderr)
        emit([])

    if not diff:
        print(f"konflate evidence provider: empty diff for PR {PR}", file=sys.stderr)
        emit([])

    src = f"{PUBLIC_URL}/#/pr/{PR}"
    findings = [{
        "severity": "info",
        "message": "konflate rendered Flux diff (post-kustomize/Helm Kubernetes YAML — the "
                   "resources Flux will actually apply, not the raw template diff):\n\n" + diff,
        "source": src,
    }]
    summary = "" if is_error(summary_resp) else text(summary_resp)
    if summary:
        findings.append({"severity": "info", "message": summary, "source": src})
    emit(findings)


if __name__ == "__main__":
    main()
