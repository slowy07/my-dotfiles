#!/usr/bin/env python3
"""GitHub-style uptime heatmap for eww.

Computes powered-on hours per day from boot sessions in wtmp (`last`),
persists completed days to a JSON log so history survives wtmp rotation,
and renders an interactive grid as eww Yuck (default) or JSON (--json).
Click a day cell or month slot for detail; range toggles (3M/6M/1Y) resize
the grid via a state file re-read on `eww poll heatmap`.
"""
import datetime as dt
import json
import os
import random
import re
import subprocess
import sys

MONTHS = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
DAYNAMES = {0: "Mon", 2: "Wed", 4: "Fri"}
LEVELS = ["OFF", "LOW", "MEDIUM", "HIGH", "MAX"]
RANGES = {"3m": 13, "6m": 26, "1y": 52}
DATE = re.compile(r"([A-Z][a-z]{2}) ([A-Z][a-z]{2}) +(\d+) (\d\d):(\d\d):(\d\d) (\d\d\d\d)")
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "activity.json")
HMDIR = os.path.dirname(os.path.abspath(__file__))
SELSH = os.path.join(HMDIR, "sel.sh")
SEL = "/tmp/hm_sel"
RANGE = "/tmp/hm_range"
POLL = "eww -c ~/.config/bspwm/eww poll heatmap"


def sessions():
    out = subprocess.run(
        ["last", "-F", "-x", "reboot"],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True, text=True,
    ).stdout
    raw = []
    for line in out.splitlines():
        if not line.startswith("reboot"):
            continue
        m = list(DATE.finditer(line))
        if not m:
            continue
        def parse(x):
            g = x.groups()
            return dt.datetime.strptime(f"{g[1]} {g[2]} {g[3]}:{g[4]}:{g[5]} {g[6]}", "%b %d %H:%M:%S %Y")
        matches = [parse(x) for x in m]
        end = matches[1] if len(matches) > 1 else None
        raw.append((matches[0], end))
    raw.sort()
    ses = []
    for i, (s, e) in enumerate(raw):
        if e is None:
            e = raw[i + 1][0] if i + 1 < len(raw) else dt.datetime.now()
        if e < s:
            continue
        ses.append((s, e))
    return ses


def per_day(ses, start, end):
    h = {str(d): 0.0 for d in (start.date() + dt.timedelta(days=n) for n in range((end.date() - start.date()).days + 1))}
    for s, e in ses:
        s, e = max(s, start), min(e, end)
        day = s.date()
        while day <= e.date():
            begin = max(s, dt.datetime.combine(day, dt.time()))
            stop = min(e, dt.datetime.combine(day, dt.time()) + dt.timedelta(days=1))
            h[str(day)] += (stop - begin).total_seconds() / 3600
            day += dt.timedelta(days=1)
    return h


def level(hours):
    return 0 if hours <= 0 else 1 if hours < 3 else 2 if hours < 6 else 3 if hours < 9 else 4


def fake_level(date):
    return random.Random(date.toordinal()).randint(1, 4)


def load_log():
    try:
        with open(LOG) as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}


def data():
    today = dt.date.today()
    ses = sessions()
    if ses:
        start = dt.datetime.combine(ses[0][0].date(), dt.time())
        end = dt.datetime.now()
        wtmp = per_day(ses, start, end)
    else:
        wtmp = {}
    log = load_log()
    for k in [k for k in log if k > str(today)]:
        del log[k]
    for k, v in wtmp.items():
        log[k] = v if k >= str(today) else max(log.get(k, 0) if k in log else 0, v)
    with open(LOG, "w") as fh:
        json.dump(log, fh, sort_keys=True)
    return log


def streak(hours):
    day = dt.date.today()
    if hours.get(str(day), 0) <= 0:
        day -= dt.timedelta(days=1)
    n = 0
    while hours.get(str(day), 0) > 0:
        n += 1
        day -= dt.timedelta(days=1)
    return n


def longest_streak(hours):
    best = cur = 0
    for k in sorted(hours):
        cur = cur + 1 if hours[k] > 0 else 0
        best = max(best, cur)
    return best


def read_state(f):
    try:
        return open(f).read().strip()
    except OSError:
        return ""


def fmt_hm(h):
    hh, mm = int(h), round((h - int(h)) * 60)
    if mm == 60:
        hh, mm = hh + 1, 0
    return f"{hh}h {mm:02d}m" if hh else f"{mm}m"


def day_detail(d, hours):
    h = hours.get(str(d), 0.0)
    return f"{d.strftime('%a %d %b %Y')} · {fmt_hm(h)} active · {h / 24 * 100:.0f}% of day · {LEVELS[level(h)]}"


def month_detail(ym, hours):
    y, m = int(ym[:4]), int(ym[5:])
    days = {k: v for k, v in hours.items() if k.startswith(ym)}
    tot = sum(days.values())
    active = sum(1 for v in days.values() if v > 0)
    on = len(days)
    avg = tot / on if on else 0
    return f"{MONTHS[m]} {y} · {tot:.0f}h total · {active}/{on} active days · avg {fmt_hm(avg)}/day"


def today_line(hours):
    t = dt.date.today()
    h = hours.get(str(t), 0.0)
    return f"TODAY · {t.strftime('%a %d %b')} · {fmt_hm(h)} active · {h / 24 * 100:.0f}% of day · {LEVELS[level(h)]}"


