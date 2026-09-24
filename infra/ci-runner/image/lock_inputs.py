"""Shared, standard-library-only primitives for network input evidence."""

import hashlib
import json
import re
import subprocess
import tempfile
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SNAPSHOT = "https://snapshot.ubuntu.com/ubuntu/20260807T000000Z/"
MICROSOFT = "https://packages.microsoft.com/repos/azure-cli/"
UBUNTU_KEY = "F6ECB3762474EDA9D21B7022871920D1991BC93C"
MICROSOFT_KEY = "BC528686B50D79E339D3721CEB3E94ADBE1229CF"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def file_hash(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def run(args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    require(result.returncode == 0,
            f"Command failed ({result.returncode}): {args}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def checked_file(path, digest, size=None):
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), f"Missing/nonregular input: {path}")
    require(re.fullmatch("[0-9a-f]{64}", digest), "Invalid SHA256")
    require(file_hash(path) == digest, f"SHA256 mismatch: {path}")
    if size is not None:
        require(path.stat().st_size == size, f"Size mismatch: {path}")
    return path


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError(f"Unexpected redirect: {req.full_url} -> {newurl}")


def fetch(url, destination, digest=None, size=None):
    """Never follow redirects, reuse only verified bytes, publish atomically."""
    require(url.startswith("https://"), f"HTTPS required: {url}")
    destination = Path(destination)
    if destination.exists() and digest:
        return checked_file(destination, digest, size)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as stream:
        temporary = Path(stream.name)
    try:
        for attempt in range(3):
            try:
                with urllib.request.build_opener(NoRedirect).open(url, timeout=30) as response:
                    require(response.geturl() == url, f"URL changed: {url}")
                    with temporary.open("wb") as stream:
                        while block := response.read(1024 * 1024):
                            stream.write(block)
                break
            except (urllib.error.URLError, TimeoutError) as error:
                if isinstance(error, urllib.error.HTTPError) or attempt == 2:
                    raise ValueError(f"Download failed: {url}: {error}") from error
                print(f"Retrying {url}: {error}", file=sys.stderr, flush=True)
                time.sleep(attempt + 1)
        if digest:
            checked_file(temporary, digest, size)
        require(temporary.stat().st_size > 0, f"Empty artifact: {url}")
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
    return destination


def paragraphs(text):
    for paragraph in text.strip().split("\n\n"):
        fields = {}
        last = None
        for line in paragraph.splitlines():
            if line.startswith((" ", "\t")):
                require(last is not None, "Unattached Debian continuation")
                fields[last] += "\n" + line
            else:
                last, value = line.split(":", 1)
                require(last not in fields, f"Duplicate Debian field: {last}")
                fields[last] = value.lstrip()
        yield fields


def serialize(fields):
    return "".join(f"{key}: {value}\n" for key, value in fields.items()) + "\n"


def signature(release, keyring, fingerprint, home):
    output = run(["gpgv", "--homedir", str(home), "--status-fd", "1",
                  "--keyring", str(keyring), str(release)])
    valid = re.findall(r"^\[GNUPG:\] VALIDSIG ([A-F0-9]+) .*$", output, re.M)
    require(valid == [fingerprint], f"Unexpected release signer: {valid}")
    text = Path(release).read_text()
    body = text.split("\n\n", 1)[1].split("-----BEGIN PGP SIGNATURE-----", 1)[0]
    return next(paragraphs(body.replace("\n- ", "\n")))


def release_index(release, path):
    rows = [line.split() for line in release["SHA256"].splitlines() if line.strip()]
    matches = [row for row in rows if row[2] == path]
    require(len(matches) == 1, f"Missing/duplicate signed index: {path}")
    digest, size, _ = matches[0]
    return digest, int(size)


def artifact_url(base, filename):
    require(not filename.startswith("/") and ".." not in filename.split("/"),
            f"Unsafe artifact path: {filename}")
    url = base + filename
    require(urllib.parse.urlsplit(url).query == "" and
            urllib.parse.urlsplit(url).fragment == "" and
            urllib.parse.urlsplit(url).netloc == urllib.parse.urlsplit(base).netloc,
            f"Unexpected artifact URL: {url}")
    return url


def compare_lock(actual, expected):
    require(actual == expected, "Lock differs from the replayed artifact graph (omission/addition/change)")
