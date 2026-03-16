#!/usr/bin/env bash
# discover_vhosts.sh - outputs YAML lists for caddy_tls and caddy_http
# Dependencies: bash, awk, openssl
# Usage: sudo ./discover_vhosts.sh

set -uo pipefail

tmp_tls=$(mktemp)
tmp_http=$(mktemp)
trap 'rm -f "$tmp_tls" "$tmp_http"' EXIT

emit_cert_entries() {
    local cert="$1" key="$2"
    [[ -z "$cert" || ! -f "$cert" ]] && return
    [[ -z "$key" || ! -f "$key" ]] && return

    openssl x509 -noout -ext subjectAltName -in "$cert" 2>/dev/null \
        | awk -F'DNS:' '{for(i=2;i<=NF;i++){gsub(/,.*/,"",$i); gsub(/[[:space:]]/,"",$i); print $i}}' \
        | while IFS= read -r san; do
            san=$(echo "$san" | xargs)
            [[ -z "$san" ]] && continue
            printf -- '%s|%s|%s\n' "$san" "$cert" "$key" >> "$tmp_tls"
        done
}

emit_http_entry() {
    local name="$1"
    [[ -z "$name" ]] && return
    [[ "$name" == "_" ]] && return
    printf -- '%s\n' "$name" >> "$tmp_http"
}

# ── nginx ──────────────────────────────────────────────────────────────────────

nginx_entries() {
    command -v nginx &>/dev/null || return
    local full_config
    full_config=$(nginx -T 2>/dev/null) || return

    # Extract server blocks: one line per block -> cert|key
    echo "$full_config" | awk '
    /server[[:space:]]*\{/ {
        cert=""; key=""; depth=1; in_s=1; next
    }
    in_s {
        if (/\{/) depth++
        if (/\}/) { depth--; if (depth==0) { print cert"|"key; in_s=0 } }
        if (/ssl_certificate[[:space:]]/ && !/key/) { gsub(/;/,""); cert=$2 }
        if (/ssl_certificate_key/)                  { gsub(/;/,""); key=$2  }
    }' | while IFS='|' read -r cert key; do
        emit_cert_entries "$cert" "$key"
    done

    echo "$full_config" | awk '
    /server[[:space:]]*\{/ {
        names=""; depth=1; in_s=1; next
    }
    in_s {
        if (/\{/) depth++
        if (/\}/) { depth--; if (depth==0) { print names; in_s=0 } }
        if ($1=="server_name") {
            for(i=2;i<=NF;i++){gsub(/;/,""); names=names" "$i}
        }
    }' | while IFS= read -r names; do
        for name in $names; do
            emit_http_entry "$name"
        done
    done
}

# ── httpd ──────────────────────────────────────────────────────────────────────

httpd_entries() {
    local files=""
    for p in /etc/httpd/conf/httpd.conf /etc/httpd/conf.d \
             /etc/apache2/apache2.conf /etc/apache2/sites-enabled \
             /etc/apache2/conf-enabled \
             /usr/local/etc/httpd /opt/homebrew/etc/httpd; do
        [[ -d "$p" ]] && files+=" $(find "$p" -name "*.conf" 2>/dev/null | tr '\n' ' ')"
        [[ -f "$p" ]] && files+=" $p"
    done
    [[ -z "$files" ]] && return

    for conf in $files; do
        [[ ! -r "$conf" ]] && continue
        local in_vhost=0 cert="" key="" names=""
        while IFS= read -r line; do
            local t="${line#"${line%%[![:space:]]*}"}"
            if echo "$t" | grep -qi "^<VirtualHost "; then
                in_vhost=1; cert=""; key=""; names=""
            elif [[ $in_vhost -eq 1 ]]; then
                if echo "$t" | grep -qi "^</VirtualHost>"; then
                    emit_cert_entries "$cert" "$key"
                    for name in $names; do
                        emit_http_entry "$name"
                    done
                    in_vhost=0
                else
                    case "${t,,}" in
                        sslcertificatefile\ *)    cert=$(echo "$t" | awk '{print $2}') ;;
                        sslcertificatekeyfile\ *) key=$(echo "$t"  | awk '{print $2}') ;;
                        servername\ *)            names+=" $(echo "$t" | awk '{print $2}')" ;;
                        serveralias\ *)           names+=" $(echo "$t" | cut -d' ' -f2-)" ;;
                    esac
                fi
            fi
        done < "$conf"
    done
}

# ── main ───────────────────────────────────────────────────────────────────────

nginx_entries
httpd_entries

if [[ -s "$tmp_tls" ]]; then
    echo "caddy_tls:"
    sort -u "$tmp_tls" | while IFS='|' read -r san cert key; do
        printf -- '  - tls_server_name: "%s"\n    tls_cert: %s\n    tls_key: %s\n' \
            "$san" "$cert" "$key"
    done
else
    echo "caddy_tls: []"
fi

if [[ -s "$tmp_http" ]]; then
    echo "caddy_http:"
    sort -u "$tmp_http" | while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        printf -- '  - server_name: "%s"\n' "$name"
    done
else
    echo "caddy_http: []"
fi