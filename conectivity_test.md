# DNS / Connectivity Test Plan

Reference values:

- Pi tailnet IP: `100.77.72.112`
- Pi LAN IP: `192.168.1.100`
- Hostname: `server`

Mac uses Pi-hole as the only ad-blocker, reached via Tailscale (anywhere) or via DHCP-supplied DNS on home WiFi. 
In case of Pi outage, revert to Cloudflare DNS, also supplied by DHCP.

## Section 1 — Tailscale ON (home or anywhere)

Setup: Tailscale connected. Network location doesn't matter.

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
scutil --dns | grep -E "nameserver|resolver #" | head -20      # Expected: nameserver[0] = 100.100.100.100
dig +short pihole.server                                       # Expected: 100.77.72.112
dig +short google.com                                          # Expected: real Google IPs
dig +short doubleclick.net                                     # Expected: 0.0.0.0
curl -s -o /dev/null -w "%{http_code}\n" http://pihole.server  # Expected: 302 (redirect to /admin)
ping -c 2 100.77.72.112                                        # Expected: replies
```

## Section 2 — Tailscale OFF, on home WiFi

Setup: Disable Tailscale. Connected to home WiFi.

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
scutil --dns | grep -E "nameserver|resolver #" | head -20      # Expected: nameserver[0] = 192.168.1.100, [1] = 1.1.1.1
dig +short pihole.server                                       # Expected: 100.77.72.112
dig +short google.com                                          # Expected: real Google IPs
dig +short doubleclick.net                                     # Expected: 0.0.0.0 (Pi-hole)
curl -s -o /dev/null -w "%{http_code}\n" http://pihole.server  # Expected: 000 — Traefik only on tailnet
ping -c 2 192.168.1.100                                        # Expected: replies
ping -c 2 -t 2 100.77.72.112                                   # Expected: no replies
```

## Section 3 — Failover (home WiFi, Tailscale OFF, Pi-hole stopped)

Setup: As Section 2. On Pi: `docker compose stop pihole`.

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
dig +short google.com         # Expected: real IPs after ~5s delay (1.1.1.1 takes over)
dig +short doubleclick.net    # Expected: real IPs (Cloudflare doesn't block)
dig +short pihole.server      # Expected: empty
```

Restart on Pi: `docker compose start pihole`.

## Section 4 — Internet disconnected, home WiFi, Tailscale ON

Setup: Unplug WAN from router. Stay on home WiFi. Tailscale ON.

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
tailscale status                                               # Expected: Pi online, ideally direct
tailscale ping 100.77.72.112                                   # Expected: pong via direct path
dig +short pihole.server                                       # Expected: 100.77.72.112
curl -s -o /dev/null -w "%{http_code}\n" http://pihole.server  # Expected: 302 (redirect to /admin)
dig +short google.com                                          # Expected: SERVFAIL/timeout
ping -c 2 -t 2 8.8.8.8                                         # Expected: no replies
```

## Cleanup

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder