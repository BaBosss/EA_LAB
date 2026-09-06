"""One-time mechanical transcription seed for portfolio/CERTIFICATION_SCOPE.csv.

docs/architecture/RUNTIME_IDENTITY_COVERAGE_CONTRACT_20260905.md requires the structured scope
owner to be populated by mechanically transcribing ONLY already-explicit facts from
portfolio/DEPLOYMENTS.csv; any ambiguous row must stay UNKNOWN. This script is the one-time
transcription tool, not a runtime dependency of monitoring (monitoring reads the resulting CSV
only -- see scripts/lib/certification_scope.ps1 -- and never re-parses DEPLOYMENTS.csv.notes).

Two explicit facts are transcribed automatically:
  - identity_mechanism_capability = NO_NATIVE_RUNTIME_IDENTITY_MT4 when DEPLOYMENTS.csv 'platform'
    is literally 'MT4' for that row (RuntimeIdentity has no MT4 producer in this repository).
  - identity_certification_scope = USER_OWNED_UNCERTIFIED when that row's OWN 'notes' field
    contains the literal phrase 'lab does not certify'.

Everything else is UNKNOWN by default -- including every MT5 row's mechanism capability, because
DEPLOYMENTS.csv does not prove which MT5 rows run the LabCore/Boss template with RuntimeIdentity
wired in versus a third-party/user-supplied MT5 EA.

ONE KNOWN TRAP, HANDLED EXPLICITLY (memory: text-scan-cannot-tell-read-from-mention):
  account 159503454 magic 991001's own notes field literally contains the substring
  'lab does not certify' -- but only because that row's note is DESCRIBING a DIFFERENT
  deployment (159475669's row 22) for cross-reference ("... same magic 991001 also runs on
  159475669 (row 22, user mix, lab does not certify) ..."). That row is itself the real-money,
  user-approved, lab-validated leg (ORDER-520/ORDER-943) -- the opposite of uncertified. A blind
  substring match would mislabel it. This script excludes that exact (account, magic) key from
  the automatic USER_OWNED_UNCERTIFIED match and leaves it UNKNOWN (no explicit self-certification
  phrase exists for it either, so UNKNOWN is the correct fail-closed answer, not an invented
  LAB_CERTIFIED label).

Run: python scripts/research/seed_certification_scope.py > portfolio/CERTIFICATION_SCOPE.csv
"""

import csv
import io
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEPLOYMENTS_PATH = os.path.join(REPO_ROOT, 'portfolio', 'DEPLOYMENTS.csv')

# The single known self-referential false-positive (see module docstring). Any future row that
# needs an exclusion like this must be added here explicitly, by hand, after a human/agent reads
# the actual note text -- never inferred automatically.
UNCERTIFIED_PHRASE_EXCLUSIONS = frozenset({('159503454', '991001')})

UNCERTIFIED_PHRASE = 'lab does not certify'

FIELDS = [
    'account', 'magic', 'identity_mechanism_capability', 'identity_certification_scope',
    'evidence_ref', 'status',
]


def classify(row):
    account = row['account'].strip()
    magic = row['magic'].strip()
    platform = row['platform'].strip().upper()
    notes = row['notes']
    notes_lower = notes.lower()

    if platform == 'MT4':
        mechanism = 'NO_NATIVE_RUNTIME_IDENTITY_MT4'
        mechanism_ref = 'DEPLOYMENTS.csv platform=MT4'
    else:
        mechanism = 'UNKNOWN'
        mechanism_ref = 'no explicit LabCore/RuntimeIdentity build-receipt binding recorded for this row'

    if (account, magic) in UNCERTIFIED_PHRASE_EXCLUSIONS:
        certification = 'UNKNOWN'
        cert_ref = ('DEPLOYMENTS.csv notes mentions "lab does not certify" only when describing a '
                     'DIFFERENT deployment (159475669 magic 991001) for cross-reference; this row '
                     'has no explicit self-certification statement')
    elif UNCERTIFIED_PHRASE in notes_lower:
        certification = 'USER_OWNED_UNCERTIFIED'
        cert_ref = 'DEPLOYMENTS.csv notes: literal "lab does not certify"'
    else:
        certification = 'UNKNOWN'
        cert_ref = 'no explicit certification-scope statement in DEPLOYMENTS.csv notes'

    evidence_ref = mechanism_ref if certification == 'UNKNOWN' and mechanism != 'UNKNOWN' else cert_ref
    if mechanism != 'UNKNOWN' and certification != 'UNKNOWN':
        evidence_ref = mechanism_ref + '; ' + cert_ref
    status = 'TRANSCRIBED'
    return {
        'account': account,
        'magic': magic,
        'identity_mechanism_capability': mechanism,
        'identity_certification_scope': certification,
        'evidence_ref': evidence_ref,
        'status': status,
    }


def main():
    with open(DEPLOYMENTS_PATH, encoding='utf-8-sig', newline='') as handle:
        rows = list(csv.DictReader(handle))

    active = [r for r in rows if r['status'].strip() == 'ACTIVE']
    seen = set()
    out_rows = []
    for row in active:
        account = row['account'].strip()
        magic = row['magic'].strip()
        if not re.fullmatch(r'[1-9][0-9]*', account) or not re.fullmatch(r'[1-9][0-9]*', magic):
            raise SystemExit('refusing to seed a row with a non-canonical account/magic key: %r' % (row,))
        key = (account, magic)
        if key in seen:
            raise SystemExit('duplicate account|magic key in DEPLOYMENTS.csv ACTIVE rows: %s' % (key,))
        seen.add(key)
        out_rows.append(classify(row))

    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=FIELDS, lineterminator='\n')
    writer.writeheader()
    for r in out_rows:
        writer.writerow(r)
    sys.stdout.write(buf.getvalue())


if __name__ == '__main__':
    main()
