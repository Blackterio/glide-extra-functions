# Glide Extra Functions

Extra functions for developers to use in Glide vehicles: pedals, gauges, wipers, switches, gear lever, destination sign, doors and more.

[![GLuaLint](https://github.com/Blackterio/glide-extra-functions/actions/workflows/glualint.yml/badge.svg)](https://github.com/Blackterio/glide-extra-functions/actions/workflows/glualint.yml)
[![Workshop Page](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-steam-workshop.jross.me%2F3530024086%2Fsubscriptions-text)](https://steamcommunity.com/sharedfiles/filedetails/?id=3530024086)

## Features

- Pedals (throttle, brake and a simulated clutch)
- Speedometer
- Tachometer
- Fuel gauge, visual by default, but functional with the [Fuel System addon](https://steamcommunity.com/sharedfiles/filedetails/?id=3671783761)
- Temp gauge (only visual)
- Oil pressure gauge (works with the engine's RPM)
- Toggleable wipers, with optional Stormfox, Stormfox 2 and GWeather support
- Wipers and light switches
- Ignition key
- Parking brake lever (networked, with optional cabin sounds heard only in first person)
- Horn button and turn signal stalk
- Gear lever (taps on every shift, one position per gear, or an H pattern for manual gearboxes), by bone or pose parameter
- Looping engine animations that follow the RPM (belts, fan...)
- Editable LED destination sign (3D2D, with marquee, line number, several lines and optional transparent background) and electronic speed limiter, both editable from "Edit Properties"
- Support for 9 doors/animations with customizable keys and sounds
- Translated to English, Spanish, French, Portuguese, Russian, Turkish, Ukrainian and Chinese

### Player interaction

- Open/close doors, hood and trunk by aiming at them with the use key (LVS style, compatible with Glide // Car Keys)
- Sit in a specific seat by aiming at it with the use key (optional, per vehicle)
- Open/close doors and other parts from your seat: hold the free look key and click them (optional, per vehicle)
- Click the ignition key, light switch, wiper switch, turn stalk, horn and parking brake lever from the driver's seat (optional, per switch)

## Guides

- [Animation implementation guide](animation_implementation_guide)
- [Add support to your vehicle](Add%20support%20to%20your%20vehicle.md)
- [Full example vehicle that uses every feature](examples/example_full_vehicle.lua)

## Console variables

### Client

| Command | Description
| ------- | -----------
| `blackterio_wipers_mode` `<number>` | Wiper mode: `0` = Auto (weather-based), `1` = Manual (key toggle)
| `blackterio_wipers_sound` `<number>` | Enable wiper sounds
| `blackterio_aimdoors_enable` `<number>` | Aim at a door, hood or trunk and press the use key to open/close it
| `blackterio_aimdoors_hint` `<number>` | Show the Open/Close hint when aiming at a door, hood or trunk
| `blackterio_aimseats_enable` `<number>` | Aim at a seat and press the use key to sit in it
| `blackterio_aimseats_hint` `<number>` | Show the box and the Sit hint when aiming at a seat
| `blackterio_clickinteract_enable` `<number>` | Hold the free look key and click on a vehicle part while seated
| `blackterio_clickinteract_hint` `<number>` | Show the crosshair and the click hint when aiming at a part while seated

### Server

| Command | Description
| ------- | -----------
| `blackterio_aimdoors_require_door` `<number>` | When `1`, vehicles with animated doors can only be entered through an open door. When `0`, the use key enters from anywhere and doors can't be opened by aiming (Glide default)

## Notes

Users need to subscribe to this addon to see these extra functions. If they don't, they simply won't see anything of these features.

## Contributing

Run [GLuaLint](https://github.com/FPtje/GLuaFixer) before opening pull requests. It also runs automatically on every push and pull request.

## License

See [LICENSE](LICENSE).
