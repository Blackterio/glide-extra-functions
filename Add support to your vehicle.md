## This next code needs to be written at the start of your vehicle's LUA file (before CLIENT and SERVER):
```
AddCSLuaFile()

-- Load Blackterio's Glide Extra Functions LUA file
local function LoadExtraFunctions()
    local paths = {
        "autorun/shared/blackterio_extra_functions.lua",
        "lua/autorun/shared/blackterio_extra_functions.lua",
        "blackterio_extra_functions.lua"
    }
      
    for _, path in ipairs(paths) do
        if file.Exists(path, "LUA") then
            if SERVER then
                AddCSLuaFile(path)
            end
            include(path)
            return true
        end
    end
    return false
end

local extraFunctionsLoaded = LoadExtraFunctions()

local ItHasExtraFunctions = true -- with this you can activate the custom extra functions on this vehicle (pedals, gauges, etc)  
```

## Just after that, you need to define the base class of your vehicle. This is an example with a vehicle of the type "car":
#### Check  Glide's Github to check all the base types
```
DEFINE_BASECLASS( "base_glide_car" ) -- strictly necessary if you wanna make support for custom anims (for example speedometers or tachometers)
```

## In the CLIENT section you need to initialize the Extra Functions for this vehicle:
```
    function ENT:Initialize()
        BaseClass.Initialize(self)

		-- Extra functions activator
		self.HasExtraFunctions = ItHasExtraFunctions
		
    end
```

## Below that, you need to call the "OnUpdateAnimations" (from Glide's base). All the features will be inside this function. 
#### IMPORTANT: build the config ONCE (inside the `if not self.AnimationConfig` guard) and call UpdateAnimations AFTER it. Do NOT call CreateConfig every frame — it copies the whole default config and creates needless garbage; the old examples also called UpdateAnimations before the config existed, so the first frames ran with the default config.
```
-- Extra functions (animations)

function ENT:OnUpdateAnimations()
    if BlackterioExtraFunctions and extraFunctionsLoaded and self.HasExtraFunctions then

        -- Build the config only ONCE per vehicle.
        -- Use a custom configuration for this vehicle in particular (highly
        -- recommended) — otherwise UpdateAnimations falls back to the DefaultConfig.
        -- This example has all the features activated; all of them are enabled
        -- by default (except the digital speedo) so you can skip the ones you don't
        -- need to change, but here we set them anyway as a reference.
        if not self.AnimationConfig then
            self.AnimationConfig = BlackterioExtraFunctions:CreateConfig({

    -- Activate/deactivate functions.
    pedals = true,
    clutch = true,
    speedo = true,
    fuel = true,
    tacho = true,
    oil = true,
    temp = true,
    battery = true,
    wipers = true,	
    ignitionKey = true,      
    lightSwitch = true,      
    wiperSwitch = true,  
    digitalSpeedometer = true,

    -- Pedals lerp
    pedalLerpRate = 0.2,
    
    -- Clutch duration (lerp)
    clutchDuration = 0.4,
    
    -- RPM calibration
    rpmCalibration = -0.04,

    -- Tachometer needle lerp
    tachoLerpRate = 0.15,
	
    -- Speedometer calibration and multiplier	
    speedCalibration = 50,
    speedMultiplier = 0.4,
    
    -- Fuel lerp
    fuelLerpRate = 0.09,

	-- Oil lerp and max value (min/max can be inverted if your gauge runs backwards)
    oilLerpRate = 0.5,
    oilMaxValue = 0.9,
    oilMinValue = 0.5,
	
	-- Temperature lerp and max value
    tempLerpRate = 0.0005,
    tempMaxValue = 0.7,
	
	-- Battery lerp and max value
    batteryLerpRate = 0.09,
    batteryMaxValue = 0.5,
	
    -- Wipers Speed
    wiperSpeed = 0.3,

      -- Switch lerp rates
    ignitionLerpRate = 0.2,  
    lightSwitchLerpRate = 0.2, 
    wiperSwitchLerpRate = 0.2,

    -- Digital Speedometer configuration
    digitalSpeedoPos = Vector(0, 0, 0), -- Text position in vehicle
    digitalSpeedoAng = Angle(0, 0, 0), -- Text angle
    digitalSpeedoScale = 0.05, -- Text scale
    digitalSpeedoFont = "BlackterioDefaultDigitalSpeedo", -- Text font. If you use a CUSTOM font, YOU must create it with surface.CreateFont; the addon no longer creates it for you.
    digitalSpeedoColor = Color(255, 255, 255), -- Text color
    digitalSpeedoUnit = "KMH", -- "KMH" or "MPH", conversions are automatic
    digitalSpeedoShowUnit = false, -- Show speed unit along the speed
    digitalSpeedoRequireEngine = true, -- Only show when engine is on

   --[[ Pose parameters default names. You can change them if they're different than these ones
    poseParameters = {
        gas = "gas",
        brake = "brake",
        clutch = "clutch",
        speedo = "speedo",
        tacho = "tacho",
        fuel = "fuel",
        oil = "oil",
        temp = "temp",
        battery = "battery",
        wipers1 = "wipers1",
        wipers2 = "wipers2",
        wipers3 = "wipers3",
        wipers4 = "wipers4",
        ignitionKey = "ignitionkey",      
        lightSwitch = "lightswitch",      
        wiperSwitch = "wiperswitch",
        handbrake = "handbrake",   -- version 3
        horn = "horn",             -- version 3
        turnStalk = "turnstalk",   -- version 3
        gearLever = "gearlever"    -- version 3 (only used when gearLeverBone = "")
    }
	]]
            })
        end

        BlackterioExtraFunctions:UpdateAnimations(self, self.AnimationConfig)
    else
        BaseClass.OnUpdateAnimations(self)
    end
end

  -- THIS IS ONLY IF YOU CHOOSE TO HAVE A DIGITAL SPEEDOMETER. 
  function ENT:DrawTranslucent()
      self:DrawModel()
      
      -- Draw digital speedometer
      if self.AnimationConfig and self.AnimationConfig.digitalSpeedometer and BlackterioExtraFunctions then
          BlackterioExtraFunctions:DrawDigitalSpeedometer(self, self.AnimationConfig)
      end
  end

end
```

