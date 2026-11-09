# lowgear

A lofi, pastel, low-poly off-road drive. Godot 4.7 (Compatibility renderer), everything generated in code.

```
godot --path .
```

## Controls
W/S gas and brake · A/D steer · Q/E shift · L low range (Panda, Niva; stop first) · Space handbrake · R reset · C camera · Esc pause · F11 fullscreen. Gamepad works too. An automatic gearbox is in Settings.

## Multiplayer (up to 4)
- **Host:** press *Host game*. Friends on your network (or Tailscale) press *Join* with the address shown in your HUD.
- **Dedicated server:** `godot --headless --path . -- --server` runs a relay with no car of its own. `server/deploy.sh root@HOST` installs it as a systemd service. It uses UDP 24680: forward that port on the router for friends outside, or use Tailscale.

## Test mode
`godot --path . -- --shot [--menu] [--car=niva] [--host | --join=IP] [--name=Ari] [--tod=0.8] [--out=DIR]` drives on autopilot, saves screenshots at 3/10/20 s and logs FPS.
