#!/usr/bin/env python3
import argparse, json, re, sys
import math
from datetime import datetime
from decimal import Decimal
from html.parser import HTMLParser

NUM_TOKEN = r"[+-]?(?:\d+|\d{1,3}(?: \d{3})+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?"


class ReportQualificationError(ValueError):
    """Input is not a complete supported MT5 Strategy Tester report."""


class _ReportHTML(HTMLParser):
    """Read actual table cells; comments/scripts cannot supply report fields.

    MT5 emits explicit end tags. Requiring them intentionally rejects browser-
    repairable fragments as well as truncated files rather than guessing values.
    """
    VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
            'link', 'meta', 'param', 'source', 'track', 'wbr'}
    BOOLEAN_ATTRIBUTES = {
        'allowfullscreen', 'async', 'autofocus', 'autoplay', 'checked',
        'controls', 'default', 'defer', 'disabled', 'formnovalidate', 'hidden',
        'inert', 'ismap', 'itemscope', 'loop', 'multiple', 'muted', 'nomodule',
        'novalidate', 'nowrap', 'open', 'playsinline', 'readonly', 'required',
        'reversed', 'selected',
    }
    NON_REPORT_CONTAINERS = {
        'button', 'datalist', 'iframe', 'noembed', 'noframes', 'noscript',
        'object', 'optgroup', 'option', 'plaintext', 'script', 'select',
        'template', 'textarea', 'xmp',
    }

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.tables = []
        self.row = None
        self.cell = None
        self.title = []
        self.html_count = self.body_count = self.title_count = 0

    def fail(self, message):
        raise ReportQualificationError('MT5_REPORT_INVALID: ' + message)

    def _raw_tag(self, text, start):
        """Consume one complete raw token, before HTMLParser can repair it."""
        ws = ' \t\r\n\f'
        closing = text.startswith('</', start)
        pos = start + (2 if closing else 1)
        name = re.compile(r'[A-Za-z][A-Za-z0-9:_-]*').match(text, pos)
        if not name:
            self.fail('invalid raw tag name')
        tag, pos = name.group().lower(), name.end()
        attrs = set()
        while pos < len(text):
            before = pos
            while pos < len(text) and text[pos] in ws:
                pos += 1
            if text.startswith('>', pos):
                return pos + 1, tag, closing
            if not closing and text.startswith('/>', pos):
                if tag not in self.VOID:
                    self.fail('self-closing structural tag')
                return pos + 2, tag, False
            if closing or pos == before:
                self.fail('malformed raw tag delimiter')
            attr = re.compile(r'[A-Za-z_:][A-Za-z0-9:_.-]*').match(text, pos)
            if not attr or attr.group().lower() in attrs:
                self.fail('invalid or duplicate raw attribute')
            attrs.add(attr.group().lower())
            pos = attr.end()
            after_name = pos
            while pos < len(text) and text[pos] in ws:
                pos += 1
            if pos >= len(text) or text[pos] != '=':
                # HTML boolean attributes have no '='; retain their delimiter.
                if attr.group().lower() not in self.BOOLEAN_ATTRIBUTES:
                    self.fail('missing raw attribute value')
                pos = after_name
                continue
            pos += 1
            while pos < len(text) and text[pos] in ws:
                pos += 1
            if pos >= len(text):
                self.fail('missing raw attribute value')
            if text[pos] in '\"\'':
                quote = text[pos]
                pos += 1
                while pos < len(text) and text[pos] != quote:
                    if text[pos] == '<':
                        self.fail('nested raw tag in attribute')
                    pos += 1
                if pos == len(text):
                    self.fail('unfinished raw attribute quote')
                pos += 1
            else:
                value_start = pos
                while pos < len(text) and text[pos] not in ws + '>':
                    if text.startswith('/>', pos):
                        break
                    if text[pos] in '<\"\'=`':
                        self.fail('illegal raw attribute value')
                    pos += 1
                if pos == value_start:
                    self.fail('missing raw attribute value')
        self.fail('incomplete raw tag')

    def _validate_raw_tokens(self, text):
        """Lex markup, leaving comments and style raw text opaque.

        This pass owns raw-token completeness (including closing tokens). It
        runs before feed, so no tolerant parser event can erase malformed syntax.
        Regexes are anchored token recognizers, not document-wide sanitizers.
        """
        pos = 0
        in_style = False
        while pos < len(text):
            start = text.find('<', pos)
            if start == -1:
                break
            if in_style and not re.compile(r'</style(?=[\s/>]|$)', re.I).match(text, start):
                pos = start + 1
                continue
            if not in_style and text.startswith('<!--', start):
                end = text.find('-->', start + 4)
                if end == -1:
                    self.fail('incomplete raw comment')
                pos = end + 3
                continue
            if not in_style and text[start:start + 9].lower() == '<!doctype':
                # MT5's HTML doctype; quoted PUBLIC/SYSTEM identifiers are opaque.
                declaration = re.compile(
                    r'<!DOCTYPE\s+HTML(?:\s+(?:PUBLIC\s+(?:"[^"]*"|\'[^\']*\')'
                    r'\s+(?:"[^"]*"|\'[^\']*\')|SYSTEM\s+(?:"[^"]*"|\'[^\']*\')))?\s*>', re.I
                ).match(text, start)
                if not declaration:
                    self.fail('invalid raw doctype')
                pos = declaration.end()
                continue
            pos, tag, closing = self._raw_tag(text, start)
            if tag == 'style':
                in_style = not closing
        if in_style:
            self.fail('incomplete style raw text')

    def handle_starttag(self, tag, attrs):
        if tag == 'html':
            self.html_count += 1
            if self.stack or self.html_count != 1:
                self.fail('expected one HTML document')
        elif not self.stack:
            self.fail('markup outside HTML document')
        if tag in self.NON_REPORT_CONTAINERS:
            self.fail('unsupported non-report content container: ' + tag)
        if tag == 'body':
            self.body_count += 1
            if self.stack != ['html'] or self.body_count != 1:
                self.fail('invalid body')
        if tag == 'title':
            self.title_count += 1
            if self.stack != ['html', 'head'] or self.title_count != 1:
                self.fail('invalid title')
        if tag == 'table':
            if ('body' not in self.stack or 'table' in self.stack or
                    self.stack[-1] not in {'body', 'div'}):
                self.fail('invalid/nested report table')
            self.tables.append([])
        if tag == 'tr':
            if not self.stack or self.stack[-1] not in {'table', 'thead', 'tbody', 'tfoot'}:
                self.fail('row outside table')
            self.row = []
        if tag in {'td', 'th'}:
            if not self.stack or self.stack[-1] != 'tr':
                self.fail('cell outside row')
            self.cell = []
        if tag not in self.VOID:
            self.stack.append(tag)

    def handle_startendtag(self, tag, attrs):
        if tag not in self.VOID:
            self.fail('self-closing structural tag')
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if not self.stack or self.stack[-1] != tag:
            self.fail('unbalanced HTML tags: ' + tag)
        if tag in {'td', 'th'}:
            self.row.append(''.join(self.cell).replace('\xa0', ' ').strip())
            self.cell = None
        if tag == 'tr':
            self.tables[-1].append(self.row)
            self.row = None
        self.stack.pop()

    def handle_data(self, data):
        if not self.stack and data.strip():
            self.fail('text outside HTML document')
        if 'style' in self.stack:
            return
        if 'title' in self.stack:
            self.title.append(data)
        if self.cell is not None:
            self.cell.append(data)

    def qualified_fields(self, html):
        self._validate_raw_tokens(html)
        self.feed(html)
        self.close()
        if self.stack or self.rawdata or self.html_count != 1 or self.body_count != 1:
            self.fail('incomplete HTML document')
        title = ''.join(self.title).strip()
        title_match = re.fullmatch(
            r'Strategy Tester Report(?:\s+Build\s+([1-9]\d*))?', title, re.I)
        if not title_match:
            self.fail('missing Strategy Tester Report identity')
        candidates = [rows for rows in self.tables
                      if any('Expert:' in row for row in rows)]
        if len(candidates) != 1:
            self.fail('expected one MT5 settings/results table')
        identity_builds = []
        if title_match.group(1):
            identity_builds.append(int(title_match.group(1)))
        for row in candidates[0]:
            if any(value.endswith(':') for value in row):
                break
            for value in row:
                identity_builds.extend(
                    int(match) for match in
                    re.findall(r'\bBuild\s+([1-9]\d*)\b', value, re.I))
        if not identity_builds:
            self.fail('missing MT5 build identity')
        if len(set(identity_builds)) != 1:
            self.fail('conflicting MT5 build identities')
        self.report_build = identity_builds[0]
        fields = {}
        for row in candidates[0]:
            for i, value in enumerate(row):
                if value.endswith(':'):
                    label = value.lower()
                    if label in fields:
                        self.fail('duplicate report label: ' + value)
                    fields[label] = row[i + 1] if i + 1 < len(row) else ''
        return fields