You can activate or deactivate functions as you wish. You can also choose to not specify any custom lerp or calibration values, but it's not really recommended.


The recommended names for the pose parameters of your animations are the ones that are specified by default, but if you want, you can assign a different name for them if that's needed.


I also recommend making animations with a maximum of 3 frames. You can make them with more, but it will need a more precise assignment of the lerp values. Except with the wipers animation, it's better if you make it with 10 frames


---

# New in version 3: controls, engine animations, destination sign and speed limiter

Everything below is **off by default** (`false` in the default config), so a vehicle made with an older version keeps working exactly the same. Turn on only what your vehicle has. The addon must be version 3 or newer: older versions don't know these options.

| Function | Turn it on with | Pose parameter / bone (default name) |
|---|---|---|
| Parking brake lever | `handbrake = true` | pose `handbrake` |
| Horn button | `horn = true` | pose `horn` |
| Turn signal stalk | `turnStalk = true` | pose `turnstalk` |
| Gear lever | `gearLever = true` | bone `gearlever` (or pose `gearlever`) |
| Engine animations (belts, fan...) | `engineAnims = { { pose = "...", speed = ... } }` | the pose names you list |
| Destination sign (LED, 3D2D) | `destinationSign = true` | none (it is drawn, not animated) |
| Speed limiter | `speedLimiter = true` | none (it limits the engine torque) |

The ignition key and the light switch (`ignitionKey` and `lightSwitch`) were already two independent pose parameters. If your model has both pieces, just animate each one with its own pose parameter.

## Share the config with the server: `ENT:GetExtraFunctionsConfig()`

The parking brake and the speed limiter run on the **server** (the handbrake state is networked so every player sees the lever and hears the sound, and the limiter acts on the engine). The server can't read the config you build inside `OnUpdateAnimations` (that function only runs on the client), so define the config in a function that exists in **both realms** (before the `if CLIENT` section). The addon finds it by itself and hooks the vehicle: you don't have to call anything from your `OnSeatInput` or `EngineThink`.

This is the same pattern as `GetAnimationConfig` for the doors. It is also the recommended way to build the config for any new vehicle:

```
function ENT:GetExtraFunctionsConfig()
    if not BlackterioExtraFunctions then return end

    -- Build the config only ONCE per vehicle
    if not self.AnimationConfig then
        self.AnimationConfig = BlackterioExtraFunctions:CreateConfig({
            pedals = true,
            speedo = true,
            -- ... everything from the main example above ...

            handbrake = true,
            horn = true,
            turnStalk = true,
            gearLever = true,
            speedLimiter = true,
        })
    end

    return self.AnimationConfig
end
```

