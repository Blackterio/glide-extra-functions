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
        wiperSwitch = "wiperswitch"  
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
