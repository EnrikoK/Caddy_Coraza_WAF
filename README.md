# Caddy setup Playbook with Coraza WAF

This playbook automates the installation of Caddy that comes with Coraza WAF ruleset.
The precompiled and statically linked Caddy server binary can be found in `files/caddy_coraza`

## Playbook Overview

### Tasks Included:

1. **Copy Caddy binary** to `/bin/caddy`.
2. **Create a systemd service** file for Caddy.
3. **Reload the systemd daemon** to recognize the new service.
4. **Ensure the Caddy directory** exists at `/etc/caddy/`.
5. **Copy the base Caddyfile** with HTTP configuration.
6. **Set firewall rules** to block and redirect HTTP and HTTPS traffic through Caddy
7. **Allow inbound traffic** on routed HTTP and HTTPS ports.
8. **Enable and start the Caddy service**.

---

## Variables

### **`caddy_regular_http_port`**  
The regular HTTP port (default: `80`).  
The regular HTTP port used by a web server for HTTP traffic. This port will get blocked in iptables

### **`caddy_routed_http_port`**  
The port to which HTTP traffic will be routed (default: `8080`).  
Caddy will handle traffic on this port after it is redirected from `caddy_regular_http_port`.

### **`caddy_regular_https_port`**  
The regular HTTPS port (default: `443`).  
The regular HTTPS port used by a web server for secure HTTPS traffic. This port will get blocked in iptables.

### **`caddy_routed_https_port`**  
The port to which HTTPS traffic will be routed (default: `8443`).  
Caddy will handle traffic on this port after it is redirected from `caddy_regular_https_port`.

### **`caddy_tls`**  
For any HTTPS traffic a configuration needs to be listed with the following properties.
Keep in mind that any traffic that is incoming from port 443 and is not listed here will be dropped due to the
iptables rule!

A list of TLS configurations, each containing:
- **`tls_server_name`**: The server name for which the TLS certificate is configured.
- **`tls_cert`**: The path to the certificate file.
- **`tls_key`**: The path to the private key file.

Example of configuration:
```yaml
caddy_tls:
  - tls_server_name: "maproovinkorra.ee"
    tls_cert: /etc/pki/tls/certs/selfsigned.crt
    tls_key: /etc/pki/tls/private/selfsigned.key
  - tls_server_name: "test2.ee"
    tls_cert: /test/cert.crt
    tls_key: /test/key.key

```
## NB!
**The certificates used will have to contain a  Subject Alternative Names (SANs) configuration for Caddy to work!**
**The changes made to iptables will not be saved with the given playbook. Be careful when overwriting firewall configurations!**
**Services like Firewalld can conflict with iptables!**