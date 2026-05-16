#!/opt/homebrew/bin/python3
# <xbar.title>AI Token Usage</xbar.title>
# <xbar.version>2.12.0</xbar.version>
# <xbar.desc>Shows daily token usage from Qwen Code, Codex, OpenCode, and Claude Code</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>

import json
import io
import os
import sqlite3
import subprocess
import sys
import time
from contextlib import redirect_stdout
from datetime import datetime, timedelta
from pathlib import Path

VERSION = "2.12.0"
REPO = "foxleoly/xbar-ai-usage"
PLUGIN_PATH = os.path.abspath(__file__)
CACHE_TTL_SECONDS = int(os.environ.get("XBAR_AI_USAGE_CACHE_TTL", "300"))
CACHE_PATH = Path.home() / ".cache/xbar-ai-usage/output.txt"

EMPTY_STATS = {
    'today': {'t':0,'i':0,'o':0,'c':0,'r':0},
    'd7': {'t':0,'i':0,'o':0,'c':0,'r':0},
    'd30': {'t':0,'i':0,'o':0,'c':0,'r':0},
    'month': {'t':0,'i':0,'o':0,'c':0,'r':0},
}

def format_count(n):
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000: return f"{n/1_000:.1f}K"
    return str(n)

def new_stats():
    return json.loads(json.dumps(EMPTY_STATS))

def add_usage(bucket, total=0, input_tokens=0, output_tokens=0, cache_tokens=0, reasoning_tokens=0):
    bucket['t'] += int(total or 0)
    bucket['i'] += int(input_tokens or 0)
    bucket['o'] += int(output_tokens or 0)
    bucket['c'] += int(cache_tokens or 0)
    bucket['r'] += int(reasoning_tokens or 0)

def get_latest_version():
    """Get latest version from GitHub"""
    if os.environ.get("XBAR_AI_USAGE_CHECK_UPDATE") != "1":
        return None
    try:
        import urllib.request
        url = f"https://raw.githubusercontent.com/{REPO}/master/opencode-usage.1m.py"
        with urllib.request.urlopen(url, timeout=5) as response:
            content = response.read().decode('utf-8')
            for line in content.split('\n'):
                if line.startswith('# <xbar.version>'):
                    return line.split('>')[1].split('<')[0]
    except:
        pass
    return None

def update_plugin():
    """Download and install latest version"""
    try:
        import urllib.request
        url = f"https://raw.githubusercontent.com/{REPO}/master/opencode-usage.1m.py"
        with urllib.request.urlopen(url, timeout=10) as response:
            content = response.read().decode('utf-8')
        with open(PLUGIN_PATH, 'w') as f:
            f.write(content)
        os.chmod(PLUGIN_PATH, 0o755)
        return True
    except Exception as e:
        return False

def get_model_info():
    """Get current model name from settings.json"""
    settings_path = Path.home() / ".qwen" / "settings.json"
    if not settings_path.exists():
        return None
    try:
        with open(settings_path) as f:
            settings = json.load(f)
        model_id = settings.get("model", {}).get("name")
        if not model_id:
            return None
        providers = settings.get("modelProviders", {})
        for provider, models in providers.items():
            for m in models:
                if m.get("id") == model_id:
                    return m.get("name", model_id)
        return model_id
    except:
        return None

def get_oc_stats():
    db_paths = [
        Path.home() / ".local/share/opencode/opencode.db",
        Path.home() / ".local/share/opencode-alt/opencode/opencode.db",
    ]
    stats = new_stats()
    found = False
    for db in db_paths:
        if not db.exists():
            continue
        try:
            conn = sqlite3.connect(str(db))
            c = conn.cursor()
            for key, condition in [
                ('today', "date(time_created/1000,'unixepoch','localtime')=date('now','localtime')"),
                ('d7', "date(time_created/1000,'unixepoch','localtime')>=date('now','localtime','-6 days')"),
                ('d30', "date(time_created/1000,'unixepoch','localtime')>=date('now','localtime','-29 days')"),
                ('month', "strftime('%Y-%m',time_created/1000,'unixepoch','localtime')=strftime('%Y-%m','now','localtime')"),
            ]:
                c.execute(f"""SELECT 
                    SUM(json_extract(data,'$.tokens.total')),
                    SUM(json_extract(data,'$.tokens.input')),
                    SUM(json_extract(data,'$.tokens.output')),
                    SUM(json_extract(data,'$.tokens.cache.read') + json_extract(data,'$.tokens.cache.write')),
                    SUM(json_extract(data,'$.tokens.reasoning'))
                    FROM message
                    WHERE json_extract(data,'$.role')='assistant' AND {condition}""")
                row = c.fetchone()
                add_usage(stats[key], row[0], row[1], row[2], row[3], row[4])
            conn.close()
            found = True
        except:
            continue
    if not found:
        return stats
    return stats

