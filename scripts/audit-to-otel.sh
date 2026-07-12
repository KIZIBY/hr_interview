#!/usr/bin/env bash
# audit-to-otel.sh — конвертер audit.md прогона → OTLP JSON в семантике OpenTelemetry GenAI
# (spec 010, эпик 003 P7). Наблюдаемость харнеса в ПОРТИРУЕМОМ стандарте: любой OTel-инструмент
# (Langfuse/Phoenix/collector) или LV_DCP-приёмник читает наш trace без нашей инструментовки.
#
# Маппинг (OTel GenAI): один SPEC_DIR = один trace; root span `invoke_agent <run>` (весь прогон);
#   agent:<имя>:start/:done → child span `invoke_agent <имя>` (длительность из спаривания deck-lib);
#   tool:<имя> → span `execute_tool <имя>`; usage:agent:<имя> с `tokens=<int>` → gen_ai.usage.* атрибуты.
#   Спаривание :start/:done — ЕДИНЫЙ pair_events из scripts/lib/deck-lib.pl (ARCH-1: не свой парсер,
#   иначе дрейф с Flight Deck). Детерминизм (NFR-2): span/trace-id по ИНДЕКСУ события + cksum пути
#   (не время/random) — повторный прогон даёт 0 дифф. Read-only над уже-опубликованным audit.md.
#
# On-prem guard (FR-6, устав I-1): по умолчанию ОФЛАЙН (пишет OTLP-файл/stdout, 0 сетевых вызовов).
#   --endpoint <url> разрешён ТОЛЬКО для loopback/private-хостов; cloud (*.langfuse.com, публичный IP,
#   сбой парсинга URL) → REJECT (fail-closed). Auth-заголовок приёмника — только env OTEL_EXPORTER_*
#   (I-7, не в argv/логах). --sink lvdcp — адаптер в локальный LV_DCP portfolio (приёмник владельца).
#
# Usage: bash scripts/audit-to-otel.sh <SPEC_DIR> [--out <file|->] [--endpoint <url>] [--sink lvdcp]
# Exit: 0 (файл-режим — всегда; недоступный приёмник — advisory) · 2 = SPEC_DIR/audit.md нет ·
#       3 = on-prem guard REJECT (endpoint вне периметра)
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
DIR=""; OUT="-"; ENDPOINT=""; SINK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:?}"; shift 2;;
    --endpoint) ENDPOINT="${2:?}"; shift 2;;
    --sink) SINK="${2:?}"; shift 2;;
    *) DIR="$1"; shift;;
  esac
done
[ -n "$DIR" ] || { echo "audit-to-otel: FATAL: нужен <SPEC_DIR>" >&2; exit 2; }
[ -f "$DIR/audit.md" ] || { echo "audit-to-otel: FATAL: нет $DIR/audit.md" >&2; exit 2; }

# --- on-prem guard (FR-6, fail-closed): endpoint только loopback/private ---
if [ -n "$ENDPOINT" ]; then
  host="$(printf '%s' "$ENDPOINT" | perl -ne 'if (m{^https?://([^/:]+)}i) { print lc($1) } else { exit 3 }')" || {
    echo "audit-to-otel: REJECT on-prem-guard: не распарсить host из endpoint (fail-closed, I-1)" >&2; exit 3; }
  case "$host" in
    localhost|127.0.0.1|::1|0.0.0.0) ;;                                  # loopback
    10.*|192.168.*) ;;                                                    # private
    172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) ;;                           # private 172.16/12
    *.local|*.internal|*.lan) ;;                                         # локальные домены
    *)
      echo "audit-to-otel: REJECT on-prem-guard: host '$host' вне периметра (cloud/публичный запрещён уставом I-1 — self-hosted loopback/private only)" >&2
      exit 3;;
  esac
fi

SELF_DIR="$SELF_DIR" DIR="$DIR" perl - <<'PERL' > "$SELF_DIR/.otel.$$.json"
use strict; use warnings; use utf8;
binmode STDOUT, ':utf8';
do "$ENV{SELF_DIR}/lib/deck-lib.pl";   # ts2e/dur + ЕДИНЫЙ pair_events (ARCH-1)
my $dir = $ENV{DIR};

my ($ev, $total, $first, $last) = pair_events($dir);

