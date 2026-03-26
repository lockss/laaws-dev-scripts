#!/usr/bin/env python3
"""Show PersistentVolume mount info and disk usage for LOCKSS Kubernetes pods."""

import argparse
import json
import os
import subprocess
import sys

K8S_CFG = os.path.expanduser("~lockss/lockss-installer/config/k8s.cfg")

# Aliases for the lazy (matches kcid conventions)
ALIASES = {
    "cfg": "config",
    "mdx": "metadata-extract",
    "mdq": "metadata-service",
}


def load_kubectl_cmd():
    """Read KUBECTL_CMD from k8s.cfg; fall back to plain 'kubectl'."""
    if os.path.isfile(K8S_CFG):
        with open(K8S_CFG) as f:
            for line in f:
                line = line.strip()
                if line.startswith("KUBECTL_CMD="):
                    val = line.split("=", 1)[1].strip('"').strip("'")
                    return val.split()
    return ["kubectl"]


KUBECTL_CMD = load_kubectl_cmd()


def kubectl(*args):
    """Run a kubectl command; return stdout or None on failure."""
    r = subprocess.run([*KUBECTL_CMD, *args], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"kubectl error: {r.stderr.strip()}", file=sys.stderr)
        return None
    return r.stdout


def find_pods(pattern, namespace):
    raw = kubectl("get", "pods", "-n", namespace, "-o", "json")
    if not raw:
        return []
    return [
        p for p in json.loads(raw).get("items", [])
        if pattern in p["metadata"]["name"]
    ]


def pvc_to_pv_map(namespace):
    """Return {pvc_name: pv_object} for all PVCs in the namespace."""
    pvc_raw = kubectl("get", "pvc", "-n", namespace, "-o", "json")
    pv_raw = kubectl("get", "pv", "-o", "json")
    if not pvc_raw or not pv_raw:
        return {}
    pvs = {p["metadata"]["name"]: p for p in json.loads(pv_raw)["items"]}
    result = {}
    for pvc in json.loads(pvc_raw)["items"]:
        vn = pvc["spec"].get("volumeName", "")
        if vn in pvs:
            result[pvc["metadata"]["name"]] = pvs[vn]
    return result


def host_path(pv):
    """Extract the host-side path from a PV spec."""
    s = pv.get("spec", {})
    if "hostPath" in s:
        return s["hostPath"]["path"]
    if "local" in s:
        return s["local"]["path"]
    if "nfs" in s:
        return f'{s["nfs"].get("server", "?")}:{s["nfs"].get("path", "?")}'
    return "N/A"


def pv_mounts(pod, pvc_pv):
    """Get PV and hostPath volume mounts from a pod's containers.

    Returns list of dicts: {pv_name, host_path, container_mount}
    """
    spec = pod["spec"]
    vol_info = {}  # vol_name -> {host_path, pv_name}

    for v in spec.get("volumes", []):
        if "persistentVolumeClaim" in v:
            pvc_name = v["persistentVolumeClaim"]["claimName"]
            pv = pvc_pv.get(pvc_name)
            if pv:
                vol_info[v["name"]] = {
                    "host_path": host_path(pv),
                    "pv_name": pv["metadata"]["name"],
                }
        elif "hostPath" in v:
            vol_info[v["name"]] = {
                "host_path": v["hostPath"]["path"],
                "pv_name": "(hostPath)",
            }

    mounts = []
    seen = set()
    for ctr in spec.get("containers", []):
        for vm in ctr.get("volumeMounts", []):
            key = (vm["name"], vm["mountPath"])
            if vm["name"] in vol_info and key not in seen:
                seen.add(key)
                info = vol_info[vm["name"]]
                mounts.append({
                    "pv_name": info["pv_name"],
                    "host_path": info["host_path"],
                    "container_mount": vm["mountPath"],
                })
    return mounts


def parse_df(raw):
    """Parse df -h output, handling wrapped long device names."""
    lines = raw.strip().split("\n")[1:]
    entries = []
    i = 0
    while i < len(lines):
        parts = lines[i].split()
        # Handle wrapped lines where the device name is on its own line
        if len(parts) == 1 and i + 1 < len(lines):
            parts += lines[i + 1].split()
            i += 2
        else:
            i += 1
        if len(parts) >= 6:
            entries.append({
                "fs": parts[0],
                "size": parts[1],
                "used": parts[2],
                "avail": parts[3],
                "use_pct": parts[4],
                "mount": " ".join(parts[5:]),
            })
    return entries


def df_for_path(entries, path):
    """Longest-prefix match of path against df mount points."""
    best = None
    for e in entries:
        mp = e["mount"]
        if path == mp or path.startswith(mp.rstrip("/") + "/") or mp == "/":
            if not best or len(mp) > len(best["mount"]):
                best = e
    return best


def print_table(headers, rows):
    if not rows:
        print("  (no rows)")
        return
    widths = [
        max(len(h), *(len(r[i]) for r in rows))
        for i, h in enumerate(headers)
    ]
    fmt = "  ".join(f"{{:<{w}}}" for w in widths)
    print(fmt.format(*headers))
    print(fmt.format(*("-" * w for w in widths)))
    for r in rows:
        print(fmt.format(*r))


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        epilog="Aliases: " + ", ".join(
            f"{k} -> {v}" for k, v in sorted(ALIASES.items())
        ),
    )
    ap.add_argument("pattern", help="pod name, substring, or alias to match")
    ap.add_argument("-n", "--namespace", default="lockss",
                    help="Kubernetes namespace (default: lockss)")
    args = ap.parse_args()

    namespace = args.namespace
    pattern = ALIASES.get(args.pattern, args.pattern)

    pods = find_pods(pattern, namespace)
    if not pods:
        print(f"No pods matching '{pattern}' in namespace '{namespace}'")
        if args.pattern in ALIASES:
            print(f"  (alias '{args.pattern}' expanded to '{pattern}')")
        sys.exit(1)

    pvc_pv = pvc_to_pv_map(namespace)
    headers = [
        "PV Name", "Host FS", "Host Mount",
        "Container Mount", "Size", "Used", "Avail", "Use%",
    ]

    for pod in pods:
        name = pod["metadata"]["name"]
        phase = pod.get("status", {}).get("phase", "Unknown")
        mounts = pv_mounts(pod, pvc_pv)

        sep = "=" * 90
        print(f"\n{sep}")
        print(f"Pod: {name}  (phase: {phase})")
        print(sep)

        if not mounts:
            print("  No PV/hostPath mounts found.")
            continue

        df_entries = []
        if phase == "Running":
            raw = kubectl("exec", "-n", namespace, name, "--", "df", "-h")
            if raw:
                df_entries = parse_df(raw)
        else:
            print("  (pod not running -- disk usage unavailable)")

        rows = []
        for m in mounts:
            d = df_for_path(df_entries, m["container_mount"])
            rows.append([
                m["pv_name"],
                d["fs"] if d else "?",
                m["host_path"],
                m["container_mount"],
                d["size"] if d else "?",
                d["used"] if d else "?",
                d["avail"] if d else "?",
                d["use_pct"] if d else "?",
            ])

        print_table(headers, rows)

    print()


if __name__ == "__main__":
    main()