def get_qwen_stats():
    qwen_path = Path.home() / ".qwen/projects"
    if not qwen_path.exists(): return {}
    stats = {
        'today': {'t':0,'i':0,'o':0,'c':0,'th':0},
        'd7': {'t':0,'i':0,'o':0,'c':0,'th':0},
        'd30': {'t':0,'i':0,'o':0,'c':0,'th':0},
        'month': {'t':0,'i':0,'o':0,'c':0,'th':0},
    }
    now = datetime.now().date()
    cutoff7 = now - timedelta(days=6)
    cutoff30 = now - timedelta(days=29)
    latest_model = None
    latest_ts = None
    for f in qwen_path.glob("*/chats/*.jsonl"):
        try:
            for line in open(f):
                if '"ui_telemetry"' not in line: continue
                d = json.loads(line)
                if d.get("subtype") != "ui_telemetry": continue
                ui = d.get("systemPayload",{}).get("uiEvent",{})
                ts = d.get("timestamp","")
                if not ts: continue
                rd = datetime.fromisoformat(ts.replace("Z","+00:00")).date()
                t = ui.get("total_token_count",0)
                i = ui.get("input_token_count",0)
                o = ui.get("output_token_count",0)
                c = ui.get("cached_content_token_count",0)
                th = ui.get("thoughts_token_count",0)
                # Track latest model
                model = ui.get("model")
                if model and ts:
                    if latest_ts is None or ts > latest_ts:
                        latest_ts = ts
                        latest_model = model
                if rd == now:
                    stats['today']['t'] += t
                    stats['today']['i'] += i
                    stats['today']['o'] += o
                    stats['today']['c'] += c
                    stats['today']['th'] += th
                if rd >= cutoff7:
                    stats['d7']['t'] += t
                    stats['d7']['i'] += i
                    stats['d7']['o'] += o
                    stats['d7']['c'] += c
                    stats['d7']['th'] += th
                if rd >= cutoff30:
                    stats['d30']['t'] += t
                    stats['d30']['i'] += i
                    stats['d30']['o'] += o
                    stats['d30']['c'] += c
                    stats['d30']['th'] += th
                if rd.year == now.year and rd.month == now.month:
                    stats['month']['t'] += t
                    stats['month']['i'] += i
                    stats['month']['o'] += o
                    stats['month']['c'] += c
                    stats['month']['th'] += th
        except: pass
    stats['model'] = latest_model
    return stats

def get_claude_stats():
    """Get Claude Code token usage from ~/.claude/projects/*/*.jsonl"""
    claude_path = Path.home() / ".claude/projects"
    if not claude_path.exists(): return {}
    stats = new_stats()
    now = datetime.now().date()
    cutoff7 = now - timedelta(days=6)
    cutoff30 = now - timedelta(days=29)
    for f in claude_path.glob("*/*.jsonl"):
        try:
            for line in open(f):
                try:
                    d = json.loads(line)
                    if d.get("type") != "assistant": continue
                    ts = d.get("timestamp", "")
                    if not ts: continue
                    rd = datetime.fromisoformat(ts.replace("Z", "+00:00")).date()
                    usage = d.get("message", {}).get("usage", {})
                    i = usage.get("input_tokens", 0)
                    o = usage.get("output_tokens", 0)
                    c = usage.get("cache_read_input_tokens", 0) + usage.get("cache_creation_input_tokens", 0)
                    t = i + o + c
                    if rd == now:
                        add_usage(stats['today'], t, i, o, c, 0)
                    if rd >= cutoff7:
                        add_usage(stats['d7'], t, i, o, c, 0)
                    if rd >= cutoff30:
                        add_usage(stats['d30'], t, i, o, c, 0)
                    if rd.year == now.year and rd.month == now.month:
                        add_usage(stats['month'], t, i, o, c, 0)
                except: pass
        except: pass
    return stats

