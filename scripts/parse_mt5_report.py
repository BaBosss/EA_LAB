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


# HTML/XML API used by the batch pipeline. Ported from the existing
# backtest-report-analyzer parser; legacy parse_report remains compatible.
import html as html_mod
import math
import xml.etree.ElementTree as ET
from pathlib import Path

def read_text_auto(path: Path) -> str:
    raw = path.read_bytes()
    if raw[:2] in (bytes([255, 254]), bytes([254, 255])):  # UTF-16 BOM
        return raw.decode("utf-16")
    for enc in ("utf-8-sig", "cp1252", "utf-16-le"):
        try:
            text = raw.decode(enc)
            if text.count("\x00") < max(1, len(text) // 100):
                return text
        except (UnicodeDecodeError, UnicodeError):
            continue
    return raw.decode("utf-8", errors="replace")


def to_number(s):
    if s is None:
        return None
    s = str(s).strip().replace("\xa0", " ")
    # MT5 uses space as thousands separator: "1 234.56"; also handle "12.34%"
    s = s.replace(" ", "").replace("%", "")
    s = s.replace(",", "")  # some locales
    m = re.match(r"^-?\d+(\.\d+)?$", s)
    if not m:
        return None
    f = float(s)
    return int(f) if f.is_integer() and "." not in s else f


HTML_FIELDS = {
    "profit factor": "profit_factor",
    "expected payoff": "expected_payoff",
    "total net profit": "net_profit",
    "gross profit": "gross_profit",
    "gross loss": "gross_loss",
    "sharpe ratio": "sharpe_ratio",
    "recovery factor": "recovery_factor",
    "balance drawdown maximal": "balance_drawdown_maximal",
    "balance drawdown relative": "balance_drawdown_relative",
    "equity drawdown maximal": "equity_drawdown_maximal",
    "equity drawdown relative": "equity_drawdown_relative",
    "total trades": "total_trades",
    "total deals": "total_deals",
    "profit trades": "profit_trades",
    "loss trades": "loss_trades",
    "largest profit trade": "largest_profit_trade",
    "largest loss trade": "largest_loss_trade",
    "average profit trade": "average_profit_trade",
    "average loss trade": "average_loss_trade",
    "initial deposit": "initial_deposit",
    "history quality": "history_quality",
    "bars": "bars",
    "ticks": "ticks",
    "symbol": "symbol",
    "period": "period",
    "expert": "ea_name",
    "broker": "broker",
    "currency": "currency",
    "leverage": "leverage",
}


CONSEC_FIELDS = {
    "maximum consecutive wins": "max_consecutive_wins",
    "maximum consecutive losses": "max_consecutive_losses",
    "maximal consecutive profit": "max_consecutive_profit",
    "maximal consecutive loss": "max_consecutive_loss",
}


class UnsupportedReport(ValueError):
    """An unrelated document, rather than a malformed tester report."""


def parse_html_report(path: Path) -> dict:
    text = read_text_auto(path)
    # strip tags but keep cell boundaries
    text = re.sub(r"<(td|th)[^>]*>", "\n|CELL|", text, flags=re.I)
    text = re.sub(r"<tr[^>]*>", "\n|ROW|", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = html_mod.unescape(text)

    rows = []
    for row_chunk in text.split("|ROW|"):
        cells = [c.strip() for c in row_chunk.split("|CELL|")]
        cells = [c for c in cells if c]
        if cells:
            rows.append(cells)

    out = {"report_type": "single_backtest", "source_file": str(path)}
    fields = {**HTML_FIELDS, **CONSEC_FIELDS}
    for cells in rows:
        for i, cell in enumerate(cells):
            key = cell.rstrip(":").strip().lower()
            if key in fields and i + 1 < len(cells):
                canon = fields[key]
                value = cells[i + 1]
                if canon in ("symbol", "period", "ea_name", "broker", "currency"):
                    if canon not in out:  # first-wins: settings block precedes deal/order tables
                        out[canon] = value
                    continue
                # split off the "(xx.xx%)" companion ONLY; to_number handles the
                # space/comma thousands separators ("7 497.37" must stay 7497.37)
                num = to_number(value.split("(")[0])
                out[canon] = num if num is not None else value
                # capture "(xx.xx%)" companions
                pct = re.search(r"\(([-\d.,\s]+)%\)", value)
                if pct:
                    out[canon + "_percent"] = to_number(pct.group(1))

    # win rate
    pt, tt = out.get("profit_trades"), out.get("total_trades")
    if isinstance(out.get("profit_trades_percent"), (int, float)):
        out["win_rate_percent"] = out["profit_trades_percent"]
    elif isinstance(pt, (int, float)) and isinstance(tt, (int, float)) and tt:
        out["win_rate_percent"] = round(100.0 * pt / tt, 2)
    report_metrics = ("profit_factor", "total_trades", "net_profit", "recovery_factor")
    if not any(key in out for key in report_metrics) and "strategy tester" not in text.lower():
        raise UnsupportedReport("Not a recognized MT5 tester report")
    _require_metrics(out, report_metrics)
    drawdown_keys = ("equity_drawdown_maximal_percent", "balance_drawdown_maximal_percent")
    present_drawdowns = [key for key in drawdown_keys if key in out]
    if not present_drawdowns:
        raise ValueError("Missing numeric maximal drawdown percentage")
    _require_metrics(out, present_drawdowns)
    return out


def _local(tag):
    return tag.rsplit("}", 1)[-1]


def parse_optimizer_xml(path: Path, top: int = 0) -> dict:
    root = ET.fromstring(path.read_bytes())  # expat honors the declared encoding

    rows = []
    for row in root.iter():
        if _local(row.tag) != "Row":
            continue
        cells = []
        for cell in row:
            if _local(cell.tag) != "Cell":
                continue
            # SpreadsheetML omits empty cells and supplies an explicit 1-based index.
            index = cell.attrib.get("{urn:schemas-microsoft-com:office:spreadsheet}Index")
            if index is not None:
                position = int(index) - 1
                if position < len(cells):
                    raise ValueError("Non-monotonic optimizer cell index")
                cells.extend([None] * (position - len(cells)))
            data = None
            for d in cell:
                if _local(d.tag) == "Data":
                    data = d.text
            cells.append(data)
        if cells:
            rows.append(cells)

    if not rows:
        raise ValueError("No rows found â€” is this an MT5 optimizer XML export?")
    return _optimizer_records(rows, path, top)


def _optimizer_records(rows, path: Path, top: int = 0) -> dict:
    header = [str(h).strip() if h else f"col{i}" for i, h in enumerate(rows[0])]
    passes = []
    for cells in rows[1:]:
        rec = {}
        for h, v in zip(header, cells):
            num = to_number(v)
            rec[h] = num if num is not None else v
        passes.append(rec)

    # canonical aliases (MT5 EN headers)
    alias = {
        "Pass": "pass_id", "Result": "result", "Profit": "net_profit",
        "Expected Payoff": "expected_payoff", "Profit Factor": "profit_factor",
        "Recovery Factor": "recovery_factor", "Sharpe Ratio": "sharpe_ratio",
        "Custom": "custom", "Equity DD %": "max_drawdown_percent",
        "Trades": "total_trades",
    }
    param_cols = [h for h in header if h not in alias]
    for rec in passes:
        for src, dst in alias.items():
            if src in rec:
                rec[dst] = rec[src]

    def sort_key(r):
        v = r.get("net_profit")
        return v if isinstance(v, (int, float)) else float("-inf")

    if not passes:
        raise ValueError("Optimizer report contains no passes")
    seen_pass_ids = set()
    for rec in passes:
        _require_metrics(rec, ("profit_factor", "max_drawdown_percent", "recovery_factor", "total_trades", "net_profit"))
        if "pass_id" in rec:
            pid = rec["pass_id"]
            if not isinstance(pid, int) or isinstance(pid, bool):
                raise ValueError(f"Invalid non-integer pass_id: {pid!r}")
            if pid in seen_pass_ids:
                raise ValueError(f"Duplicate pass_id in optimizer report: {pid}")
            seen_pass_ids.add(pid)
    passes.sort(key=sort_key, reverse=True)
    out = {
        "report_type": "optimizer",
        "source_file": str(path),
        "total_passes": len(passes),
        "columns": header,
        "parameter_columns": param_cols,
        "passes": passes[:top] if top else passes,
    }
    return out


def verify_optimizer_passes(report_or_passes, expected_count=None, expected_sweep=None) -> dict:
    """Verify optimizer pass count, unique pass_ids, finite numeric metrics (0/0.0 preserved),
    and exact swept parameter values independent of sort order (ORDER-1709 / E-3)."""
    if isinstance(report_or_passes, dict):
        passes = list(report_or_passes.get("passes", []))
        total_passes = report_or_passes.get("total_passes", len(passes))
    else:
        passes = list(report_or_passes)
        total_passes = len(passes)

    if not passes:
        raise ValueError("Optimizer report contains no passes")
    if expected_count is not None:
        if isinstance(expected_count, bool) or not isinstance(expected_count, int) or expected_count < 1:
            raise ValueError(f"Invalid expected_count (must be a positive integer): {expected_count!r}")
    # R3-4: validate expected sweep expectations BEFORE any comparison.
    canon_sweep = None
    if expected_sweep is not None:
        if not isinstance(expected_sweep, dict) or not expected_sweep:
            raise ValueError("expected_sweep must be a non-empty mapping of parameter name to values")
        canon_sweep = {}
        for pname, vals in expected_sweep.items():
            if not isinstance(pname, str) or not pname.strip():
                raise ValueError(f"Invalid expected sweep parameter name: {pname!r}")
            if isinstance(vals, (str, bytes)) or not hasattr(vals, "__iter__"):
                raise ValueError(f"Expected sweep values for '{pname}' must be a list of numbers")
            vals = list(vals)
            if not vals:
                raise ValueError(f"Expected sweep values for '{pname}' are empty")
            clean = []
            for v in vals:
                if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v):
                    raise ValueError(f"Expected sweep value for '{pname}' is not a finite number: {v!r}")
                clean.append(float(v))
            if len(set(clean)) != len(clean):
                raise ValueError(f"Expected sweep values for '{pname}' contain duplicates: {vals!r}")
            canon_sweep[pname.strip()] = clean
        expected_sweep = canon_sweep
    if expected_count is not None and (len(passes) != expected_count or total_passes != expected_count):
        raise ValueError(f"Expected {expected_count} optimizer passes, got total_passes={total_passes}, len(passes)={len(passes)}")

    required_metrics = ("profit_factor", "max_drawdown_percent", "recovery_factor", "total_trades", "net_profit")
    optional_metrics = ("expected_payoff", "sharpe_ratio", "result", "custom")
    seen_ids = set()
    for rec in passes:
        if "pass_id" not in rec:
            raise ValueError("Missing pass_id in optimizer pass record")
        pid = rec["pass_id"]
        if not isinstance(pid, int) or isinstance(pid, bool):
            raise ValueError(f"Invalid pass_id: {pid!r}")
        if pid in seen_ids:
            raise ValueError(f"Duplicate pass_id: {pid}")
        seen_ids.add(pid)
        _require_metrics(rec, required_metrics)
        for opt_key in optional_metrics:
            if opt_key in rec and rec[opt_key] is not None:
                _require_metrics(rec, (opt_key,))

    sweep_verified = {}
    if expected_sweep:
        for param_name, expected_vals in expected_sweep.items():
            norm_expected = sorted(float(v) for v in expected_vals)
            actual_vals = []
            for rec in passes:
                if param_name not in rec:
                    raise ValueError(f"Missing swept parameter column '{param_name}' in pass {rec.get('pass_id')}")
                val = rec[param_name]
                if not isinstance(val, (int, float)) or isinstance(val, bool) or not math.isfinite(val):
                    raise ValueError(f"Invalid non-numeric swept value for '{param_name}': {val!r}")
                actual_vals.append(float(val))
            norm_actual = sorted(actual_vals)
            if len(norm_actual) != len(norm_expected) or any(abs(a - b) > 1e-9 for a, b in zip(norm_actual, norm_expected)):
                raise ValueError(
                    f"Swept parameter '{param_name}' values mismatch: expected {norm_expected}, got {norm_actual}"
                )
            sweep_verified[param_name] = [rec[param_name] for rec in sorted(passes, key=lambda r: r["pass_id"])]

    return {
        "verified": True,
        "pass_count": len(passes),
        "pass_ids": sorted(seen_ids),
        "sweep_verified": sweep_verified,
    }


def _require_metrics(record, keys):
    for key in keys:
        value = record.get(key)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value):
            raise ValueError(f"Missing or invalid numeric metric: {key}")