def _read_report(raw):
    # Do not try UTF-16 first on arbitrary even-length UTF-8 bytes: decoding can
    # succeed as meaningless characters. MT5 commonly writes BOM-less UTF-16LE.
    if raw.startswith((b'\xff\xfe', b'\xfe\xff')):
        encoding = 'utf-16'
    elif raw[:4] in (b'<\x00!\x00', b'<\x00h\x00', b'<\x00H\x00') or b'\x00' in raw[:80]:
        encoding = 'utf-16-le'
    else:
        encoding = 'utf-8-sig'
    try:
        html = raw.decode(encoding)
    except UnicodeError as exc:
        raise ReportQualificationError('MT5_REPORT_INVALID: invalid encoding') from exc
    if any(ord(c) < 32 and c not in '\t\r\n' for c in html):
        raise ReportQualificationError('MT5_REPORT_INVALID: control character')
    return html

def strip_html(t):
    t = re.sub(r"<[^>]+>", "", t)
    return (
        t.replace("&nbsp;", " ")
        .replace("\xa0", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .strip()
    )

def pn(s):
    if s is None:
        return None
    s = str(s).replace("\xa0", " ").strip()
    if not s or not re.fullmatch(NUM_TOKEN, s):
        return None
    normalized = s.replace(",", "").replace(" ", "")
    try:
        value = float(normalized)
        return value if math.isfinite(value) else None
    except ValueError:
        return None

def leading_number(s):
    if not s:
        return None
    m = re.match(rf"\s*({NUM_TOKEN})(?=\s*(?:\(|%|$))", str(s).replace("\xa0", " "))
    return pn(m.group(1)) if m else None

def parse_report(path):
    with open(path, "rb") as f:
        raw = f.read()
    html = _read_report(raw)
    document = _ReportHTML()
    fields = document.qualified_fields(html)
    LOOKUP_NOT_FOUND = 0
    LOOKUP_FOUND_EMPTY = 1
    LOOKUP_FOUND_VALUE = 2

    def _lookup(label):
        if label.lower() not in fields:
            return LOOKUP_NOT_FOUND, ""
        value = fields[label.lower()]
        return (LOOKUP_FOUND_VALUE if value else LOOKUP_FOUND_EMPTY), value

    def fl(label):
        status, value = _lookup(label)
        return value if status == LOOKUP_FOUND_VALUE else ""

    def fl_any(*labels):
        for label in labels:
            status, value = _lookup(label)
            if status == LOOKUP_NOT_FOUND:
                continue
            return value if status == LOOKUP_FOUND_VALUE else ""
        return ""

    def number_pct(value):
        if not value:
            return None
        m = re.fullmatch(
            rf"\s*({NUM_TOKEN})\s*\(\s*({NUM_TOKEN})\s*%\s*\)\s*",
            str(value).replace("\xa0", " "),
        )
        if not m:
            return None
        pair = pn(m.group(1)), pn(m.group(2))
        return pair if all(v is not None for v in pair) else None

    def count_pct(value):
        pair = number_pct(value)
        if pair is None or pair[0] is None:
            return None
        return int(pair[0]), pair[1]

    def refuse(label):
        raise ReportQualificationError("MT5_REPORT_INVALID: missing/invalid " + label)

    def exact_number(value):
        value = value.replace('\xa0', ' ').strip()
        if not re.fullmatch(NUM_TOKEN, value):
            return None
        return Decimal(value.replace(',', '').replace(' ', ''))

    def exact_pair(value):
        match = re.fullmatch(rf'({NUM_TOKEN})\s*\(\s*({NUM_TOKEN})\s*\)', value)
        return tuple(exact_number(part) for part in match.groups()) if match else None

    # Agreement precedes float-based public validation/conversion. Decimal is
    # constructed from the grammar-checked text, never from a rounded float.
    for normalize, labels in (
            (exact_number, ('Average profit trade:', 'Avg profit trade:')),
            (exact_number, ('Average loss trade:', 'Avg loss trade:')),
            (exact_number, ('Average consecutive wins:', 'Avg consecutive wins:')),
            (exact_number, ('Average consecutive losses:', 'Avg consecutive losses:')),
            (exact_pair, ('Maximum consecutive wins ($):', 'Max consecutive wins:')),
            (exact_pair, ('Maximum consecutive losses ($):', 'Max consecutive losses:'))):
        values = []
        for label in labels:
            if _lookup(label)[0] == LOOKUP_NOT_FOUND:
                continue
            value = normalize(fl(label))
            if value is None:
                refuse(label)
            values.append(value)
        if values and any(value != values[0] for value in values[1:]):
            raise ReportQualificationError(
                'MT5_REPORT_INVALID: conflicting metric aliases: ' + ' / '.join(labels))

    # These settings and aggregate results identify the supported single-test
    # MT5 schema. Zero is valid; missing/empty/malformed must never become zero.
    for label in ("Expert:", "Symbol:", "Company:", "Currency:", "Leverage:"):
        if not fl(label) or fl(label).endswith(":"):
            refuse(label)
    period = re.fullmatch(r"(M[1-9]\d*|H[1-9]\d*|D1|W1|MN1) \((\d{4}\.\d{2}\.\d{2}) - (\d{4}\.\d{2}\.\d{2})\)", fl("Period:"))
    if not period:
        refuse("Period:")
    try:
        start, end = (datetime.strptime(d, "%Y.%m.%d") for d in period.groups()[1:])
    except ValueError:
        refuse("Period: calendar date")
    if start >= end:
        refuse("Period: date order")
    required_numbers = ("Initial Deposit:", "Bars:", "Ticks:", "Symbols:",
                        "Total Net Profit:", "Gross Profit:", "Gross Loss:",
                        "Profit Factor:", "Total Trades:", "Total Deals:",
                        "Balance Drawdown Absolute:", "Equity Drawdown Absolute:")
    for label in required_numbers:
        if pn(fl(label)) is None:
            refuse(label)
    for label in ("Bars:", "Ticks:", "Symbols:", "Total Trades:", "Total Deals:"):
        n = pn(fl(label))
        if n < 0 or not n.is_integer():
            refuse(label)
    for label in ("Balance Drawdown Maximal:", "Equity Drawdown Maximal:"):
        if number_pct(fl(label)) is None:
            refuse(label)
    # Present optional numeric cells must also be valid. The output defaults for
    # absent optional labels are kept for qualified older report versions.
    for label in ("Recovery Factor:", "Expected Payoff:", "Sharpe Ratio:",
                  "LR Correlation:", "OnTester result:", "Largest profit trade:",
                  "Largest loss trade:", "Average profit trade:", "Avg profit trade:",
                  "Average loss trade:", "Avg loss trade:", "Average consecutive wins:",
                  "Avg consecutive wins:", "Average consecutive losses:", "Avg consecutive losses:"):
        if _lookup(label)[0] != LOOKUP_NOT_FOUND and pn(fl(label)) is None:
            refuse(label)
    for label in ("Short Trades (won %):", "Long Trades (won %):",
                  "Profit Trades (% of total):", "Loss Trades (% of total):"):
        if _lookup(label)[0] != LOOKUP_NOT_FOUND:
            pair = number_pct(fl(label))
            if pair is None or pair[0] < 0 or not pair[0].is_integer() or not 0 <= pair[1] <= 100:
                refuse(label)
    for label in ("AHPR:", "GHPR:"):
        if _lookup(label)[0] != LOOKUP_NOT_FOUND and number_pct(fl(label)) is None:
            refuse(label)
    for label in ("Balance Drawdown Relative:", "Equity Drawdown Relative:"):
        if _lookup(label)[0] != LOOKUP_NOT_FOUND:
            match = re.fullmatch(rf"({NUM_TOKEN})\s*%(?:\s*\(\s*({NUM_TOKEN})\s*\))?", fl(label))
            if not match or any(pn(v) is None for v in match.groups() if v is not None):
                refuse(label)
    for label in ("Maximum consecutive wins ($):", "Max consecutive wins:",
                  "Maximum consecutive losses ($):", "Max consecutive losses:"):
        if _lookup(label)[0] != LOOKUP_NOT_FOUND:
            match = re.fullmatch(rf"({NUM_TOKEN})\s*\(\s*({NUM_TOKEN})\s*\)", fl(label))
            if not match or any(pn(v) is None for v in match.groups()):
                refuse(label)

    r = {}
    r["ea_name"] = fl("Expert:")
    r["symbol"] = fl("Symbol:")
    r["company"] = fl("Company:")
    r["report_build"] = document.report_build
    r["currency"] = fl("Currency:")

    pr = fl("Period:")
    if pr:
        pts = pr.split("(")
        if len(pts) >= 2:
            dp = pts[-1].rstrip(")").strip()
            ds = dp.split("-")
            r["period"] = pts[0].strip()
            if len(ds) == 2:
                r["from_date"] = ds[0].strip()
                r["to_date"] = ds[1].strip()
        else:
            r["period"] = pr

    r["initial_deposit"] = pn(fl("Initial Deposit:")) or 0
    r["leverage"] = fl("Leverage:")
    r["quality"] = fl("Quality:")
    r["history_quality"] = fl("History Quality:")
    r["bars"] = pn(fl("Bars:")) or 0
    r["ticks"] = pn(fl("Ticks:")) or 0
    symbols = pn(fl("Symbols:"))
    r["symbols_count"] = int(symbols) if symbols is not None else 0

    r["net_profit"] = pn(fl("Total Net Profit:")) or 0
    r["gross_profit"] = pn(fl("Gross Profit:")) or 0
    r["gross_loss"] = pn(fl("Gross Loss:")) or 0
    r["balance_drawdown_abs"] = pn(fl("Balance Drawdown Absolute:")) or 0
    r["equity_drawdown_abs"] = pn(fl("Equity Drawdown Absolute:")) or 0

    bdma = fl("Balance Drawdown Maximal:")
    eqdma = fl("Equity Drawdown Maximal:")
    if bdma:
        pair = number_pct(bdma)
        if pair is not None:
            r["balance_drawdown_maximal_abs"] = pair[0] or 0
            r["balance_drawdown_maximal_pct"] = pair[1] or 0
    if eqdma:
        pair = number_pct(eqdma)
        if pair is not None:
            r["equity_drawdown_maximal_abs"] = pair[0] or 0
            r["equity_drawdown_maximal_pct"] = pair[1] or 0

    bdr = fl("Balance Drawdown Relative:")
    edr = fl("Equity Drawdown Relative:")
    if bdr:
        m = re.match(rf"\s*({NUM_TOKEN})\s*%", bdr.replace("\xa0", " "))
        if m:
            r["balance_drawdown_relative_pct"] = pn(m.group(1)) or 0
    if edr:
        m = re.match(rf"\s*({NUM_TOKEN})\s*%", edr.replace("\xa0", " "))
        if m:
            r["equity_drawdown_relative_pct"] = pn(m.group(1)) or 0

    r["profit_factor"] = pn(fl("Profit Factor:")) or 0
    r["recovery_factor"] = pn(fl("Recovery Factor:")) or 0
    r["expected_payoff"] = pn(fl("Expected Payoff:")) or 0
    r["sharpe_ratio"] = pn(fl("Sharpe Ratio:")) or 0
    r["z_score"] = fl("Z-Score:")
    r["ahpr"] = leading_number(fl("AHPR:")) or 0
    r["ghpr"] = leading_number(fl("GHPR:")) or 0
    r["lr_correlation"] = pn(fl("LR Correlation:")) or 0
    r["ontester_result"] = pn(fl("OnTester result:")) or 0
    r["margin_level"] = fl("Margin Level:")
    r["total_trades"] = pn(fl("Total Trades:")) or 0
    r["total_deals"] = pn(fl("Total Deals:")) or 0

    sr = fl("Short Trades (won %):")
    lr2 = fl("Long Trades (won %):")
    if sr:
        pair = count_pct(sr)
        if pair is not None:
            r["short_trades"] = pair[0]
            r["short_won_pct"] = pair[1] or 0
    if lr2:
        pair = count_pct(lr2)
        if pair is not None:
            r["long_trades"] = pair[0]
            r["long_won_pct"] = pair[1] or 0

    ptr = fl("Profit Trades (% of total):")
    lt2 = fl("Loss Trades (% of total):")
    if ptr:
        pair = count_pct(ptr)
        if pair is not None:
            r["profit_trades"] = pair[0]
            r["profit_trades_pct"] = pair[1] or 0
    if lt2:
        pair = count_pct(lt2)
        if pair is not None:
            r["loss_trades"] = pair[0]
            r["loss_trades_pct"] = pair[1] or 0

    r["largest_profit_trade"] = pn(fl("Largest profit trade:")) or 0
    r["largest_loss_trade"] = pn(fl("Largest loss trade:")) or 0
    r["avg_profit_trade"] = pn(fl_any("Average profit trade:", "Avg profit trade:")) or 0
    r["avg_loss_trade"] = pn(fl_any("Average loss trade:", "Avg loss trade:")) or 0
    r["avg_consecutive_wins"] = pn(fl_any("Average consecutive wins:", "Avg consecutive wins:")) or 0
    r["avg_consecutive_losses"] = pn(fl_any("Average consecutive losses:", "Avg consecutive losses:")) or 0
    r["max_consecutive_wins"] = leading_number(fl_any("Maximum consecutive wins ($):", "Max consecutive wins:")) or 0
    r["max_consecutive_losses"] = leading_number(fl_any("Maximum consecutive losses ($):", "Max consecutive losses:")) or 0
    return r

def main():
    pa = argparse.ArgumentParser()
    pa.add_argument("report")
    pa.add_argument("--json", action="store_true")
    a = pa.parse_args()
    try:
        res = parse_report(a.report)
    except FileNotFoundError:
        print(json.dumps({"error": f"File not found: {a.report}", "status": "NO_REPORT"}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e), "status": "PARSE_ERROR"}))
        sys.exit(1)
    if a.json:
        print(json.dumps(res, indent=2, ensure_ascii=False))
    else:
        for k, v in res.items():
            print(f"  {k}: {v}")

if __name__ == "__main__":
    main()