def get_codex_stats():
    """Get Codex token usage from ~/.codex session rollout token_count events."""
    state_db = Path.home() / ".codex/state_5.sqlite"
    if not state_db.exists():
        return {}
    stats = new_stats()
    try:
        conn = sqlite3.connect(str(state_db))
        c = conn.cursor()
        c.execute("""SELECT rollout_path, updated_at
            FROM threads
            WHERE date(updated_at,'unixepoch','localtime') >= date('now','localtime','-29 days')
               OR strftime('%Y-%m',updated_at,'unixepoch','localtime')=strftime('%Y-%m','now','localtime')""")
        rollout_rows = [(Path(row[0]), datetime.fromtimestamp(row[1]).date()) for row in c.fetchall() if row and row[0]]
        conn.close()
    except:
        return {}

    now = datetime.now().date()
    cutoff7 = now - timedelta(days=6)
    cutoff30 = now - timedelta(days=29)
    for rollout, updated_date in rollout_rows:
        if not rollout.exists():
            continue
        last_usage = None
        try:
            with open(rollout, errors="replace") as f:
                for line in f:
                    if "token_count" not in line:
                        continue
                    try:
                        d = json.loads(line)
                    except:
                        continue
                    if d.get("type") != "event_msg":
                        continue
                    payload = d.get("payload", {})
                    if payload.get("type") != "token_count":
                        continue
                    info = payload.get("info") or {}
                    usage = info.get("total_token_usage", {})
                    if not usage:
                        continue
                    last_usage = usage
        except:
            continue
        if not last_usage:
            continue
        total = last_usage.get("total_tokens", 0)
        i = last_usage.get("input_tokens", 0)
        o = last_usage.get("output_tokens", 0)
        c = last_usage.get("cached_input_tokens", 0)
        r = last_usage.get("reasoning_output_tokens", 0)
        if updated_date == now:
            add_usage(stats['today'], total, i, o, c, r)
        if updated_date >= cutoff7:
            add_usage(stats['d7'], total, i, o, c, r)
        if updated_date >= cutoff30:
            add_usage(stats['d30'], total, i, o, c, r)
        if updated_date.year == now.year and updated_date.month == now.month:
            add_usage(stats['month'], total, i, o, c, r)
    return stats

