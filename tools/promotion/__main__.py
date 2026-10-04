"""Run from the repository root: python -m tools.promotion --help."""
import argparse
import json
from pathlib import Path
import sys

from .common import Commands, Context, PromotionError, bundle, load, require
from . import monitor, observability, preflight, release


def private_output(path):
    resolved = Path(path).resolve()
    repo = Path(__file__).resolve().parents[2]
    require(not resolved.is_relative_to(repo), "Evidence/receipts must be outside the repository.")
    return resolved


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", help="Explicit context JSON; never contains credentials.")
    parser.add_argument("--output", help="Private evidence directory OUTSIDE the repository.")
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("preflight", "observe"):
        sub = commands.add_parser(command)
        sub.add_argument("--spec", required=True)
    sub = commands.add_parser("snapshot")
    sub.add_argument("--preflight", required=True)
    sub.add_argument("--phase", choices=("before", "after-infra", "final"), required=True)
    sub = commands.add_parser("compare")
    sub.add_argument("--before", required=True)
    sub.add_argument("--after", required=True)
    sub = commands.add_parser("source")
    sub.add_argument("--run", required=True)
    sub.add_argument("--sha", required=True)
    sub = commands.add_parser("deployment")
    sub.add_argument("--run", required=True)
    sub.add_argument("--sha", required=True)
    sub.add_argument("--source-run", required=True)
    sub.add_argument("--source-sha", required=True)
    sub.add_argument("--operation", choices=("promotion", "rollback"), required=True)
    sub = commands.add_parser("dispatch")
    sub.add_argument("--authorization", required=True)
    sub.add_argument("--preflight", required=True)
    sub.add_argument("--before", required=True)
    sub.add_argument("--receipts", required=True)
    sub.add_argument("--monitor")
    sub.add_argument("--execute", action="store_true")
    for command in ("baseline", "start-monitor"):
        sub = commands.add_parser(command)
        sub.add_argument("--spec", required=True)
        sub.add_argument("--sha", required=True)
        if command == "start-monitor":
            sub.add_argument("--baseline", required=True)
            sub.add_argument("--start", required=True)
    for command in ("monitor", "status", "retrospective"):
        sub = commands.add_parser(command)
        sub.add_argument("--monitor", required=True)
        if command == "monitor":
            sub.add_argument("--resume", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.command == "status":
            status = monitor.monitor_status(args.monitor)
            print(json.dumps({"state": status}))
            return 0 if status == "complete" else 2
        require(args.output is not None, "--output is required.")
        root = private_output(args.output)
        if args.command == "compare":
            path = bundle(root, "comparison", preflight.compare(args.before, args.after))
            safe = True
        else:
            require(args.context is not None, "--context is required.")
            api = Commands(Context(load(args.context)))
            safe = True
            if args.command == "preflight":
                path, safe = preflight.run_preflight(api, load(args.spec), root)
            elif args.command == "snapshot":
                path = preflight.snapshot(api, args.preflight, args.phase, root)
            elif args.command == "source":
                path = bundle(root, "source", release.source_proof(api, args.run, args.sha))
            elif args.command == "deployment":
                source = release.source_proof(api, args.source_run, args.source_sha)
                path = bundle(root, "deployment", release.deployment_proof(
                    api, args.run, args.sha, source, args.operation))
            elif args.command == "dispatch":
                path = release.dispatch(api, load(args.authorization), args.preflight, args.before,
                                        private_output(args.receipts), execute=args.execute,
                                        monitor_dir=args.monitor)
            elif args.command == "observe":
                path, safe = observability.observe(api, load(args.spec), root)
            elif args.command == "baseline":
                path = monitor.baseline(api, load(args.spec), api.context.scope(args.sha), root)
            elif args.command == "start-monitor":
                path = monitor.create_monitor(api, load(args.spec), api.context.scope(args.sha),
                                              args.baseline, args.start, root)
            elif args.command == "monitor":
                path = private_output(args.monitor)
                safe = monitor.run_monitor(api, path, resume=args.resume)
            elif args.command == "retrospective":
                path, safe = monitor.retrospective(api, args.monitor, root)
        print(json.dumps({"evidence": str(path), "result": "recorded" if safe else "blocked-or-unconfirmed"}))
        return 0 if safe else 2
    except PromotionError as error:
        print(f"promotion: {error}", file=sys.stderr)
        return 2
    except (OSError, KeyError, TypeError, ValueError):
        print("promotion: malformed input or unavailable local evidence; details suppressed.", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("promotion: interrupted; inspect evidence and explicitly resume or use retrospective.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
