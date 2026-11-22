#!/usr/bin/env bash
set -euo pipefail

# 上游：BT Tracker 的 announce URL 列表（每行一条 announce 地址）
SOURCE_URL="https://cf.trackerslist.com/best.txt"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.work"
OUT_SOURCE_DIR="$ROOT_DIR/sing-box/source"
OUT_SRS_DIR="$ROOT_DIR/sing-box/srs"
SINGBOX_VERSION="1.13.8"
SINGBOX_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz"

mkdir -p "$WORK_DIR" "$OUT_SOURCE_DIR" "$OUT_SRS_DIR"

RAW_TMP="$WORK_DIR/cn-tracker-list.best.txt.tmp"
TXT_TMP="$WORK_DIR/cn-tracker-list.txt.tmp"
JSON_TMP="$WORK_DIR/cn-tracker-list.json.tmp"
SRS_TMP="$WORK_DIR/cn-tracker-list.srs.tmp"
TAR_PATH="$WORK_DIR/sing-box.tar.gz"
SINGBOX_DIR="$WORK_DIR/sing-box"
SINGBOX_BIN="$SINGBOX_DIR/sing-box"

curl -fsSL "$SOURCE_URL" -o "$RAW_TMP"

# 从 announce URL 中提取主机域名，去重排序；输出 txt 与 sing-box JSON 源
python3 - <<'PY' "$RAW_TMP" "$TXT_TMP" "$JSON_TMP"
import sys
from urllib.parse import urlsplit

raw, txt_out, json_out = sys.argv[1], sys.argv[2], sys.argv[3]
seen, hosts = set(), []
with open(raw, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        h = urlsplit(s).hostname
        if not h:                      # 兼容无 scheme 的裸域名行
            h = urlsplit('//' + s).hostname
        if not h:
            continue
        h = h.lower().strip('.')
        if h and h not in seen:
            seen.add(h)
            hosts.append(h)
hosts.sort()

with open(txt_out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(hosts) + ('\n' if hosts else ''))

import json
with open(json_out, 'w', encoding='utf-8') as f:
    json.dump({"version": 3, "rules": [{"domain_suffix": hosts}]}, f, ensure_ascii=False)
print(f"tracker hosts: {len(hosts)}")
PY

if [ ! -x "$SINGBOX_BIN" ]; then
  rm -rf "$SINGBOX_DIR"
  mkdir -p "$SINGBOX_DIR"
  curl -fsSL "$SINGBOX_URL" -o "$TAR_PATH"
  tar -xzf "$TAR_PATH" -C "$SINGBOX_DIR" --strip-components=1
fi

"$SINGBOX_BIN" rule-set compile -o "$SRS_TMP" "$JSON_TMP"

mv -f "$TXT_TMP" "$OUT_SOURCE_DIR/cn-tracker-list.txt"
mv -f "$JSON_TMP" "$OUT_SOURCE_DIR/cn-tracker-list.json"
mv -f "$SRS_TMP" "$OUT_SRS_DIR/cn-tracker-list.srs"

echo updated