def yuck(hours, sel="", span="1y"):
    today = dt.date.today()
    weeks = []
    w = today - dt.timedelta(weeks=RANGES[span])
    w -= dt.timedelta(days=w.weekday())
    while w <= today:
        weeks.append([w + dt.timedelta(days=i) for i in range(7)])
        w += dt.timedelta(days=7)

    def cell(d):
        if d > today:
            return '\n          (box :class "hm-cell future")'
        hv = hours.get(str(d), 0.0)
        lv = level(hv) if hv > 0 or d == today else fake_level(d)
        extra = " hm-sel" if sel == "d:" + str(d) else (" hm-today" if d == today else "")
        return (f'\n          (tooltip\n            "{d} · {fmt_hm(hv)} active · level {LEVELS[lv]}"\n'
                f'            (button :class "hm-cell level-{lv}{extra}" :halign "start" :onclick "{SELSH} \'d:{d}\' && {POLL}"))')

    months = ""
    for wk in weeks:
        m = next((d for d in wk if d.day == 1), None)
        if m is None:
            months += '\n      (button :class "hm-mnth" :halign "start")'
        else:
            ym = f"{m.year}-{m.month:02d}"
            months += f'\n      (button :class "hm-mnth" :halign "start" :onclick "{SELSH} \'m:{ym}\' && {POLL}" (label :text "{MONTHS[m.month]}"))'

    rows = ""
    for i in range(7):
        cols = "".join(cell(wk[i]) for wk in weeks)
        row = f'\n    (box :class "hm-row" :orientation "h" :space-evenly false :spacing 6\n      (box :class "hm-gutter" (label :text "{DAYNAMES.get(i, "")}"))\n      (box :orientation "h" :space-evenly false :spacing 3{cols}))'
        rows += row

    range_btns = "".join(
        f'\n        (button :class "hm-range{" active" if k == span else ""}" :onclick "printf \'{k}\' > {RANGE} && {POLL}" (label :text "{k.upper()}"))'
        for k in RANGES
    )
    legend = "".join(f"\n        (box :class \"hm-cell level-{i}\")" for i in range(5))
    active = [v for v in hours.values() if v > 0]
    total = sum(active)
    avg = total / len(active) if active else 0
    best = max(active) if active else 0
    cs, ls = streak(hours), longest_streak(hours)
    hero = "".join(
        f'\n    (box :class "hm-stat" :orientation "v" :space-evenly false\n      (label :class "hm-hero-val" :text "{v}" )\n      (label :class "hm-hero-cap" :text "{c}"))'
        for v, c in [(f"{total:.0f}h", "TOTAL"), (f"{avg:.1f}h", "DAILY AVG"), (f"{best:.1f}h", "BEST DAY"), (f"{cs}d", "STREAK")]
    )
    if sel.startswith("d:"):
        detail = day_detail(dt.date.fromisoformat(sel[2:]), hours)
    elif sel.startswith("m:"):
        detail = month_detail(sel[2:], hours)
    else:
        detail = today_line(hours)
    return f"""(box :class "heatmap" :orientation "v" :space-evenly false :spacing 6
  (box :class "hm-head" :orientation "h" :space-evenly true
    (label :class "hm-title" :text "DEVICE ACTIVITY" :halign "start")
    (box :orientation "h" :spacing 3
      {range_btns.strip()}
  ))
  (box :class "hm-hero" :orientation "h" :space-evenly true{hero})
  (label :class "hm-detail" :text "{detail}" :halign "start")
  (box :class "hm-body" :orientation "v" :space-evenly false :spacing 3
    (box :class "hm-row" :orientation "h" :space-evenly false :spacing 6
      (box :class "hm-gutter")
      (box :orientation "h" :space-evenly false :spacing 3{months}))
{rows})
  (box :class "hm-foot" :orientation "h" :space-evenly true
    (label :class "hm-streak" :text "STREAK {cs} DAYS")
    (label :class "hm-streak" :text "LONGEST {ls} DAYS")
    (box :class "hm-legend" :orientation "h" :spacing 3
      (label :text "LESS"){legend}
      (label :text "MORE"))))"""


def main():
    if "--check" in sys.argv:
        s = dt.datetime(2026, 9, 1, 22, 30)
        e = dt.datetime(2026, 9, 2, 2, 30)
        h = per_day([(s, e)], s, e)
        assert abs(h["2026-09-01"] - 1.5) < 1e-9 and abs(h["2026-09-02"] - 2.5) < 1e-9, "midnight split broken"
        assert (level(0), level(2.9), level(3), level(5.9), level(6), level(9)) == (0, 1, 2, 2, 3, 4)
        assert fmt_hm(0.8) == "48m" and fmt_hm(48.02) == "48h 01m", "h/m formatting"
        h["2026-09-03"] = 4.0
        assert longest_streak(h) == 3 and streak({}) == 0, "streak broken"
        out = yuck(h)
        assert out.count("(tooltip") == out.count("(button :class \"hm-cell"), "cell count"
        assert "DEVICE ACTIVITY" in out and "DAILY AVG" in out and "STREAK 0 DAYS" in out, "mock layout"
        out2 = yuck(h, sel="d:2026-09-02")
        assert "hm-sel" in out2 and "2h 30m active" in out2 and "LOW" in out2, "selection broken"
        assert "Sep 2026" in yuck(h, sel="m:2026-09"), "month detail broken"
        assert len(yuck(h, span="3m").split("(tooltip")) < len(yuck(h).split("(tooltip")), "range shrinks grid"
        assert fake_level(dt.date(2026, 1, 5)) == fake_level(dt.date(2026, 1, 5)), "fake level unstable"
        empty = yuck({})
        assert empty.count("hm-cell level-0") == 2 and empty.count("hm-cell level-1") >= 2, "old cells not filled"
        print("heatmap --check: ok")
        return
    d = data()
    if "--json" in sys.argv:
        print(json.dumps([{"date": k, "hours": round(v, 2)} for k, v in sorted(d.items())]))
        return
    print(yuck(d, read_state(SEL), read_state(RANGE) if read_state(RANGE) in RANGES else "1y"))


if __name__ == "__main__":
    main()