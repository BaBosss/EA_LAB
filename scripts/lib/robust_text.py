"""
robust_text.py - one hardened text reader for the whole EA_LAB intake pipeline.

WHY THIS EXISTS (paid for with 3 silent failures in one day, 2026-07-11):
  1. PROJECT_STATE.md  = UTF-8 bytes that had been decoded-as-cp1252 then re-saved
     (double-encoded "mojibake": 16k Thai chars unreadable).
  2. ORDER-091A intake = 374 EA sources were UTF-16 LE *without a BOM*; a naive
     utf-8/cp1252 decode does NOT raise - it returns NUL-interleaved garbage that
     matches no regex, so the parser silently saw "empty" files (this is the real
     reason ORDER-074's drive-wide scan missed 374 EAs).
  3. ORDER-091B / BOT MOGUL reports = UTF-16 LE *with* BOM (FF FE).

The lesson: on this corpus, "file looks empty / no matches" almost always means a
decode went wrong, NOT that the content is absent. Every script that reads raw EA
source / vendor reports MUST route through read_text_robust() so this class of
silent failure cannot recur.

Usage:
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
    from robust_text import read_text_robust
    text = read_text_robust(path)          # returns str, best-effort decoded
    text, enc = read_text_robust(path, return_encoding=True)
"""

def _looks_like_utf16(raw: bytes) -> str | None:
    """Detect BOM-less UTF-16 by NUL-byte density in the even/odd positions."""
    if len(raw) < 4:
        return None
    sample = raw[:4096]
    if not sample:
        return None
    even_nul = sample[0::2].count(0)
    odd_nul = sample[1::2].count(0)
    half = max(1, len(sample) // 2)
    # ASCII text in UTF-16LE has a NUL as every odd (high) byte; UTF-16BE the even.
    if odd_nul / half > 0.30 and even_nul / half < 0.10:
        return "utf-16-le"
    if even_nul / half > 0.30 and odd_nul / half < 0.10:
        return "utf-16-be"
    return None


def _looks_like_double_encoded(text: str) -> bool:
    """UTF-8 bytes decoded as cp1252 then re-saved leave signature sequences."""
    markers = ("Ã ", "Ã¸", "Ã¹",  # Ã /Ã¸/Ã¹ from Thai
               "â", "Ã°Ÿ")             # â€ / ð from em-dash/emoji
    hits = sum(text.count(m) for m in markers)
    return hits > 3


def read_text_robust(path, return_encoding: bool = False):
    """
    Read a text file and return its content as str, correctly decoded.

    Order of attempts:
      1. Honour a UTF-8/UTF-16 BOM if present.
      2. Sniff BOM-less UTF-16 via NUL-density (the ORDER-091A killer).
      3. Try strict UTF-8.
      4. Detect UTF-8-double-encoded-as-cp1252 mojibake and reverse it.
      5. Fall back to cp1252, then latin-1 (never raises).
    """
    with open(path, "rb") as fh:
        raw = fh.read()

    def _done(text, enc):
        return (text, enc) if return_encoding else text

    if raw.startswith(b"\xef\xbb\xbf"):
        return _done(raw[3:].decode("utf-8", "replace"), "utf-8-sig")
    if raw.startswith(b"\xff\xfe"):
        return _done(raw[2:].decode("utf-16-le", "replace"), "utf-16-le-bom")
    if raw.startswith(b"\xfe\xff"):
        return _done(raw[2:].decode("utf-16-be", "replace"), "utf-16-be-bom")

    guessed = _looks_like_utf16(raw)
    if guessed:
        return _done(raw.decode(guessed, "replace"), guessed + "-nobom")

    try:
        text = raw.decode("utf-8")
        return _done(text, "utf-8")
    except UnicodeDecodeError:
        pass

    # cp1252 never raises; use it to inspect for double-encoding, then reverse.
    cp = raw.decode("cp1252", "replace")
    if _looks_like_double_encoded(cp):
        fixed = cp
        for _ in range(3):
            try:
                cand = fixed.encode("cp1252").decode("utf-8")
            except (UnicodeEncodeError, UnicodeDecodeError):
                break
            if not _looks_like_double_encoded(cand):
                fixed = cand
                break
            fixed = cand
        return _done(fixed, "utf-8-double-encoded-reversed")

    return _done(cp, "cp1252")


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        t, e = read_text_robust(p, return_encoding=True)
        print(f"{e:32s} {len(t):8d} chars  {p}")