And `OnUpdateAnimations` just uses it:

```
function ENT:OnUpdateAnimations()
    if BlackterioExtraFunctions and extraFunctionsLoaded and self.HasExtraFunctions then
        BlackterioExtraFunctions:UpdateAnimations(self, self:GetExtraFunctionsConfig())
    else
        BaseClass.OnUpdateAnimations(self)
    end
end
```

Notes:
- The config is read ONCE per vehicle and cached, like the doors config.
- Only the parking brake and the speed limiter need `GetExtraFunctionsConfig`. The other new functions only need the config that you pass to `UpdateAnimations`, but there is no reason to build it twice.
- `self.HasExtraFunctions = false` (set only in the CLIENT `Initialize`, as in this guide) stops the animations, but the server side keeps running. To disable a function completely, don't turn it on in the config.

## Parking brake lever

```
handbrake = true,
handbrakeLerpRate = 0.25,
handbrakeOnSound = "path/to/handbrake_on.wav",   -- optional, "" = no sound (default)
handbrakeOffSound = "path/to/handbrake_off.wav", -- optional
```

The lever follows Glide's handbrake key. The sounds are cabin sounds: they are only heard by the player who is inside the vehicle, in first person. The addon doesn't ship handbrake sounds, so use your own.

## Horn button and turn signal stalk

```
horn = true,
hornLerpRate = 0.4,

turnStalk = true,
turnStalkLerpRate = 0.3,
turnStalkLeftSign = -1, -- value of the pose parameter for the LEFT signal; the right one uses the opposite
```

The horn goes from 0 to 1 while it sounds. The stalk goes from -1 to 1: left signal, right signal, and the hazard lights leave it centered (0).

## Gear lever

```
gearLever = true,
gearLeverMode = "tap",       -- "tap", "position" or "h"
gearLeverBone = "gearlever", -- bone to turn. "" = use the pose parameter poseParameters.gearLever instead
gearLeverAxis = 3,           -- bone rotation: 1 = pitch, 2 = yaw, 3 = roll
gearLeverAngle = 20,         -- tap mode: degrees
gearLeverSign = 1,           -- tap mode: -1 inverts the direction
gearLeverHold = 0.25,        -- tap mode: seconds the lever stays pushed
gearLeverLerpRate = 0.35,
gearLeverPositions = {},     -- position mode
```

- **"tap"**: the lever is pushed `gearLeverAngle` degrees forward on every upshift and back on every downshift, and returns to the center after `gearLeverHold` seconds. Good for automatic gearboxes with a +/- lever.
- **"position"**: the lever stays at the value that `gearLeverPositions` has for the current gear. Missing gears go to 0. For example, a reverse / neutral / drive lever by bone:

```
gearLeverMode = "position",
gearLeverAxis = 2,
gearLeverPositions = { [-1] = -20, [0] = 0, [1] = 20 }, -- degrees
```

- **"h"**: an H pattern lever for manual gearboxes, explained below.

- With a pose parameter (`gearLeverBone = ""`) the values aren't degrees: "tap" writes -1 to 1, and "position" writes the numbers of `gearLeverPositions` as they are (use the range of your pose parameter).
- Use the bone when your model already uses all the pose parameters that Source allows (24).

### H pattern lever

The lever moves on two axes: **x** across the gates and **y** forwards/backwards (y = 0 is neutral). On every gear change it goes back to neutral, crosses to the new gate and goes into the gear, like a real gearbox.

```
gearLeverMode = "h",
gearLeverH = {
    positions = {                     -- {x, y} of each gear: -1 = reverse, 0 = neutral
        [-1] = { 1.5, 0.75 },
        [0] = { 0, 0 },
        [1] = { 0.75, 0.75 }, [2] = { 0.75, -1.5 },
        [3] = { -0.75, 0.75 }, [4] = { -0.75, -1.5 },
        [5] = { -1.5, 0.75 }, [6] = { -1.5, -1.5 },
    },
    speedX = 15,                      -- speed across the gates
    speedY = 4.5,                     -- speed forwards/backwards
    bones = {                         -- degrees per unit of x and of y
        { name = "gearlever_low", x = Angle( 0, -4, 0 ), y = Angle( 0, 0, 5 ) },
        { name = "gearlever_top", x = Angle( 0, -8, 0 ), y = Angle( 0, 0, 8 ) },
    },
},
```

