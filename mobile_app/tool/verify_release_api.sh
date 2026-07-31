#!/bin/sh
set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

api_url=""
old_ifs=$IFS
IFS=','
for encoded_define in ${DART_DEFINES:-}; do
  if [ "$(/usr/bin/uname -s)" = "Darwin" ]; then
    decoded_define=$(/usr/bin/printf '%s' "$encoded_define" | /usr/bin/base64 -D 2>/dev/null || true)
  else
    decoded_define=$(/usr/bin/printf '%s' "$encoded_define" | base64 --decode 2>/dev/null || true)
  fi
  case "$decoded_define" in
    HISAAB_API_URL=*)
      api_url=${decoded_define#HISAAB_API_URL=}
      ;;
  esac
done
IFS=$old_ifs

case "$api_url" in
  https://*)
    ;;
  *)
    echo "error: Release builds require --dart-define=HISAAB_API_URL=https://your-production-host." >&2
    exit 1
    ;;
esac

after_scheme=${api_url#https://}
case "$after_scheme" in
  *@*|*\?*|*#*)
    echo "error: HISAAB_API_URL must be an HTTPS origin without credentials, query, or fragment." >&2
    exit 1
    ;;
esac

case "$after_scheme" in
  */*)
    path_part=/${after_scheme#*/}
    if [ "$path_part" != "/" ]; then
      echo "error: HISAAB_API_URL must be an origin without a path." >&2
      exit 1
    fi
    ;;
esac

host_port=${after_scheme%%/*}
case "$host_port" in
  \[*\]*)
    host=${host_port#\[}
    host=${host%%\]*}
    ;;
  *)
    host=${host_port%%:*}
    ;;
esac
host=$(/usr/bin/printf '%s' "$host" | /usr/bin/tr '[:upper:]' '[:lower:]')

case "$host" in
  ""|localhost|*.localhost|*.local|*.ts.net|::|::1|::ffff:*|fc*:*|fd*:*|fe[89ab]*:*|ff*:*|0.*|127.*|10.*|169.254.*|192.168.*)
    echo "error: HISAAB_API_URL must use a public HTTPS host for release builds." >&2
    exit 1
    ;;
esac

case "$host" in
  100.*)
    second_octet=$(echo "$host" | /usr/bin/cut -d. -f2)
    if [ "$second_octet" -ge 64 ] 2>/dev/null && [ "$second_octet" -le 127 ] 2>/dev/null; then
      echo "error: HISAAB_API_URL must not use a private network host." >&2
      exit 1
    fi
    ;;
esac

case "$host" in
  *.*.*.*)
    first_octet=$(/usr/bin/printf '%s' "$host" | /usr/bin/cut -d. -f1)
    if [ "$first_octet" -ge 224 ] 2>/dev/null; then
      echo "error: HISAAB_API_URL must use a public unicast host." >&2
      exit 1
    fi
    ;;
esac

case "$host" in
  172.*)
    second_octet=$(echo "$host" | /usr/bin/cut -d. -f2)
    if [ "$second_octet" -ge 16 ] 2>/dev/null && [ "$second_octet" -le 31 ] 2>/dev/null; then
      echo "error: HISAAB_API_URL must not use a private network host." >&2
      exit 1
    fi
    ;;
esac
