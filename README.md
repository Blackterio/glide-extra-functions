# glide-extra-functions

## This adds extra functions for developers to use in Glide vehicles:

```
- Pedals (throttle, brake and a simulated clutch)
- Speedometer
- Tachometer
- Fuel gauge - Visual by default, but functional with the Fuel System addon (https://steamcommunity.com/sharedfiles/filedetails/?id=3671783761&searchtext=)
- Temp gauge (only visual)
- Oil pressure gauge (works with the engine's RPM)
- Toggleable wipers ( with Stormfox , Stormfox 2 or GWeather optional support )
- Wipers and light switches
- Ignition key
- Parking brake lever (networked, with optional cabin sounds heard only in first person)
- Horn button and turn signal stalk
- Gear lever (taps on every shift, or one position per gear), by bone or pose parameter
- Looping engine animations that follow the RPM (belts, fan...)
- Editable LED destination sign (3D2D, with marquee) and electronic speed limiter, both editable from "Edit Properties"
- Support for 9 doors/animations with customizable keys and sounds
- Open/close doors, hood and trunk by aiming at them with the use key (LVS style, compatible with Glide // Car Keys)
- Translated to English, Spanish, French, Portuguese, Russian, Turkish, Ukrainian and Chinese
```

### You can see an animation implementation guide for your vehicles in animation_implementation_guide.md

### To add the extra functions (gauges, switches, wipers and, since version 3, the controls, belts, destination sign and speed limiter) to your vehicle, follow "Add support to your vehicle.md"

#### Version 3: every new function is off by default, so vehicles made with older versions keep working the same. The handbrake and the speed limiter also need the vehicle to define `ENT:GetExtraFunctionsConfig()` (explained in the guide).

#### Users need to subscribe to this addon if they want to see these extra functions, in case they don't choose to do it, they simply won't see anything of these features.