- `positions` can use any units. A gear without a position goes to neutral.
- `bones` can have one bone or more (this lever has a lower and an upper bone).
- To find the angles of your bone, try `Angle( 10, 0, 0 )`, `Angle( 0, 10, 0 )` and `Angle( 0, 0, 10 )` with `ManipulateBoneAngles` and keep the ones that tilt the lever sideways and forwards.
- With pose parameters instead of bones: `poseX = "..."` and `poseY = "..."` receive x and y as they are.

Any number of gears works the same way: one position per gear. For example, 4 gears:

```
positions = {
    [-1] = { -1, 1 },
    [0] = { 0, 0 },
    [1] = { 1, 1 }, [2] = { 1, -1 },
    [3] = { 0, 1 }, [4] = { 0, -1 },
},
```

Gearboxes with a range or a splitter use the same position for more than one gear. For example, 12 gears where 7-12 repeat the H of 1-6:

```
local H6 = { { 0.75, 0.75 }, { 0.75, -1.5 }, { -0.75, 0.75 }, { -0.75, -1.5 }, { -1.5, 0.75 }, { -1.5, -1.5 } }

positions = {
    [-1] = { 1.5, 0.75 },
    [0] = { 0, 0 },
    [1] = H6[1], [2] = H6[2], [3] = H6[3], [4] = H6[4], [5] = H6[5], [6] = H6[6],
    [7] = H6[1], [8] = H6[2], [9] = H6[3], [10] = H6[4], [11] = H6[5], [12] = H6[6],
},
```

## Engine animations (belts, fan...)

```
engineAnims = {
    { pose = "engine_belts", speed = 0.25 },
    { pose = "engine_fan", speed = 0.4 },
},
```

Each entry is a looping pose parameter (0 to 1, it should have `loop` enabled in the QC) that advances with the engine RPM. `speed` is how many cycles it does per engine revolution. Keep it low: a real belt pattern would look strobed on screen (`0.25` works well). It doesn't move while the engine is off.

## Editable destination sign (LED, 3D2D)

A panel that shows a text that the player can edit with "Edit Properties" (right click on the vehicle). It scrolls like a marquee when the text doesn't fit.

**1.** Add the editable network vars in `SetupDataTables`. Call it after the base class:

```
function ENT:SetupDataTables()
    BaseClass.SetupDataTables(self)

    BlackterioExtraFunctions:AddEditableVars(self, {
        category = "My Vehicle",   -- category in Edit Properties
        order = 201,               -- position of the first entry (the next one uses order + 1)
        destinationText = true,    -- ENT:GetDestinationText / SetDestinationText (text of the sign)
        speedLimit = true,         -- ENT:GetSpeedLimit / SetSpeedLimit (km/h, see the speed limiter)
        -- speedLimitMax = 500,    -- maximum value of the speed limit
    })
end
```

Ask only for the vars you use. Set the initial text with `self:SetDestinationText("CITY")` (for example in `CreateFeatures`).

**2.** Turn it on in the config:

```
destinationSign = true,
destinationSignPos = Vector(296.4, -39.9, 109.8), -- top left corner of the sign, seen from the front (vehicle coordinates)
destinationSignAng = Angle(0, 90, 90),
destinationSignScale = 0.05,
destinationSignWidth = 716,  -- size in sign pixels. Width * scale = units (716 * 0.05 = 35.8)
destinationSignHeight = 100,
destinationSignFont = "BlackterioDefaultDestinationSign", -- the addon creates this one. A CUSTOM font must be created by you with surface.CreateFont
destinationSignColor = Color(255, 160, 20),
destinationSignBackground = Color(8, 6, 2, 255),
destinationSignGridColor = Color(0, 0, 0, 150), -- dot matrix look. Alpha 0 or GridSize 0 = no grid
destinationSignGridSize = 6,
destinationSignMarqueeSpeed = 120, -- pixels per second when the text doesn't fit
destinationSignDrawDistance = 3000,
destinationSignRequirePower = true, -- only lit with the engine on or the headlights on
```

The defaults are the ones above, so usually you only need `destinationSign = true` and `destinationSignPos`.

**3.** Draw it from the client side of your vehicle (CLIENT only, like the digital speedometer):

```
function ENT:Draw(flags)
    BaseClass.Draw(self, flags)

    if BlackterioExtraFunctions and extraFunctionsLoaded and self.HasExtraFunctions then
        BlackterioExtraFunctions:DrawDestinationSign(self, self:GetExtraFunctionsConfig())
    end
end
```

If your vehicle already draws its model in `DrawTranslucent`, call `DrawDestinationSign` from there instead.

