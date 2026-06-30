# Copyright 2025 CNOE
# SPDX-License-Identifier: Apache-2.0

"""Remediation MCP Server — pod restart with explicit human approval gate.

Two-tool design:
  propose_pod_restart  — read-only: verifies pod exists, returns a restart
                         plan for human review. No side effects.
  execute_pod_restart  — write: deletes the pod. ONLY call after the user
                         has explicitly approved the plan via CAIPEAgentResponse.

Requires KUBECONFIG to be set or a kubeconfig mounted at the default path.
"""

import json
import logging
import os
import subprocess
from dotenv import load_dotenv
from fastmcp import FastMCP

mcp = FastMCP("Remediation MCP Server")

logger = logging.getLogger(__name__)


def _kubectl(args: list[str], timeout: int = 15) -> tuple[int, str, str]:
    result = subprocess.run(
        ["kubectl"] + args,
        capture_output=True, text=True, timeout=timeout
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()


@mcp.tool()
async def propose_pod_restart(pod_name: str, namespace: str) -> str:
    """Inspect the target pod and return a restart plan. Does NOT modify anything.

    Call this first. Only call execute_pod_restart after the user explicitly
    approves the plan returned here.
    """
    rc, stdout, stderr = _kubectl(
        ["get", "pod", pod_name, "-n", namespace, "-o", "json"]
    )
    if rc != 0:
        return f"ERROR: Cannot inspect pod — {stderr}"

    try:
        pod = json.loads(stdout)
    except json.JSONDecodeError:
        return f"ERROR: Unexpected kubectl output — {stdout}"

    owner_refs = pod.get("metadata", {}).get("ownerReferences", [])
    if owner_refs:
        owners = ", ".join(f"{r['kind']}/{r['name']}" for r in owner_refs)
        recreation_note = "Kubernetes will schedule a replacement pod automatically."
    else:
        owners = "none"
        recreation_note = (
            "WARNING: This pod has no owner (orphan). "
            "It will NOT be recreated after deletion."
        )

    phase = pod.get("status", {}).get("phase", "Unknown")
    containers = pod.get("spec", {}).get("containers", [])
    image_list = ", ".join(c.get("image", "?") for c in containers)

    return (
        f"POD RESTART PLAN\n"
        f"================\n"
        f"Pod:        {pod_name}\n"
        f"Namespace:  {namespace}\n"
        f"Phase:      {phase}\n"
        f"Images:     {image_list}\n"
        f"Owners:     {owners}\n"
        f"\n"
        f"Proposed action: kubectl delete pod {pod_name} -n {namespace}\n"
        f"\n"
        f"Effect: {recreation_note}\n"
        f"No other pods or resources will be affected.\n"
        f"\n"
        f"Awaiting explicit user approval before executing."
    )


@mcp.tool()
async def execute_pod_restart(pod_name: str, namespace: str) -> str:
    """Delete the pod to trigger a clean restart via Kubernetes self-healing.

    ONLY call this after the user has explicitly approved the plan from
    propose_pod_restart. Do NOT call speculatively or without confirmation.
    """
    logger.info(f"Executing pod restart: pod={pod_name} namespace={namespace}")
    rc, stdout, stderr = _kubectl(
        ["delete", "pod", pod_name, "-n", namespace, "--wait=false"],
        timeout=30
    )
    if rc != 0:
        return f"ERROR: kubectl delete failed — {stderr}"
    return (
        f"Pod {pod_name} deleted from namespace {namespace}.\n"
        f"{stdout}\n"
        f"Kubernetes will schedule a replacement pod if a Deployment or "
        f"ReplicaSet owns this pod."
    )


def main():
    load_dotenv()
    logging.basicConfig(level=logging.INFO)
    mcp_mode = os.getenv("MCP_MODE", "stdio")
    mcp_host = os.getenv("MCP_HOST", "0.0.0.0")
    mcp_port = int(os.getenv("MCP_PORT", "8000"))

    logger.info(f"Starting Remediation MCP server in {mcp_mode} mode on {mcp_host}:{mcp_port}")

    if mcp_mode.lower() in ("sse", "http"):
        mcp.run(transport="sse", host=mcp_host, port=mcp_port)
    else:
        mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