def _parse_sweep_spec(spec_list):
    if not spec_list:
        return None
    out = {}
    for item in spec_list:
        if "=" not in item:
            raise ValueError(f"Invalid --expect-sweep spec {item!r}; expected PARAM=v1,v2,...")
        k, raw_vals = item.split("=", 1)
        vals = [to_number(v.strip()) for v in raw_vals.split(",") if v.strip()]
        if not vals or any(v is None or not math.isfinite(v) for v in vals):
            raise ValueError(f"Invalid numeric sweep values in {item!r}")
        out[k.strip()] = vals
    return out


def main():
    pa = argparse.ArgumentParser()
    pa.add_argument("report")
    pa.add_argument("--json", action="store_true")
    pa.add_argument("--top",type=int,default=0)
    pa.add_argument("--expect-passes",type=int,default=None)
    pa.add_argument("--expect-sweep",action="append",default=None)
    a = pa.parse_args()
    try:
        report_path = Path(a.report)
        if not report_path.exists():
            raise FileNotFoundError(a.report)
        if report_path.suffix.lower() == ".xml":
            res = parse_optimizer_xml(report_path, top=a.top)
            if a.expect_passes is not None or a.expect_sweep:
                res["verification"] = verify_optimizer_passes(
                    res,
                    expected_count=a.expect_passes,
                    expected_sweep=_parse_sweep_spec(a.expect_sweep),
                )
        else:
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