def main():
    oc = get_oc_stats()
    qw = get_qwen_stats()
    cx = get_codex_stats()
    cc = get_claude_stats()
    qw_t = qw.get('today',{}).get('t',0)
    cx_t = cx.get('today',{}).get('t',0)
    cc_t = cc.get('today',{}).get('t',0)
    oc_t = oc.get('today',{}).get('t',0)
    qw_m = qw.get('month',{}).get('t',0)
    cx_m = cx.get('month',{}).get('t',0)
    cc_m = cc.get('month',{}).get('t',0)
    oc_m = oc.get('month',{}).get('t',0)
    # Get model from chat logs first, fallback to settings.json
    qw_model = qw.get('model') or get_model_info()

    # Check for updates
    latest_version = get_latest_version()
    has_update = latest_version and latest_version != VERSION

    # Title - show all tools with data
    title_parts = []
    month_total = qw_m + cx_m + cc_m + oc_m
    if month_total > 0:
        title_parts.append(f"AI Mo {format_count(month_total)}")
    elif qw_t > 0:
        title_parts.append(f"QC {format_count(qw_t)}")
    if month_total == 0 and cx_t > 0:
        title_parts.append(f"Codex {format_count(cx_t)}")
    if month_total == 0 and cc_t > 0:
        title_parts.append(f"CC {format_count(cc_t)}")
    if month_total == 0 and oc_t > 0:
        title_parts.append(f"OC {format_count(oc_t)}")
    if title_parts:
        print(" / ".join(title_parts))
    else:
        print("No data")

    # Update notification
    if has_update:
        print(f"⬆️ v{VERSION} → v{latest_version} | color=orange")
    print("---")

    # Update menu item
    if has_update:
        print(f"🔄 Update to v{latest_version} | href=https://github.com/{REPO}")
        print("---")

    # Qwen Code section (first)
    if qw_t > 0 or qw_m > 0:
        print("Qwen Code | color=#7986cb font=Menlo size=13")
        print(f"--Total: {format_count(qw['today']['t'])} | color=#00bcd4")
        print(f"--Input: {format_count(qw['today']['i'])} | color=#81d4fa")
        print(f"--Output: {format_count(qw['today']['o'])} | color=#a5d6a7")
        print(f"--Cache: {format_count(qw['today']['c'])} | color=#ffcc80")
        print(f"--Thoughts: {format_count(qw['today']['th'])} | color=#f48fb1")
        print(f"--7-Day: {format_count(qw['d7']['t'])} | color=#ce93d8")
        print(f"--30-Day: {format_count(qw['d30']['t'])} | color=#90a4ae")
        print(f"--Month: {format_count(qw['month']['t'])} | color=#90a4ae")
        print(f"--Model: {qw_model or 'N/A'} | color=#b0bec5 size=11")

    # Codex section (second)
    if cx_t > 0 or cx_m > 0:
        if qw_t > 0 or qw_m > 0:
            print("---")
        print("Codex | color=#4fc3f7 font=Menlo size=13")
        print(f"--Total: {format_count(cx['today']['t'])} | color=#00bcd4")
        print(f"--Input: {format_count(cx['today']['i'])} | color=#81d4fa")
        print(f"--Output: {format_count(cx['today']['o'])} | color=#a5d6a7")
        print(f"--Cache: {format_count(cx['today']['c'])} | color=#ffcc80")
        print(f"--Reasoning: {format_count(cx['today']['r'])} | color=#f48fb1")
        print(f"--7-Day: {format_count(cx['d7']['t'])} | color=#ce93d8")
        print(f"--30-Day: {format_count(cx['d30']['t'])} | color=#90a4ae")
        print(f"--Month: {format_count(cx['month']['t'])} | color=#90a4ae")

    # Claude Code section (second)
    if cc_t > 0 or cc_m > 0:
        if qw_t > 0 or qw_m > 0 or cx_t > 0 or cx_m > 0:
            print("---")
        print("Claude Code | color=#d4a574 font=Menlo size=13")
        print(f"--Total: {format_count(cc['today']['t'])} | color=#00bcd4")
        print(f"--Input: {format_count(cc['today']['i'])} | color=#81d4fa")
        print(f"--Output: {format_count(cc['today']['o'])} | color=#a5d6a7")
        print(f"--Cache: {format_count(cc['today']['c'])} | color=#ffcc80")
        print(f"--Reasoning: {format_count(cc['today']['r'])} | color=#f48fb1")
        print(f"--7-Day: {format_count(cc['d7']['t'])} | color=#ce93d8")
        print(f"--30-Day: {format_count(cc['d30']['t'])} | color=#90a4ae")
        print(f"--Month: {format_count(cc['month']['t'])} | color=#90a4ae")

    # OpenCode section
    if oc_t > 0 or oc_m > 0:
        if qw_t > 0 or qw_m > 0 or cx_t > 0 or cx_m > 0 or cc_t > 0 or cc_m > 0:
            print("---")
        print("OpenCode | color=#66bb6a font=Menlo size=13")
        print(f"--Total: {format_count(oc_t)} | color=#00bcd4")
        print(f"--Input: {format_count(oc['today']['i'])} | color=#81d4fa")
        print(f"--Output: {format_count(oc['today']['o'])} | color=#a5d6a7")
        print(f"--Cache: {format_count(oc['today']['c'])} | color=#ffcc80")
        print(f"--Reasoning: {format_count(oc['today']['r'])} | color=#f48fb1")
        print(f"--7-Day: {format_count(oc['d7']['t'])} | color=#ce93d8")
        print(f"--30-Day: {format_count(oc['d30']['t'])} | color=#90a4ae")
        print(f"--Month: {format_count(oc['month']['t'])} | color=#90a4ae")
        print(f"--Model: {qw_model or 'N/A'} | color=#b0bec5 size=11")

    print("---")
    print(f"Current: v{VERSION} | color=#78909c size=10")
    print(f"Updated: {datetime.now().strftime('%H:%M:%S')} | color=#78909c size=10")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "update":
        if update_plugin():
            print("✅ Update successful!")
        else:
            print("❌ Update failed!")
        sys.exit(0)

    refresh_cache = os.environ.get("XBAR_AI_USAGE_REFRESH_CACHE") == "1"
    if CACHE_PATH.exists() and not refresh_cache:
        age = time.time() - CACHE_PATH.stat().st_mtime
        print(CACHE_PATH.read_text(), end="")
        if CACHE_TTL_SECONDS <= 0 or age < CACHE_TTL_SECONDS:
            sys.exit(0)
        try:
            env = os.environ.copy()
            env["XBAR_AI_USAGE_REFRESH_CACHE"] = "1"
            subprocess.Popen(
                [sys.executable, PLUGIN_PATH],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                close_fds=True,
            )
        except:
            pass
        sys.exit(0)

    output = io.StringIO()
    with redirect_stdout(output):
        main()
    text = output.getvalue()
    try:
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        CACHE_PATH.write_text(text)
    except:
        pass
    if not refresh_cache:
        print(text, end="")
