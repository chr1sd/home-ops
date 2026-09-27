#!/usr/bin/env python3
"""Evidence provider for the AI PR review: konflate's rendered Flux diff.

Called by misospace/pr-reviewer-action (see .github/konflate-evidence-providers.json)
with PR_NUMBER in the environment. Talks to konflate's read-only MCP endpoint
over the in-cluster Service (KONFLATE_MCP_URL) and prints the action's
evidence-provider JSON contract on stdout:

  {"severity": "info", "findings": [{"severity", "message", "source"}]}

Advisory, never a gate: on any failure, an untracked PR, or a render that is
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
# konflate renders on the PR webhook; the review usually starts while that render
# is still running, so poll briefly instead of giving up on the first "still
# rendering". Keep the total under the provider timeout in the providers file.
WAIT_SEC = int(os.environ.get("KONFLATE_WAIT_SEC", "90"))
POLL_SEC = 10
SID = None

# konflate answers with a plain sentinel when there is no usable diff: PR not
# tracked ("No pull request #N is tracked."), render pending ("has no rendered
# diff yet", "Still rendering"). Never present those as evidence.
_NO_DIFF = ("no pull request", "is tracked", "no rendered diff", "still rendering", "has no rendered")
_PENDING = ("still rendering", "no rendered diff", "has no rendered")


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


def is_no_diff(t):
    low = (t or "").lower()
    return (not t) or any(s in low for s in _NO_DIFF)


def is_pending(t):
    low = (t or "").lower()
    return any(s in low for s in _PENDING)


def main():
    if not PR.isdigit():
        emit([])
    try:
        call("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                            "clientInfo": {"name": "konflate-evidence", "version": "0"}})
        call("notifications/initialized", notif=True)
        deadline = time.monotonic() + WAIT_SEC
        while True:
            diff = text(call("tools/call", {"name": "get_pr_diff", "arguments": {"number": int(PR)}}))
            if not (is_pending(diff) and time.monotonic() < deadline):
                break
            time.sleep(POLL_SEC)
        summary = text(call("tools/call", {"name": "get_pr_summary", "arguments": {"number": int(PR)}}))
    except Exception as exc:  # advisory: never fail the review
        print(f"konflate evidence provider: {exc}", file=sys.stderr)
        emit([])

    if is_no_diff(diff):
        print(f"konflate evidence provider: no rendered diff for PR {PR} ({(diff or '')[:80]!r})", file=sys.stderr)
        emit([])

    src = f"{PUBLIC_URL}/#/pr/{PR}"
    findings = [{
        "severity": "info",
        "message": "konflate rendered Flux diff (post-kustomize/Helm Kubernetes YAML — the "
                   "resources Flux will actually apply, not the raw template diff):\n\n" + diff,
        "source": src,
    }]
    if summary and not is_no_diff(summary):
        findings.append({"severity": "info", "message": summary, "source": src})
    emit(findings)


if __name__ == "__main__":
    main()