# Детерминизм (NFR-2/ARCH-2): trace-id из cksum пути (стабилен для прогона), span-id из индекса.
sub cksum32 { my $s = shift; my $h = 0; $h = ($h * 31 + $_) & 0xffffffff for unpack('C*', $s); $h }
my $seed = cksum32($dir);
my $trace_id = sprintf('%08x%08x%08x%08x', $seed, $seed ^ 0x5a5a5a5a, $seed ^ 0xa5a5a5a5, $seed ^ 0xffffffff);
my $span_i = 0;
sub next_span { $span_i++; sprintf('%08x%08x', $seed ^ ($span_i*2654435761 & 0xffffffff), $span_i) }
sub nano { my $e = shift; defined $e ? sprintf('%d000000000', $e) : '0' }
sub jstr { my $s = shift // ''; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; $s =~ s/\n/ /g; $s =~ s/[\x00-\x1f]/ /g; '"'.$s.'"' }
sub kv_str { my ($k,$v)=@_; '{"key":'.jstr($k).',"value":{"stringValue":'.jstr($v).'}}' }
sub kv_int { my ($k,$v)=@_; '{"key":'.jstr($k).',"value":{"intValue":"'.$v.'"}}' }

my $root_id = next_span();
my @spans;
# root span = весь прогон (invoke_agent), gen_ai.operation.name
push @spans, join('', '{',
  '"traceId":"',$trace_id,'","spanId":"',$root_id,'","name":',jstr("invoke_agent ".$dir),
  ',"kind":1,"startTimeUnixNano":"',nano($first),'","endTimeUnixNano":"',nano($last),'"',
  ',"attributes":[',kv_str("gen_ai.operation.name","invoke_agent"),',',kv_str("gen_ai.system","lv-agent-team"),',',kv_str("lvat.spec_dir",$dir),']}');

for my $e (@$ev) {
  my $name = $e->{event};
  if ($name =~ /^(.*):done$/ && defined $e->{start_epoch}) {
    my $who = $1;
    my ($op, $label) = $who =~ /^tool:/ ? ('execute_tool', $who) : ('invoke_agent', $who);
    push @spans, join('', '{',
      '"traceId":"',$trace_id,'","spanId":"',next_span(),'","parentSpanId":"',$root_id,'"',
      ',"name":',jstr("$op $label"),',"kind":1',
      ',"startTimeUnixNano":"',nano($e->{start_epoch}),'","endTimeUnixNano":"',nano($e->{epoch}),'"',
      ',"attributes":[',kv_str("gen_ai.operation.name",$op),',',kv_str("lvat.event",$who),
      ($e->{detail} && $e->{detail} ne '-' ? ','.kv_str("lvat.detail",$e->{detail}) : ''),']}');
  }
  elsif ($name =~ /^usage:(.+)$/) {
    # usage:agent:X с tokens=<int> → span с gen_ai.usage.* (D-8: только если tokens= есть)
    my ($tok) = ($e->{detail} // '') =~ /\btokens=(\d+)/;
    next unless defined $tok;
    push @spans, join('', '{',
      '"traceId":"',$trace_id,'","spanId":"',next_span(),'","parentSpanId":"',$root_id,'"',
      ',"name":',jstr("usage $1"),',"kind":1',
      ',"startTimeUnixNano":"',nano($e->{epoch}),'","endTimeUnixNano":"',nano($e->{epoch}),'"',
      ',"attributes":[',kv_str("gen_ai.operation.name","chat"),',',kv_int("gen_ai.usage.total_tokens",$tok),']}');
  }
}

print '{"resourceSpans":[{"resource":{"attributes":[',
  kv_str("service.name","lv-agent-team-pipeline"),',',kv_str("lvat.trace_id",$trace_id),
  ']},"scopeSpans":[{"scope":{"name":"audit-to-otel","version":"1.0"},"spans":[',
  join(',', @spans), ']}]}]}', "\n";
PERL

rc=$?
TMP="$SELF_DIR/.otel.$$.json"
if [ "$rc" -ne 0 ] || [ ! -s "$TMP" ]; then
  rm -f "$TMP"; echo "audit-to-otel: FATAL: конвертация не удалась (rc=$rc)" >&2; exit 2
fi

# --- вывод: файл/stdout (дефолт, офлайн) ---
if [ "$OUT" = "-" ]; then cat "$TMP"; else mkdir -p "$(dirname "$OUT")"; cp "$TMP" "$OUT"; echo "audit-to-otel: → $OUT ($(wc -c <"$TMP" | tr -d ' ') байт)" >&2; fi

# --- опциональный приёмник (advisory: недоступность не роняет, exit 0) ---
if [ -n "$SINK" ] && [ "$SINK" = "lvdcp" ]; then
  # LV_DCP-приёмник (решение владельца): OTLP-файл скармливается локальному LV_DCP portfolio.
  # MCP-инструмент lvdcp_audit_portfolio — оператор/агент вызывает его с этим файлом (мост построен
  # доктринально; on-prem: LV_DCP локален, egress периметра нет). Здесь — только указатель, не сетевой push.
  echo "audit-to-otel: sink=lvdcp → OTLP готов ($TMP-эквивалент в $OUT); скорми в LV_DCP: lvdcp_audit_portfolio(path=<lvdcp-proj>, otlp=<файл>) — приёмник локален (I-1)" >&2
fi
if [ -n "$ENDPOINT" ]; then
  # on-prem endpoint прошёл guard; push под perl-alarm; недоступность = advisory (exit 0)
  if perl -e 'alarm shift; exec @ARGV' 15 curl -sf -X POST -H 'Content-Type: application/json' \
       ${OTEL_EXPORTER_OTLP_HEADERS:+-H "$OTEL_EXPORTER_OTLP_HEADERS"} --data-binary @"$TMP" "$ENDPOINT" >/dev/null 2>&1; then
    echo "audit-to-otel: POST $ENDPOINT ok" >&2
  else
    echo "audit-to-otel: приёмник $ENDPOINT недоступен — OTLP-файл сохранён, скорми позже (advisory, exit 0)" >&2
  fi
fi
rm -f "$TMP"
