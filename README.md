# Caddy Coraza ruleset WAF

This role automates the installation of Caddy that comes with Coraza WAF ruleset.
The precompiled and statically linked Caddy server binary is in roles/caddy_waf_apache_nginx/files/caddy_coraza.

Example usage lives in `examples/`:
- `examples/playbook.yaml`
- `examples/inventory.ini`

## Playbook Overview

### Tasks Included:

1. **Copy Caddy binary** to `/bin/caddy`.
2. **Create a systemd service** file for Caddy.
3. **Reload the systemd daemon** to recognize the new service.
4. **Ensure the Caddy directory** exists at `/etc/caddy/`.
5. **Copy the base Caddyfile** with HTTP configuration.
6. **Set firewall rules** to redirect HTTP and HTTPS traffic through Caddy
7. **Enable and start the Caddy service**.

---

## Building the caddy binary yourself

If you don't want to trust pre built binaries then use the following command to build it with necessary dependencies 

```
CGO_ENABLED=0 
xcaddy build --with github.com/corazawaf/coraza-caddy/v2 --with github.com/corazawaf/coraza-coreruleset --output ./caddy-waf
```

## Variables

### **`caddy_regular_http_port`**  
The regular HTTP port (default: `80`).  
The regular HTTP port used by a web server for HTTP traffic. This port will get routed in iptables

### **`caddy_routed_http_port`**  
The port to which HTTP traffic will be routed (default: `8080`).  
Caddy will handle traffic on this port after it is redirected from `caddy_regular_http_port`.

### **`caddy_regular_https_port`**  
The regular HTTPS port (default: `443`).  
The regular HTTPS port used by a web server for secure HTTPS traffic. This port will get routed in iptables.

### **`caddy_routed_https_port`**  
The port to which HTTPS traffic will be routed (default: `8443`).  
Caddy will handle traffic on this port after it is redirected from `caddy_regular_https_port`.

### **`caddy_discover_vhosts`**
Enable automatic HTTP and TLS vhost discovery from nginx/httpd configs (default: `true`).
When enabled and `caddy_tls`/`caddy_http` are empty, the role runs the discovery script and uses its output
to build per-host HTTPS and HTTP blocks in the Caddyfile.

```
## NB!
**The certificates used will have to contain a  Subject Alternative Names (SANs) configuration for Caddy to work!**

**The changes made to iptables will not be saved with the given playbook. Be careful when overwriting firewall configurations!**

