# lowgear

A lofi, pastel, low-poly off-road drive. Godot 4.7 (Compatibility renderer), everything generated in code.

## Download
Grab the latest build for Linux, Windows or Android from [Releases](https://github.com/Quezka/lowgear/releases). The game checks for updates itself and offers to install them.

To run from source: `godot --path .` (Godot 4.7).

## Controls
W/S gas and brake · A/D steer · Q/E shift · Shift clutch (if manual clutch is on) · L low range · X AWD · Z diff lock · G winch (H reels in) · I engine · Space handbrake (toggle) · F lights · Y hazards · T interact (load, unload, garage) · M map · mouse wheel or +/- zoom · R reset / tow · C camera · Esc pause. Gamepad and touch controls too.

## Playing
Take jobs from the map (M): load cargo at the warehouse, sawmill or logging camp, drive it to the site, press T. Earn money and levels, then buy trucks and upgrades at the garage.

## Vehicles
Sparrow 4x4, Taiga 4x4, Pebble, Kestrel U4, Mule (tractor + trailer), Volok 6x6, Heron 6x6 (crane), Timberline 6x6 (logs), Bastion 8x8. Choose tyres (highway, all-terrain, mud, chains) and a snorkel in the menu. Mud, deep water, fuel and damage matter; fuel stations also repair.

## Multiplayer (up to 4, Linux / Windows / Android together)
- **Host:** press *Host game*. Friends on your network (or Tailscale) press *Join* with the address shown in your HUD.
- **Dedicated server:** `godot --headless --path . -- --server` runs a relay with no car of its own. `server/deploy.sh root@HOST` installs it as a systemd service. It uses UDP 24680: forward that port on the router for friends outside, or use Tailscale.

## Test mode
`godot --path . -- --shot [--menu] [--car=niva] [--host | --join=IP] [--name=Ari] [--tod=0.8] [--out=DIR]` drives on autopilot, saves screenshots at 3/10/20 s and logs FPS.

## Releases
Push a `v*` tag and CI builds Linux, Windows and Android and publishes them (needs the `LOWGEAR_KEYSTORE_B64` and `LOWGEAR_KEYSTORE_PASSWORD` secrets).

Code: MIT. See CREDITS.md.