## Speed limiter

Like the electronic limiter of a real bus or truck: the engine torque fades out over the last part before the limit, so the vehicle stops accelerating there. It only limits going forward.

```
speedLimiter = true,
speedLimiterFade = 0.04, -- fraction of the limit where the torque fades out (0.04 = the last 4 %)
speedLimit = 0,          -- fixed limit in km/h if the vehicle doesn't have the editable one. 0 = no limit
```

- If the vehicle has `ENT:GetSpeedLimit()` (added by `AddEditableVars` with `speedLimit = true`), that value is used, so the player can change it from "Edit Properties". Set the default with `self:SetSpeedLimit(120)` in `CreateFeatures`.
- The limit is in km/h **exactly as Glide's HUD and the Wire speedometer show them**, not real km/h.
- A vehicle that doesn't use `speedLimiter` is never limited.

## Click on the switches (v102926)

The driver can hold the free look key (ALT by default), aim at a switch with the center of the screen and click it. First person only. **All off by default**: turn on only what your vehicle has.

```
ignitionKeyClick = true, -- click starts / stops the engine
lightSwitchClick = true, -- click cycles the headlights (off, low, high)
wiperSwitchClick = true, -- click turns the wipers on / off
turnStalkClick = true,   -- left click: left signal, right click: right signal
hornClick = true,        -- the horn sounds while the click is held
handbrakeClick = true,   -- click applies / releases the parking brake

clickSwitchPadding = 0.2, -- units added to each side of the switch's hitbox (they are tiny)
clickSwitchRadius = 1,    -- half size of the box around the bone if the switch has no hitbox

-- Optional: a different size for one switch, by the name of its function
-- (ignitionKey, lightSwitch, wiperSwitch, turnStalk, horn, handbrake)
clickSwitchSizes = {
    ignitionKey = { radius = 1.5 },
    lightSwitch = { padding = 0.3 },
},
```

Turn on `developer 1`, hold the free look key inside the vehicle and the boxes are drawn (the aimed one in green), so you can calibrate them in game.

- Each flag also needs its function on: `lightSwitchClick` needs `lightSwitch = true`, `turnStalkClick` needs `turnStalk = true`, and so on.
- The vehicle has to define `ENT:GetExtraFunctionsConfig()` (see above), because the server reads the flags.
- The click does not move the pose parameters: it changes the real state (engine, lights...) with the same Glide actions as the keys, and the animation follows by itself. So don't animate those poses with anything else.
- The switch is found like the doors: the bones that its pose parameter moves, and the hitboxes of those bones (studiomdl creates one per bone when the QC has no `$hbox`). A bone without hitbox gets a small box around its origin.
- The parking brake stays applied while the driver is seated: Glide releases it when they exit, like the key.
- Turn it off for a player with `blackterio_clickinteract_enable 0` (the same setting of the doors).

## Full example (version 3)

A vehicle with the controls, belts, destination sign and speed limiter:

```
function ENT:GetExtraFunctionsConfig()
    if not BlackterioExtraFunctions then return end

    if not self.AnimationConfig then
        self.AnimationConfig = BlackterioExtraFunctions:CreateConfig({
            pedals = true,
            speedo = true,
            tacho = true,
            wipers = true,

            handbrake = true,
            handbrakeOnSound = "my_vehicle/handbrake_on.wav",
            handbrakeOffSound = "my_vehicle/handbrake_off.wav",
            horn = true,
            turnStalk = true,
            gearLever = true,
            engineAnims = { { pose = "engine_belts", speed = 0.25 } },

            destinationSign = true,
            destinationSignPos = Vector(296.4, -39.9, 109.8),

            speedLimiter = true,
        })
    end

    return self.AnimationConfig
end

function ENT:SetupDataTables()
    BaseClass.SetupDataTables(self)

    BlackterioExtraFunctions:AddEditableVars(self, { category = "My Vehicle", order = 201, destinationText = true, speedLimit = true })
end

-- In CreateFeatures (SERVER):
--     self:SetDestinationText("CITY")
--     self:SetSpeedLimit(120)
```

Tips:
- The pose parameters of the controls are written every frame while the function is on, so don't animate them with anything else.
- The parking brake lever and the gear lever are only animated: the brake itself and the gears are handled by Glide.
- Test in game with a vehicle that is spawned **after** you edit the Lua: the server side is hooked when the vehicle is created. Changing the map is the simplest way to reload everything.
