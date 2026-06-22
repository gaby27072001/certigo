#!/usr/bin/env python3
"""Compile Microlingo content-as-code into Cosmos documents.

Reads content/<track>/track.yaml and content/<track>/lessons/*.lesson.yaml and
emits one JSON document per track and per lesson into tools/seed_output/ (the
shape stored in the Cosmos `content` container, partitioned by /trackId).

Key rule: the answer key (`correct`, `explanation`) is kept in a SEPARATE
server-only document (`type: answerKey`). The lesson document that ships to
clients is stripped of answers — grading is authoritative server-side.

Usage:
    python tools/seed_content.py                # write JSON to tools/seed_output/
    python tools/seed_content.py --cosmos       # also upsert to Cosmos DB
                                                # (needs azure-cosmos + env var
                                                #  COSMOS_ENDPOINT). Auth:
                                                #  - COSMOS_KEY set  -> key auth
                                                #    (Cosmos emulator / local).
                                                #  - COSMOS_KEY unset -> AAD via
                                                #    DefaultAzureCredential
                                                #    (required when the account
                                                #    has disableLocalAuth=true,
                                                #    e.g. policy-hardened Azure).
                                                #    Needs azure-identity and a
                                                #    Cosmos data-plane role
                                                #    (Built-in Data Contributor).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
OUT = Path(__file__).resolve().parent / "seed_output"


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def public_block(block: dict) -> dict:
    """Strip the answer key from a block's inline check."""
    out = {k: v for k, v in block.items() if k != "check"}
    if "check" in block and block["check"]:
        item = block["check"]
        out["check"] = {
            "id": item["id"],
            "conceptId": item["conceptId"],
            "type": item["type"],
            "stem": item["stem"],
            "options": item["options"],
        }
    return out


def answer_keys(lesson: dict) -> list[dict]:
    keys = []
    for block in lesson.get("blocks", []):
        item = block.get("check")
        if item:
            keys.append({
                "itemId": item["id"],
                "conceptId": item["conceptId"],
                "type": item["type"],
                "difficulty": item.get("difficulty", 1),
                "correct": item["correct"],
                "explanation": item["explanation"],
            })
    return keys


def build_documents() -> list[dict]:
    docs: list[dict] = []
    for track_file in sorted(CONTENT.glob("*/track.yaml")):
        track = load_yaml(track_file)
        track_id = track["id"]
        # The track document id is the bare track id so the domain `Track.Id`
        # deserializes correctly (the backend point-reads by trackId).
        docs.append({
            **track,
            "type": "track",
            "trackId": track_id,
        })

        for lesson_file in sorted((track_file.parent / "lessons").glob("*.lesson.yaml")):
            lesson = load_yaml(lesson_file)
            # Public lesson (no answers) — sent to clients. The document id is the
            # bare lesson id (the backend point-reads lessons by lessonId).
            docs.append({
                "id": lesson["id"],
                "type": "lesson",
                "trackId": track_id,
                "lessonId": lesson["id"],
                "unitId": lesson["unitId"],
                "domainId": lesson["domainId"],
                "title": lesson["title"],
                "estMinutes": lesson["estMinutes"],
                "blocks": [public_block(b) for b in lesson["blocks"]],
            })
            # Server-only answer key (carries item type/difficulty/domain so the
            # grader can score XP and map concepts to exam domains).
            keys = answer_keys(lesson)
            if keys:
                docs.append({
                    "id": f"answerkey::{lesson['id']}",
                    "type": "answerKey",
                    "trackId": track_id,
                    "lessonId": lesson["id"],
                    "domainId": lesson["domainId"],
                    "items": keys,
                })
    return docs


def write_local(docs: list[dict]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for doc in docs:
        (OUT / f"{doc['id'].replace('::', '__')}.json").write_text(
            json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    print(f"[ok] Wrote {len(docs)} documents to {OUT.relative_to(ROOT)}")


def upsert_cosmos(docs: list[dict]) -> None:
    try:
        from azure.cosmos import CosmosClient
    except ImportError:
        sys.exit("azure-cosmos required for --cosmos: pip install azure-cosmos")
    endpoint = os.environ["COSMOS_ENDPOINT"]
    key = os.environ.get("COSMOS_KEY")
    if key:
        credential: object = key
    else:
        # No key -> AAD. Required when the account has disableLocalAuth=true
        # (key auth disabled by security policy). Uses the Azure CLI / managed
        # identity login; the principal needs a Cosmos data-plane role.
        try:
            from azure.identity import DefaultAzureCredential
        except ImportError:
            sys.exit(
                "azure-identity required when COSMOS_KEY is unset (AAD auth): "
                "pip install azure-identity"
            )
        credential = DefaultAzureCredential()
    client = CosmosClient(endpoint, credential=credential)
    container = client.get_database_client("microlingo").get_container_client("content")
    for doc in docs:
        container.upsert_item(doc)
    print(f"[ok] Upserted {len(docs)} documents to Cosmos (content).")


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed Microlingo content.")
    parser.add_argument("--cosmos", action="store_true", help="Upsert to Cosmos DB.")
    args = parser.parse_args()

    docs = build_documents()
    write_local(docs)
    if args.cosmos:
        upsert_cosmos(docs)


if __name__ == "__main__":
    main()
