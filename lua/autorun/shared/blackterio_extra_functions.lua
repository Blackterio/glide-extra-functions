-- ============================================
-- Extra animations for Glide vehicles
-- lua/autorun/shared/blackterio_extra_functions.lua
--
-- NOTE: GMod does NOT auto-run lua/autorun/shared/. This file is loaded by
-- lua/glide/autoload/Blackterio_00_Loader.lua, and legacy vehicle templates
-- also include() it directly. The version guard below turns those repeated
-- include()s into cheap no-ops instead of redefining the whole library
-- once per installed vehicle.
-- ============================================

-- DEV NOTE: bump VERSION whenever you edit this file, or autorefresh will
-- hit the guard and your changes won't apply until the next restart.
-- VERSION is the date of the release as YYMMDD, so the guard orders the
-- versions across years. It's shown as vMMDDYY (261026 = v102626).
local VERSION = 261104

if BlackterioExtraFunctions and ( BlackterioExtraFunctions._version or 0 ) >= VERSION then return end

BlackterioExtraFunctions = BlackterioExtraFunctions or {}
BlackterioExtraFunctions._version = VERSION
BlackterioExtraFunctions._versionLabel = string.format( "v%02d%02d%02d", math.floor( VERSION / 100 ) % 100, VERSION % 100, math.floor( VERSION / 10000 ) )

-- This is the default configuration in case you don't choose to make a custom one for your vehicle
BlackterioExtraFunctions.DefaultConfig = {
    -- Activate/deactivate functions
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
    digitalSpeedometer = false, -- False by default, not many vehicles have this feature so it will not be used that much

    -- Added in version 3 (all false by default, so existing vehicles don't change)
    handbrake = false, -- Parking brake lever. Server side needs ENT:GetExtraFunctionsConfig (see Blackterio_Vehicle_Controls.lua)
    horn = false, -- Horn button
    turnStalk = false, -- Turn signal stalk
    gearLever = false, -- Gear lever (tap on every shift, or one position per gear)
    engineAnims = false, -- List of looping engine animations, each one { pose = "pose parameter", speed = cycles per engine revolution }
    destinationSign = false, -- Editable LED destination sign. Call BlackterioExtraFunctions:DrawDestinationSign from ENT:Draw
    speedLimiter = false, -- Electronic speed limiter. Server side needs ENT:GetExtraFunctionsConfig (see Blackterio_Vehicle_Controls.lua)

    -- Click to interact with the switches (all false by default). The driver holds the free look key, aims at the switch and clicks.
    -- Each one also needs its function on (lightSwitchClick needs lightSwitch...) and ENT:GetExtraFunctionsConfig (see Blackterio_Custom_Anims_Aim.lua)
    ignitionKeyClick = false, -- Click starts / stops the engine
    lightSwitchClick = false, -- Click cycles the headlights (off, low, high)
    wiperSwitchClick = false, -- Click turns the wipers on / off
    turnStalkClick = false, -- Left click: left signal, right click: right signal
    hornClick = false, -- The horn sounds while the click is held
    handbrakeClick = false, -- Click applies / releases the parking brake (while the driver is seated)

    -- Pedals lerp
    pedalLerpRate = 0.2,

    -- Clutch Duration (lerp)
    clutchDuration = 0.4,

    -- RPM Calibration
    rpmCalibration = 0.15,

    -- Tachometer needle lerp (was hardcoded to 0.15 before)
    tachoLerpRate = 0.15,

    -- Speedometer calibration and multiplier
    speedCalibration = 90,
    speedMultiplier = 1.9,

    -- Fuel lerp
    fuelLerpRate = 0.1,

    -- Oil lerp and max value
    oilLerpRate = 0.0025,
    oilMaxValue = 1, -- 0 is 0%, 1 is 100%
    oilMinValue = 1, -- 0 is 0%, 1 is 100%

    -- Temperature lerp and max value
    tempLerpRate = 0.1,
    tempMaxValue = 0.5, -- 0 is 0%, 1 is 100%

    -- Battery lerp and max value
    batteryLerpRate = 0.1,
    batteryMaxValue = 0.5,

    -- Wipers speed
    wiperSpeed = 0.3,

    -- Wiper sounds (nil/absent falls back to these defaults; "" disables the sound)
    wiperSwitchSound      = "glide/headlights_on.wav",
    wiperStartCycleSound  = "blackterios_glide_vehicles/misc/wiperstart.wav",
    wiperFinishCycleSound = "blackterios_glide_vehicles/misc/wiperfinish.wav",

    -- Switch lerp rates
    ignitionLerpRate = 0.2,
    lightSwitchLerpRate = 0.2,
    wiperSwitchLerpRate = 0.2,

    -- Click to interact: the switches are tiny, so their hitbox grows by clickSwitchPadding units on each side.
    -- A switch whose bone has no hitbox gets a box of clickSwitchRadius units around the bone's origin instead.
    -- clickSwitchSizes overrides both per switch, by the name of its function:
    --   clickSwitchSizes = { ignitionKey = { radius = 1.5 }, lightSwitch = { padding = 0.3 } }
    -- (ignitionKey, lightSwitch, wiperSwitch, turnStalk, horn, handbrake)
    clickSwitchPadding = 0.2,
    clickSwitchRadius = 1,
    clickSwitchSizes = {},

    -- Digital Speedometer configuration
    digitalSpeedoPos = Vector( 0, 0, 0 ), -- Text position in vehicle
    digitalSpeedoAng = Angle( 0, 0, 0 ), -- Text angle
    digitalSpeedoScale = 0.05, -- Text scale
    digitalSpeedoFont = "BlackterioDefaultDigitalSpeedo", -- Text font (custom fonts must be created by the vehicle author with surface.CreateFont)
    digitalSpeedoColor = Color( 255, 255, 255 ), -- Text color
    digitalSpeedoUnit = "KMH", -- "KMH" or "MPH", conversions are automatic
    digitalSpeedoShowUnit = false, -- Show speed unit
    digitalSpeedoRequireEngine = true, -- Only show when engine is on

    -- Handbrake lever lerp and sounds (cabin sounds: only heard in first person. "" = no sound)
    handbrakeLerpRate = 0.25,
    handbrakeOnSound = "",
    handbrakeOffSound = "",

    -- Horn button lerp
    hornLerpRate = 0.4,

    -- Turn signal stalk lerp. The pose parameter goes from -1 to 1: this is the value for the LEFT signal (the right one uses the opposite)
    turnStalkLerpRate = 0.3,
    turnStalkLeftSign = -1,

    -- Gear lever
    -- gearLeverMode "tap": the lever is pushed gearLeverAngle degrees (forward on upshift, back on downshift) for gearLeverHold seconds and returns to the center
    -- gearLeverMode "position": the lever stays at gearLeverPositions[gear] (for example { [-1] = -20, [0] = 0, [1] = 20 })
    -- gearLeverBone: bone to turn (rotates around gearLeverAxis: 1 = pitch, 2 = yaw, 3 = roll). Set it to "" to use poseParameters.gearLever instead
    -- With a pose parameter, "tap" writes -1 to 1 and "position" writes the values of gearLeverPositions as they are
    -- gearLeverMode "h": H-pattern lever, see gearLeverH below
    gearLeverMode = "tap",
    gearLeverBone = "gearlever",
    gearLeverAxis = 3,
    gearLeverAngle = 20,
    gearLeverSign = 1,
    gearLeverHold = 0.25,
    gearLeverLerpRate = 0.35,
    gearLeverPositions = {},

    -- H-pattern lever (gearLeverMode = "h"). The lever has two axes: x moves across the gates, y forwards/backwards
    -- (y = 0 is the neutral row). On every gear change it goes back to the neutral row, crosses to the gate of the new gear and
    -- then goes into it, like a real H gearbox (and like OMSI's shifter script).
    --   positions = { [gear] = { x, y } }  lever position of each Glide gear (-1 = reverse, 0 = neutral, 1..n)
    --   speedX / speedY                    units per second on each axis
    --   bones = { { name = "bone", x = Angle( p, y, r ), y = Angle( p, y, r ) } }
    --       ManipulateBoneAngles( bone, x * bone.x + y * bone.y ): degrees per unit of each axis, in the bone's local angles.
    --       Several bones are allowed (a lever skinned to a lower and an upper bone, for example)
    --   poseX / poseY                      optional pose parameters that receive x and y as they are
    gearLeverH = {},

    -- Destination sign (3D2D). Needs the DestinationText network var: see BlackterioExtraFunctions:AddEditableVars
    destinationSignPos = Vector( 0, 0, 0 ), -- Top left corner of the sign, seen from the front
    destinationSignAng = Angle( 0, 90, 90 ),
    destinationSignScale = 0.05,
    destinationSignWidth = 716, -- Size in sign pixels (width * scale = units)
    destinationSignHeight = 100,
    destinationSignFont = "BlackterioDefaultDestinationSign", -- Custom fonts must be created by the vehicle author with surface.CreateFont
    destinationSignColor = Color( 255, 160, 20 ),
    destinationSignBackground = Color( 8, 6, 2, 255 ),
    destinationSignShowBackground = true, -- false = no black rectangle (the dot matrix grid is hidden too)
    destinationSignLineFont = "BlackterioDefaultDestinationSign", -- Font of the line number (DestinationLine network var)
    destinationSignLineColor = false, -- false = same as destinationSignColor
    destinationSignLineWidth = 0, -- Width of the line number box in sign pixels. 0 = fits the number
    destinationSignLinePadding = 16, -- Space around the number when destinationSignLineWidth is 0
    destinationSignGridColor = Color( 0, 0, 0, 150 ), -- Dot matrix look. Alpha 0 or destinationSignGridSize 0 = no grid
    destinationSignGridSize = 6,
    destinationSignMarqueeSpeed = 120, -- Pixels per second when the text doesn't fit
    destinationSignDrawDistance = 3000,
    destinationSignRequirePower = true, -- Only lit with the engine on or the headlights on

    -- Painted text (off by default): the text looks painted on the vehicle instead of lit. It is always visible (no power needed),
    -- never scrolls, has no dot matrix grid, and the light that reaches the sign (map, sun, dynamic lights) darkens it, like a real paint.
    -- It fills the whole sign (destinationSignWidth x destinationSignHeight): every line stretches or squeezes on its own width and height until the letters touch the edges.
    -- To leave a margin, make the sign a little smaller. The color picked in Edit Properties still wins over destinationSignPaintedColor.
    destinationSignPainted = false,
    destinationSignPaintedFont = "BlackterioDefaultPaintedSign", -- Custom fonts must be created by the vehicle author with surface.CreateFont (the shape of its letters is assumed like Arial's)
    destinationSignPaintedColor = Color( 20, 20, 20 ),

    -- Curvature of the sign around its vertical axis, from -1 to 1. 0 = flat. Positive curves it forward (the center stays where the flat sign was and the ends go back),
    -- negative curves it back. 1 is an arc of 45 degrees (the ends turn 22.5). The curve fades out with the distance (full up to 400 units, flat from 800)
    destinationSignCurvature = 0,

    -- What a sign shows: "all" = line number at the left and the destination, "text" = only the destination, "line" = only the line number (centered, on the whole sign)
    destinationSignContent = "all",

    -- Several signs: a list of { id = "front", destinationSignPos = ..., any other destinationSign* key }. Each sign starts from this config and changes the keys it lists.
    -- Empty = this config is the only sign. destinationSign = true here turns the feature on for all of them.
    destinationSigns = {},

    -- Changes a sign depending on the skin and the bodygroups (like License Plates' LicensePlateAdvancedConfigs). The first variant that matches a sign wins:
    --   { id = "front", skin = 7, bodygroup = { 17, 1 }, destinationSignPos = ..., destinationSignPainted = true, destinationSign = false ... }
    -- id (a sign of destinationSigns; "main" is the only sign when destinationSigns is empty), skin and bodygroup = { group id, submodel } are optional: the ones given must all match.
    -- The other keys are destinationSign* overrides.
    destinationSignVariants = {},

    -- Speed limiter: the torque fades out over the last speedLimiterFade (fraction) before the limit. Forward only.
    -- The limit in km/h is read from the vehicle (ENT:GetSpeedLimit, see AddEditableVars) or from speedLimit if it doesn't have one. 0 = no limit
    speedLimit = 0,
    speedLimiterFade = 0.04,

    -- OPTIONAL: baseClass = "base_glide_car"
    -- Set this if your vehicle derives from ANOTHER vehicle that also uses
    -- these extra functions (2+ inheritance levels). It resolves the base
    -- whose OnUpdateAnimations should run, instead of vehicle.BaseClass
    -- (which would point back to the parent vehicle and recurse).

    -- Pose parameters names. You can change them if they're different than these ones
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
        handbrake = "handbrake",
        horn = "horn",
        turnStalk = "turnstalk",
        gearLever = "gearlever"
    }
}

-- Create default font for digital speedometer (CLIENT ONLY)
-- NOTE: custom fonts (digitalSpeedoFont) must be created by the vehicle author
-- with surface.CreateFont. This addon no longer (re)creates them: doing so
-- overwrote the author's font definition with the default Tahoma one.
if CLIENT then
    surface.CreateFont( "BlackterioDefaultDigitalSpeedo", {
        font = "Tahoma",
        size = 20,
        weight = 700,
        antialias = true,
    } )

    surface.CreateFont( "BlackterioDefaultDestinationSign", {
        font = "Consolas",
        size = 78,
        weight = 900,
        antialias = false,
    } )

    -- Painted text: the biggest bold font the engine allows (255 is its limit), so stretching it over the sign blurs the edges as little as possible
    surface.CreateFont( "BlackterioDefaultPaintedSign", {
        font = "Arial",
        size = 255,
        weight = 900,
        antialias = true,
    } )
end

-- Frame-rate independent Lerp helper.
-- `rate` keeps the same feel the old per-frame fractions had at 60 FPS,
-- but the result no longer depends on the client's frame rate.
local function FrameLerp( rate, from, to )
    if rate >= 1 then return to end
    if rate <= 0 then return from end
    return Lerp( 1 - ( 1 - rate ) ^ ( FrameTime() * 60 ), from, to )
end

--[[
    Engine states (Glide): 0 = off, 1 = starting, 2 = running, 3 = shutting down.
    Electric gauges (fuel, temp, battery, wipers, ignition key) only react on
    states 1-2: state 3 means the ignition was cut, so needles drop and wipers
    park, like turning the key off in a real car. The oil pressure gauge stays
    up on states 2-3 instead, since pressure exists while the engine spins.
]]
local function AreElectricsOn( vehicle )
    local state = vehicle:GetEngineState()
    return state == 1 or state == 2
end

-- Main function to update anims
function BlackterioExtraFunctions:UpdateAnimations( vehicle, config )
    if not IsValid( vehicle ) then return end

    -- Use default configuration if a custom one isn't specified
    config = config or self.DefaultConfig

    -- Call the base class' animations first.
    -- `config.baseClass` (a class name string) resolves the base explicitly
    -- for vehicles that derive from another extra-functions vehicle; the
    -- re-entrancy guard prevents an infinite BaseClass recursion (it turns
    -- a would-be stack overflow into a harmless skipped call).
    if not vehicle.befInBaseUpdate then
        local base = config.baseClass and baseclass.Get( config.baseClass ) or vehicle.BaseClass
        if base and base.OnUpdateAnimations then
            vehicle.befInBaseUpdate = true
            base.OnUpdateAnimations( vehicle )
            vehicle.befInBaseUpdate = false
        end
    end

    -- Update pedals anim
    if config.pedals then
        self:UpdatePedals( vehicle, config )
    end

    -- Update clutch anim
    if config.clutch then
        self:UpdateClutch( vehicle, config )
    end

    -- Update speedometer and tachometer anims
    if config.speedo or config.tacho then
        self:UpdateGauges( vehicle, config )
    end

    -- Update fuel anim
    if config.fuel then
        self:UpdateFuel( vehicle, config )
    end

    -- Update wipers anim
    if config.wipers then
        self:UpdateWipers( vehicle, config )
    end

    -- Update oil anim
    if config.oil then
        self:UpdateOil( vehicle, config )
    end

    -- Update temperature anim
    if config.temp then
        self:UpdateTemp( vehicle, config )
    end

    -- Update battery anim
    if config.battery then
        self:UpdateBattery( vehicle, config )
    end

    -- Update ignition key anim
    if config.ignitionKey then
        self:UpdateIgnitionKey( vehicle, config )
    end

    -- Update light switch anim
    if config.lightSwitch then
        self:UpdateLightSwitch( vehicle, config )
    end

    -- Update wiper switch anim
    if config.wiperSwitch then
        self:UpdateWiperSwitch( vehicle, config )
    end

    -- Update handbrake lever anim
    if config.handbrake then
        self:UpdateHandbrake( vehicle, config )
    end

    -- Update horn button anim
    if config.horn then
        self:UpdateHorn( vehicle, config )
    end

    -- Update turn signal stalk anim
    if config.turnStalk then
        self:UpdateTurnStalk( vehicle, config )
    end

    -- Update gear lever anim
    if config.gearLever then
        self:UpdateGearLever( vehicle, config )
    end

    -- Update engine anims (belts, fan...)
    if config.engineAnims then
        self:UpdateEngineAnims( vehicle, config )
    end

    -- Invalidate bone cache. This is NOT redundant with the base class call:
    -- our pose parameters were written AFTER the base already invalidated.
    vehicle:InvalidateBoneCache()
end

-- Pedals
function BlackterioExtraFunctions:UpdatePedals( vehicle, config )
    if not vehicle.befGas then
        vehicle.befGas = 0
        vehicle.befBrake = 0
    end

    -- Update accelerator
    vehicle.befGas = FrameLerp( config.pedalLerpRate, vehicle.befGas, vehicle:GetEngineThrottle() )

    -- Update brake
    if vehicle:IsBraking() then
        if vehicle:GetEngineState() <= 1 then
            vehicle.befBrake = FrameLerp( config.pedalLerpRate, vehicle.befBrake, 0 )
        else
            vehicle.befBrake = FrameLerp( config.pedalLerpRate, vehicle.befBrake, vehicle:GetBrakePower() )
        end
    else
        vehicle.befBrake = FrameLerp( config.pedalLerpRate, vehicle.befBrake, 0 )
    end

    vehicle:SetPoseParameter( config.poseParameters.gas, vehicle.befGas )
    vehicle:SetPoseParameter( config.poseParameters.brake, vehicle.befBrake )
end

-- Clutch
function BlackterioExtraFunctions:UpdateClutch( vehicle, config )
    local gear = vehicle:GetGear()

    if gear ~= vehicle.befPrevGear then
        vehicle.befTargetClutch = 1
        vehicle.befClutchStart = vehicle.befClutch or 0
        vehicle.befClutchLerpStart = CurTime()
        vehicle.befClutchReturning = false
        vehicle.befPrevGear = gear
    end

    if vehicle.befTargetClutch then
        local elapsed = CurTime() - vehicle.befClutchLerpStart
        local duration = config.clutchDuration
        -- Lerp from the stored start value so the movement really lasts
        -- `clutchDuration` seconds (lerping from the current value compounded
        -- every frame and finished much earlier than configured).
        vehicle.befClutch = Lerp( math.min( elapsed / duration, 1 ), vehicle.befClutchStart, vehicle.befTargetClutch )

        if elapsed >= duration then
            if not vehicle.befClutchReturning then
                vehicle.befClutchReturning = true
                vehicle.befTargetClutch = 0
                vehicle.befClutchStart = vehicle.befClutch
                vehicle.befClutchLerpStart = CurTime()
            else
                vehicle.befTargetClutch = nil
                vehicle.befClutchReturning = false
            end
        end

        vehicle:SetPoseParameter( config.poseParameters.clutch, vehicle.befClutch )
    end
end

-- Speedometer and tachometer
function BlackterioExtraFunctions:UpdateGauges( vehicle, config )
    if not vehicle.befGauge then
        vehicle.befGauge = 0
        vehicle.befSpeed = 0
        vehicle.befRpm = 0
    end

    -- Update RPM
    if config.tacho then
        local tachoRate = config.tachoLerpRate or 0.15
        if vehicle:GetEngineState() > 0 then
            vehicle.befRpm = FrameLerp( tachoRate, vehicle.befRpm, vehicle:GetEngineRPM() / vehicle:GetMaxRPM() - config.rpmCalibration )
        else
            vehicle.befRpm = FrameLerp( tachoRate, vehicle.befRpm, 0 )
        end
        vehicle:SetPoseParameter( config.poseParameters.tacho, vehicle.befRpm )
    end

    -- Update Speedometer
    -- Longitudinal speed via dot product: same value the old
    -- WorldToLocal(velocity + pos).x gave, without allocating vectors.
    if config.speedo then
        vehicle.befSpeed = vehicle:GetVelocity():Dot( vehicle:GetForward() ) * 0.03
        vehicle.befGauge = vehicle.befSpeed / config.speedCalibration * config.speedMultiplier
        vehicle:SetPoseParameter( config.poseParameters.speedo, vehicle.befGauge )
    end
end

-- Oil
function BlackterioExtraFunctions:UpdateOil( vehicle, config )
    if not vehicle.befOil then
        vehicle.befOil = 0
    end

    local targetOil = 0

    -- Oil pressure gauge: active while the engine spins (states 2 and 3)
    if vehicle:GetEngineState() > 1 then
        local rpmFraction = vehicle:GetEngineRPM() / vehicle:GetMaxRPM()
        local a, b = config.oilMinValue, config.oilMaxValue
        -- Normalized clamp bounds so inverted gauges (min > max) also work
        targetOil = math.Clamp( a + rpmFraction * ( b - a ), math.min( a, b ), math.max( a, b ) )
    end

    vehicle.befOil = FrameLerp( config.oilLerpRate, vehicle.befOil, targetOil )
    vehicle:SetPoseParameter( config.poseParameters.oil, vehicle.befOil )
end

-- Temperature
function BlackterioExtraFunctions:UpdateTemp( vehicle, config )
    if not vehicle.befTemp then
        vehicle.befTemp = 0
    end

    if AreElectricsOn( vehicle ) then
        vehicle.befTemp = FrameLerp( config.tempLerpRate, vehicle.befTemp, config.tempMaxValue )
    else
        vehicle.befTemp = FrameLerp( config.tempLerpRate, vehicle.befTemp, 0 )
    end

    vehicle:SetPoseParameter( config.poseParameters.temp, vehicle.befTemp )
end

-- Battery
function BlackterioExtraFunctions:UpdateBattery( vehicle, config )
    if not vehicle.befBattery then
        vehicle.befBattery = 0
    end

    if AreElectricsOn( vehicle ) then
        vehicle.befBattery = FrameLerp( config.batteryLerpRate, vehicle.befBattery, config.batteryMaxValue )
    else
        vehicle.befBattery = FrameLerp( config.batteryLerpRate, vehicle.befBattery, 0 )
    end

    vehicle:SetPoseParameter( config.poseParameters.battery, vehicle.befBattery )
end

-- Fuel
function BlackterioExtraFunctions:UpdateFuel( vehicle, config )
    if not vehicle.befFuel then
        vehicle.befFuel = 0
        vehicle.befFuelTarget = 0
        vehicle.befFuelNextRead = 0
    end

    if AreElectricsOn( vehicle ) then
        -- Fuel System addon presence is checked on every read tick (cheap),
        -- so it still works if that addon happens to load after us.
        if GlideFuelSystem ~= nil and isfunction( GlideFuelSystem.GetFuel ) then
            -- Throttle reads to every 0.25s (matches GlideFuelSystem consumption tick).
            -- Each frame only does a Lerp; NW2 reads happen at most 4x/second.
            local now = CurTime()
            if now >= vehicle.befFuelNextRead then
                vehicle.befFuelNextRead = now + 0.25

                -- Read NW2 floats directly, bypassing ResolveVehicle / IsFuelSystemDisabled overhead.
                local current = vehicle:GetNW2Float( "glide_fuel_system_value", -1 )
                if current >= 0 then
                    local max = vehicle:GetNW2Float( "glide_fuel_system_forced_max", -1 )
                    if max <= 0 then max = vehicle:GetNW2Float( "glide_fuel_system_max", -1 ) end
                    if max <= 0 then max = GlideFuelSystem.DefaultTankSize or 0 end

                    if max > 0 then
                        vehicle.befFuelTarget = math.Clamp( current / max, 0, 1 )
                    else
                        -- Unknown tank size, treat as full (avoids dividing by nil/zero)
                        vehicle.befFuelTarget = 1
                    end
                else
                    -- Vehicle not tracked by fuel system yet, treat as full
                    vehicle.befFuelTarget = 1
                end
            end
        else
            vehicle.befFuelTarget = 1
        end
    else
        vehicle.befFuelTarget = 0
    end

    vehicle.befFuel = FrameLerp( config.fuelLerpRate, vehicle.befFuel, vehicle.befFuelTarget )
    vehicle:SetPoseParameter( config.poseParameters.fuel, vehicle.befFuel )
end


-- Shared weather addon detection (used by UpdateWipers and UpdateWiperSwitch)
function BlackterioExtraFunctions:_EnsureWeatherChecked()
    if self._weatherChecked then return end
    self._weatherChecked = true
    self._hasStormFox = StormFox ~= nil
    self._hasStormFox2 = StormFox2 ~= nil
    self._hasGWeather = gWeather ~= nil and gWeather.IsRaining ~= nil
end

-- Resolve a wiper sound: nil (key absent) falls back to DefaultConfig; "" means no sound.
local function ResolveWiperSound( config, key, defaults )
    local snd = config[key]
    if snd == nil then return defaults[key] end
    if snd == "" then return nil end
    return snd
end

-- Writes the wiper pose parameters, skipping the 4 SetPoseParameter calls
-- when the wipers are parked and were already written as parked last frame.
local function ApplyWiperPose( vehicle, config, value )
    if value == 0 and vehicle.befWipersParked then return end
    vehicle.befWipersParked = ( value == 0 )

    vehicle:SetPoseParameter( config.poseParameters.wipers1, value )
    vehicle:SetPoseParameter( config.poseParameters.wipers2, value )
    vehicle:SetPoseParameter( config.poseParameters.wipers3, value )
    vehicle:SetPoseParameter( config.poseParameters.wipers4, value )
end

-- Wipers
function BlackterioExtraFunctions:UpdateWipers( vehicle, config )
    self:_EnsureWeatherChecked()

    -- Wiper state and mode come from NW2 vars on the vehicle (set server-side
    -- from the DRIVER's settings), so every client sees the same animation.
    local useManualMode    = vehicle:GetNW2Bool( "blackterio_wipers_manual_mode", false )
    local manualOn         = vehicle:GetNW2Bool( "blackterio_wipers_on", false )
    local weatherAvailable = self._hasStormFox or self._hasStormFox2 or self._hasGWeather
    local soundEnabled     = self.IsWiperSoundEnabled == nil or self:IsWiperSoundEnabled()

    -- Seed manual-toggle tracking on first call (avoids false trigger on spawn)
    if vehicle.befPrevManualWiper == nil then
        vehicle.befPrevManualWiper = manualOn
    end

    -- Switch sound: plays when key toggles AND weather isn't already controlling the wipers
    if manualOn ~= vehicle.befPrevManualWiper then
        vehicle.befPrevManualWiper = manualOn
        if soundEnabled and ( useManualMode or not vehicle.befPrevAutoShouldWipe ) then
            local snd = ResolveWiperSound( config, "wiperSwitchSound", self.DefaultConfig )
            if snd then vehicle:EmitSound( snd ) end
        end
    end

    -- No source of wiping available: keep wipers off
    if not manualOn and not useManualMode and not weatherAvailable and not vehicle.befWipersActive then
        vehicle.befWipers = 0
        ApplyWiperPose( vehicle, config, 0 )
        return
    end

    if not vehicle.befOldWipers then
        vehicle.befOldWipers = CurTime()
        vehicle.befWipers = 0
        vehicle.befWipersActive = false
    end

    local shouldWipe = false
    local engineOn   = AreElectricsOn( vehicle ) -- state 3 (shutting down) parks the wipers

    if manualOn then
        shouldWipe = engineOn
    elseif not useManualMode then
        if self._hasStormFox then
            shouldWipe = StormFox.IsRaining() and engineOn
        elseif self._hasStormFox2 then
            shouldWipe = StormFox2.Weather.HasDownfall() and engineOn
        elseif self._hasGWeather then
            shouldWipe = ( gWeather:IsRaining() or gWeather:IsSnowing() ) and engineOn
        end
    end

    -- Switch sound para modo auto: weather activa/desactiva los wipers
    if not manualOn then
        if vehicle.befPrevAutoShouldWipe == nil then
            vehicle.befPrevAutoShouldWipe = shouldWipe
        elseif shouldWipe ~= vehicle.befPrevAutoShouldWipe then
            vehicle.befPrevAutoShouldWipe = shouldWipe
            if soundEnabled then
                local snd = ResolveWiperSound( config, "wiperSwitchSound", self.DefaultConfig )
                if snd then vehicle:EmitSound( snd ) end
            end
        end
    end

    if shouldWipe then
        vehicle.befWipersActive = true
        vehicle.befWipers = math.sin( ( CurTime() - vehicle.befOldWipers ) / config.wiperSpeed )
    else
        if vehicle.befWipersActive then
            local sinVal = math.sin( ( CurTime() - vehicle.befOldWipers ) / config.wiperSpeed )
            if sinVal <= 0 then
                vehicle.befWipersActive = false
                vehicle.befWipers = 0
                vehicle.befOldWipers = CurTime()
            else
                vehicle.befWipers = sinVal
            end
        else
            vehicle.befWipers = 0
            vehicle.befOldWipers = CurTime()
        end
    end

    -- Cycle sounds: value-based detection on the actual pose parameter
    if vehicle.befWipersActive then
        local cur     = vehicle.befWipers
        local prev    = vehicle.befPrevWipersSound          -- nil en el primer frame activo
        local curAbs  = math.abs( cur )
        local prevAbs = prev and math.abs( prev ) or 0

        if CLIENT then
            -- Start: primera activación, o wiper cruza cero ascendiendo (inicio de barrido)
            if soundEnabled and ( prev == nil or ( prev < 0 and cur > 0 ) ) then
                local snd = ResolveWiperSound( config, "wiperStartCycleSound", self.DefaultConfig )
                if snd then vehicle:EmitSound( snd ) end
            end

            -- Peak: marcar al entrar en zona de máximo recorrido (solo en semiciclo positivo)
            if cur > 0 and curAbs >= 0.95 and prevAbs < 0.95 then
                vehicle.befWiperAbovePeak = true
            end
            -- Finish: el wiper pasó el pico y ya está bajando
            if vehicle.befWiperAbovePeak and prev ~= nil and curAbs < prevAbs then
                vehicle.befWiperAbovePeak = false
                if soundEnabled then
                    local snd = ResolveWiperSound( config, "wiperFinishCycleSound", self.DefaultConfig )
                    if snd then vehicle:EmitSound( snd ) end
                end
            end
        end

        vehicle.befPrevWipersSound = cur
    else
        vehicle.befPrevWipersSound = nil
        vehicle.befWiperAbovePeak  = false
    end

    ApplyWiperPose( vehicle, config, vehicle.befWipers )
end

-- Ignition Key Animation
function BlackterioExtraFunctions:UpdateIgnitionKey( vehicle, config )
    if not vehicle.befIgnitionKey then
        vehicle.befIgnitionKey = 0
    end

    local engineState = vehicle:GetEngineState()
    local targetKeyPosition = 0

    if engineState == 1 then
        targetKeyPosition = 0.5
    elseif engineState == 2 then
        targetKeyPosition = 1
    end
    -- States 0 and 3 (shutting down = key turned off) return the key to 0

    vehicle.befIgnitionKey = FrameLerp( config.ignitionLerpRate, vehicle.befIgnitionKey, targetKeyPosition )
    vehicle:SetPoseParameter( config.poseParameters.ignitionKey, vehicle.befIgnitionKey )
end

-- Light Switch Animation
function BlackterioExtraFunctions:UpdateLightSwitch( vehicle, config )
    if not vehicle.befLightSwitch then
        vehicle.befLightSwitch = 0
    end

    local headlightState = vehicle:GetHeadlightState()
    local targetSwitchPosition = 0

    if headlightState == 1 then
        targetSwitchPosition = 0.5
    elseif headlightState == 2 then
        targetSwitchPosition = 1
    end

    vehicle.befLightSwitch = FrameLerp( config.lightSwitchLerpRate, vehicle.befLightSwitch, targetSwitchPosition )
    vehicle:SetPoseParameter( config.poseParameters.lightSwitch, vehicle.befLightSwitch )
end

-- Wiper Switch Animation
function BlackterioExtraFunctions:UpdateWiperSwitch( vehicle, config )
    self:_EnsureWeatherChecked()

    if not vehicle.befWiperSwitch then
        vehicle.befWiperSwitch = 0
    end

    local useManualMode = vehicle:GetNW2Bool( "blackterio_wipers_manual_mode", false )
    local manualOn      = vehicle:GetNW2Bool( "blackterio_wipers_on", false )
    local engineOn      = AreElectricsOn( vehicle )
    local shouldWipe    = false

    if manualOn then
        shouldWipe = engineOn
    elseif not useManualMode then
        if self._hasStormFox then
            shouldWipe = StormFox.IsRaining() and engineOn
        elseif self._hasStormFox2 then
            shouldWipe = StormFox2.Weather.HasDownfall() and engineOn
        elseif self._hasGWeather then
            shouldWipe = ( gWeather:IsRaining() or gWeather:IsSnowing() ) and engineOn
        end
    end

    local wipersActive = vehicle.befWipers ~= 0 and vehicle.befWipersActive

    local targetSwitchPosition = ( shouldWipe or wipersActive ) and 1 or 0
    vehicle.befWiperSwitch = FrameLerp( config.wiperSwitchLerpRate, vehicle.befWiperSwitch, targetSwitchPosition )
    vehicle:SetPoseParameter( config.poseParameters.wiperSwitch, vehicle.befWiperSwitch )
end

-- Handbrake lever
-- The state comes from the "blackterio_handbrake" NW2Int, published by the server
-- (Blackterio_Vehicle_Controls.lua): counter * 2 + state, 1 = applied. The counter
-- changes on every press and release, so clients can tell when to play the sounds.
function BlackterioExtraFunctions:UpdateHandbrake( vehicle, config )
    if not vehicle.befHandbrake then
        vehicle.befHandbrake = 0
    end

    local nw = vehicle:GetNW2Int( "blackterio_handbrake", 0 )
    local applied = nw % 2 == 1

    vehicle.befHandbrake = FrameLerp( config.handbrakeLerpRate, vehicle.befHandbrake, applied and 1 or 0 )
    vehicle:SetPoseParameter( config.poseParameters.handbrake, vehicle.befHandbrake )

    -- Cabin sounds, only heard from the inside. The first read is only a baseline
    local last = vehicle.befHandbrakeSeen
    vehicle.befHandbrakeSeen = nw

    if CLIENT and last ~= nil and nw ~= last and vehicle.isLocalPlayerInFirstPerson then
        local onSound, offSound = config.handbrakeOnSound, config.handbrakeOffSound
        local snd = applied and onSound or offSound

        if snd and snd ~= "" then
            local other = applied and offSound or onSound
            if other and other ~= "" then vehicle:StopSound( other ) end

            vehicle:EmitSound( snd, 70, 100, 1, CHAN_AUTO )
        end
    end
end

-- Horn button
function BlackterioExtraFunctions:UpdateHorn( vehicle, config )
    if not vehicle.befHorn then
        vehicle.befHorn = 0
    end

    vehicle.befHorn = FrameLerp( config.hornLerpRate, vehicle.befHorn, vehicle:GetIsHonking() and 1 or 0 )
    vehicle:SetPoseParameter( config.poseParameters.horn, vehicle.befHorn )
end

-- Turn signal stalk: 1 = left signal, 2 = right signal, 3 = hazards (leave it centered)
function BlackterioExtraFunctions:UpdateTurnStalk( vehicle, config )
    if not vehicle.befTurnStalk then
        vehicle.befTurnStalk = 0
    end

    local signal = vehicle:GetTurnSignalState()
    local left = config.turnStalkLeftSign
    local target = 0

    if signal == 1 then
        target = left
    elseif signal == 2 then
        target = -left
    end

    vehicle.befTurnStalk = FrameLerp( config.turnStalkLerpRate, vehicle.befTurnStalk, target )
    vehicle:SetPoseParameter( config.poseParameters.turnStalk, vehicle.befTurnStalk )
end

-- Gear lever (bone or pose parameter, "tap" or "position" mode)
local leverAng = Angle()

function BlackterioExtraFunctions:UpdateGearLever( vehicle, config )
    if config.gearLeverMode == "h" then
        return self:UpdateGearLeverH( vehicle, config )
    end

    local boneName = config.gearLeverBone
    local useBone = boneName ~= nil and boneName ~= ""

    if useBone and ( vehicle.befLeverBone == nil or vehicle.befLeverModel ~= vehicle:GetModel() ) then
        vehicle.befLeverBone = vehicle:LookupBone( boneName ) or false
        vehicle.befLeverModel = vehicle:GetModel()
    end

    if useBone and not vehicle.befLeverBone then return end

    local gear = vehicle:GetGear()
    local target = 0

    if config.gearLeverMode == "position" then
        target = config.gearLeverPositions[gear] or 0
    else
        local last = vehicle.befLeverGear
        vehicle.befLeverGear = gear

        if last ~= nil and gear ~= last then
            vehicle.befLeverTap = gear > last and 1 or -1
            vehicle.befLeverHoldUntil = CurTime() + config.gearLeverHold
        end

        if ( vehicle.befLeverTap or 0 ) ~= 0 and CurTime() > ( vehicle.befLeverHoldUntil or 0 ) then
            vehicle.befLeverTap = 0
        end

        target = ( vehicle.befLeverTap or 0 ) * config.gearLeverSign * ( useBone and config.gearLeverAngle or 1 )
    end

    vehicle.befLever = FrameLerp( config.gearLeverLerpRate, vehicle.befLever or 0, target )

    if useBone then
        leverAng[1], leverAng[2], leverAng[3] = 0, 0, 0
        leverAng[config.gearLeverAxis] = vehicle.befLever
        vehicle:ManipulateBoneAngles( vehicle.befLeverBone, leverAng )
    else
        vehicle:SetPoseParameter( config.poseParameters.gearLever, vehicle.befLever )
    end
end

-- H-pattern gear lever: back to the neutral row, across to the gate, into the gear
local hAng = Angle()
local zeroAng = Angle()

function BlackterioExtraFunctions:UpdateGearLeverH( vehicle, config )
    local h = config.gearLeverH
    if not h or not h.positions then return end

    local bones = h.bones or {}

    if vehicle.befHModel ~= vehicle:GetModel() then
        vehicle.befHModel = vehicle:GetModel()
        vehicle.befHBones = {}

        for i, b in ipairs( bones ) do
            vehicle.befHBones[i] = vehicle:LookupBone( b.name or "" ) or false
        end
    end

    local target = h.positions[vehicle:GetGear()] or h.positions[0] or { 0, 0 }
    local tx, ty = target[1] or target.x or 0, target[2] or target.y or 0

    -- first frame: start at the current gear, without travelling
    local x, y = vehicle.befHX or tx, vehicle.befHY or ty
    local dt = FrameTime()

    if math.abs( x - tx ) > 1e-4 then
        if math.abs( y ) > 1e-4 then
            y = math.Approach( y, 0, ( h.speedY or 4.5 ) * dt )   -- out of the gear, to the neutral row
        else
            x = math.Approach( x, tx, ( h.speedX or 15 ) * dt )   -- across the gates
        end
    else
        y = math.Approach( y, ty, ( h.speedY or 4.5 ) * dt )      -- into the gear
    end

    vehicle.befHX, vehicle.befHY = x, y

    for i, b in ipairs( bones ) do
        local bone = vehicle.befHBones[i]

        if bone then
            local ax, ay = b.x or zeroAng, b.y or zeroAng
            hAng[1] = ax[1] * x + ay[1] * y
            hAng[2] = ax[2] * x + ay[2] * y
            hAng[3] = ax[3] * x + ay[3] * y
            vehicle:ManipulateBoneAngles( bone, hAng )
        end
    end

    if h.poseX then vehicle:SetPoseParameter( h.poseX, x ) end
    if h.poseY then vehicle:SetPoseParameter( h.poseY, y ) end
end

-- Engine animations: each entry is a looping pose parameter (0 to 1) that advances
-- with the engine RPM. `speed` = cycles per engine revolution (keep it low, a real
-- belt pattern would look strobed)
function BlackterioExtraFunctions:UpdateEngineAnims( vehicle, config )
    local anims = config.engineAnims
    if type( anims ) ~= "table" then return end

    local phases = vehicle.befEnginePhases

    if not phases then
        phases = {}
        vehicle.befEnginePhases = phases
    end

    local rpm = vehicle:GetEngineState() > 0 and vehicle:GetEngineRPM() or 0

    for i, anim in ipairs( anims ) do
        local phase = phases[i] or 0

        if rpm > 0 then
            phase = ( phase + rpm / 60 * ( anim.speed or 0.25 ) * FrameTime() ) % 1
            phases[i] = phase
        end

        vehicle:SetPoseParameter( anim.pose, phase )
    end
end

-- Digital Speedometer (CLIENT ONLY)
if CLIENT then
    function BlackterioExtraFunctions:DrawDigitalSpeedometer( vehicle, config )
        -- Check if engine state requirement is met
        if config.digitalSpeedoRequireEngine and ( not vehicle:GetEngineState() or vehicle:GetEngineState() == 0 ) then
            return
        end

        -- Calculate speed based on unit
        local speedMultiplier = config.digitalSpeedoUnit == "MPH" and 0.04261363636 or 0.06858
        -- MPH and KMH values from: https://github.com/wiremod/wire/blob/master/lua/entities/gmod_wire_speedometer.lua
        -- Longitudinal speed only: falling or sliding sideways shouldn't
        -- register on the speedometer.
        local speed = math.floor( math.abs( vehicle:GetVelocity():Dot( vehicle:GetForward() ) ) * speedMultiplier )
        local unitText = config.digitalSpeedoUnit == "MPH" and "MPH" or "KM/H"

        -- Custom fonts (digitalSpeedoFont) must be created by the vehicle
        -- author with surface.CreateFont before this is drawn.

        -- Calculate position and angle
        local pos = vehicle:LocalToWorld( config.digitalSpeedoPos )
        local ang = vehicle:LocalToWorldAngles( config.digitalSpeedoAng )

        -- 3D2D text can't be seen from behind: don't draw it then
        if ang:Up():Dot( EyePos() - pos ) <= 0 then return end

        -- Draw 3D2D speedometer
        cam.Start3D2D( pos, ang, config.digitalSpeedoScale )
            local displayText = config.digitalSpeedoShowUnit and ( speed .. " " .. unitText ) or tostring( speed )
            draw.SimpleText( displayText, config.digitalSpeedoFont, 0, 0, config.digitalSpeedoColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
        cam.End3D2D()
    end
end

-- Destination signs (CLIENT ONLY): LED panels, or painted text, that show the DestinationText / DestinationLine / DestinationColor network vars.
-- One sign by default (the config itself). `config.destinationSigns` lists several: each one has an `id` and its own destinationSign* keys, on top of the base config.
-- `config.destinationSignVariants` changes a sign (position, angle, painted text, hidden...) depending on the skin and the bodygroups, like License Plates does.
if CLIENT then
    -- Keys of a sign entry / variant that choose the sign or the moment, not config overrides
    local SIGN_SKIP = { id = true }
    local VARIANT_SKIP = { id = true, skin = true, bodygroup = true }

    -- { [config] = { [sign] = { base = config of the sign, [variant] = config of the sign with that variant } } }, built once
    local signCaches = setmetatable( {}, { __mode = "k" } )

    -- Shallow copy of `base` with the keys of `overrides` on top
    local function MergeConfig( base, overrides, skip )
        local merged = {}

        for k, v in pairs( base ) do
            merged[k] = v
        end

        for k, v in pairs( overrides ) do
            if not skip[k] then merged[k] = v end
        end

        return merged
    end

    -- A variant applies when its id (if it has one), its skin (if it has one) and its bodygroup { id, submodel } (if it has one) match
    local function VariantMatches( vehicle, variant, signId )
        if variant.id ~= nil and variant.id ~= signId then return false end
        if variant.skin ~= nil and vehicle:GetSkin() ~= variant.skin then return false end

        local bodygroup = variant.bodygroup
        if bodygroup and vehicle:GetBodygroup( bodygroup[1] ) ~= bodygroup[2] then return false end

        return true
    end

    -- Config to draw one sign with: the sign (nil = the base config is the only sign) plus the first variant that matches
    local function ResolveSign( vehicle, config, sign, signId )
        local variants = config.destinationSignVariants
        local hasVariants = variants ~= nil and #variants > 0

        if not sign and not hasVariants then return config end

        local cache = signCaches[config]

        if not cache then
            cache = {}
            signCaches[config] = cache
        end

        local entry = cache[sign or config]

        if not entry then
            entry = { base = sign and MergeConfig( config, sign, SIGN_SKIP ) or config }
            cache[sign or config] = entry
        end

        if hasVariants then
            for i = 1, #variants do
                local variant = variants[i]

                if VariantMatches( vehicle, variant, signId ) then
                    local resolved = entry[variant]

                    if not resolved then
                        resolved = MergeConfig( entry.base, variant, VARIANT_SKIP )
                        entry[variant] = resolved
                    end

                    return resolved
                end
            end
        end

        return entry.base
    end

    -- Where the ink of capitals and digits is inside the line of the painted font (measured on Arial): top and bottom as a fraction of the line
    -- (the bottom goes down to 1 with descenders) and the empty space at each side of a text
    local INK_TOP, INK_BOTTOM, INK_SIDE = 0.185, 0.825, 0.037
    local DESCENDERS = "[gjpqyQ,;]"

    -- Vertical scale that makes the ink of the lines fill `boxH` (surface font already set). Returns the height of one line too
    local function PaintedScaleY( lines, boxH )
        local _, th = surface.GetTextSize( "A" )
        local bottom = string.find( lines[#lines], DESCENDERS ) and 1 or INK_BOTTOM

        return boxH / ( ( #lines - 1 ) * th + ( bottom - INK_TOP ) * th ), th
    end

    -- Reused by every painted line (the signs are drawn one after another): no new objects per frame
    local lineMatrix, lineTranslate, lineScale = Matrix(), Vector(), Vector( 1, 1, 1 )

    -- Painted text: every line stretches or squeezes on its own width and the block on its height, until the ink fills a box of boxW x boxH
    -- that is centered on centerX and starts at the top of the sign (surface font and color already set)
    local function DrawPaintedLines( lines, centerX, boxW, boxH )
        local sy, th = PaintedScaleY( lines, boxH )

        for i, line in ipairs( lines ) do
            local tw = surface.GetTextSize( line )

            lineTranslate.x = centerX
            lineScale.x, lineScale.y = boxW / ( tw - INK_SIDE * 2 * th ), sy
            lineMatrix:Identity()
            lineMatrix:SetTranslation( lineTranslate )
            lineMatrix:SetScale( lineScale )

            cam.PushModelMatrix( lineMatrix, true ) -- multiply: keep the 3D2D transform
                surface.SetTextPos( -tw * 0.5, ( i - 1 ) * th - INK_TOP * th )
                surface.DrawText( line )
            cam.PopModelMatrix()
        end
    end

    -- ===== Culling, level of detail, curvature and the caches of the signs =====
    -- New on every load of this file: the caches that vehicles keep from an older load are rebuilt, never reused
    local CACHE_TOKEN = {}
    local WEAK_KEYS = { __mode = "k" }

    local ARC_AT_FULL_CURVATURE = 45 -- degrees of arc of a sign with destinationSignCurvature = 1 (the ends turn half of it)
    local STRIP_ANGLE = 3 -- degrees of arc of every flat strip of a curved sign
    local MAX_STRIPS = 32
    local LOD_LEVELS = 8 -- the curve fades out in this many steps with the distance (each step has its own cached strips)
    local LOD_NEAR, LOD_FAR = 400, 800 -- units: full curve up to LOD_NEAR, flat from LOD_FAR
    local FADE_FRACTION = 0.15 -- the last part of destinationSignDrawDistance fades out instead of cutting

    -- What a sign draws, filled for every sign (they are drawn one after another)
    local ctx = {}

    -- Parses the destination text in lines (separated by "|"). The result is kept in the cache of the sign until the text changes
    local function ParseLines( text )
        local lines = {}

        for part in string.gmatch( text, "[^|]+" ) do
            part = string.Trim( part )
            if part ~= "" then lines[#lines + 1] = part end
        end

        return lines
    end

    -- Geometry of one sign in the coordinates of the vehicle, kept on the vehicle. It is checked against the values of the config on every frame
    -- (position, angle, scale, size and curvature), so changing any of them rebuilds it. Texts are not part of it
    local function GetGeometry( vehicle, config )
        local store = vehicle.befSignGeo

        if not store or store.token ~= CACHE_TOKEN then
            store = setmetatable( { token = CACHE_TOKEN }, WEAK_KEYS )
            vehicle.befSignGeo = store
        end

        local pos, ang = config.destinationSignPos, config.destinationSignAng
        local scale, w, h, curv = config.destinationSignScale, config.destinationSignWidth, config.destinationSignHeight, config.destinationSignCurvature or 0
        local geo = store[config]

        if geo and geo.pos == pos and geo.ang == ang and geo.scale == scale and geo.w == w and geo.h == h and geo.curvRaw == curv then
            return geo
        end

        geo = { pos = Vector( pos ), ang = Angle( ang ), scale = scale, w = w, h = h, curvRaw = curv, curv = math.Clamp( curv, -1, 1 ), levels = {} }

        local widthUnits, heightUnits = w * scale, h * scale
        local right, down, normal = geo.ang:Forward(), geo.ang:Right(), geo.ang:Up()

        geo.center = geo.pos + right * ( widthUnits * 0.5 ) + down * ( heightUnits * 0.5 )
        geo.normal = normal

        -- Bounding sphere of the sign (with the sag of the curve) and how far past 90 degrees the ends of a curved sign can still be seen
        local arc = math.rad( math.abs( geo.curv ) * ARC_AT_FULL_CURVATURE )
        local sag = arc > 1e-4 and ( widthUnits / arc ) * ( 1 - math.cos( arc * 0.5 ) ) or 0

        geo.radius = 0.5 * math.sqrt( widthUnits * widthUnits + heightUnits * heightUnits ) + sag + 5
        geo.facingMargin = -math.sin( arc * 0.5 )

        store[config] = geo

        return geo
    end

    -- Strips of a curved sign at one level of detail: flat pieces tangent to a circular arc, each one cut by the plane that bisects it with its neighbors,
    -- so the pieces meet at a line without gaps or overlaps. The center of the sign stays where the flat sign was, the ends go back (positive
    -- curvature) or forward (negative). Returns false when the arc is so small that a flat sign is the same
    local function BuildLevel( geo, level )
        local curvature = geo.curv * level / LOD_LEVELS
        local arc = math.rad( math.abs( curvature ) * ARC_AT_FULL_CURVATURE )
        local count = math.Clamp( math.ceil( math.deg( arc ) / STRIP_ANGLE ), 1, MAX_STRIPS )

        if count <= 1 then return false end

        local right, normal = geo.ang:Forward(), geo.ang:Up()
        local scale = geo.scale
        local widthUnits = geo.w * scale
        local radius = widthUnits / arc
        local sign = curvature >= 0 and 1 or -1
        local arcStep = widthUnits / count -- arc length of one strip
        local halfChord = radius * math.tan( arc / count * 0.5 ) -- from the point where a strip touches the arc to the line where it meets the next one

        -- First the tangent point, the direction along the strip and the normal of every strip
        local points, tangents, bents = {}, {}, {}

        for i = 1, count do
            local phi = ( ( i - 0.5 ) * arcStep - widthUnits * 0.5 ) / radius -- angle from the center of the sign to the middle of the strip
            local sinPhi, cosPhi = math.sin( phi ), math.cos( phi )

            points[i] = geo.pos + right * ( widthUnits * 0.5 + radius * sinPhi ) - normal * ( sign * radius * ( 1 - cosPhi ) )
            tangents[i] = right * cosPhi - normal * ( sign * sinPhi )
            bents[i] = normal * cosPhi + right * ( sign * sinPhi )
        end

        -- Then, for every strip: where it starts, which part of the sign it shows, and the planes that cut it (none at the ends of the sign)
        local strips = {}
        local overlap = 0.03 -- units: every strip goes a little past its planes, so no crack shows between two of them

        for i = 1, count do
            local first, last = i == 1, i == count
            local before, after = first and arcStep * 0.5 or halfChord, last and arcStep * 0.5 or halfChord
            local start = points[i] - tangents[i] * before
            local strip = { pos = start, ang = tangents[i]:AngleEx( bents[i] ), u0 = ( ( i - 0.5 ) * arcStep - before ) / scale }

            if not first then
                local bisector = tangents[i - 1] + tangents[i]
                bisector:Normalize()

                strip.leftNormal, strip.leftPoint = bisector, start - bisector * overlap
            end

            if not last then
                local bisector = tangents[i] + tangents[i + 1]
                bisector:Normalize()

                strip.rightNormal, strip.rightPoint = -bisector, points[i] + tangents[i] * after + bisector * overlap
            end

            strips[i] = strip
        end

        return { strips = strips }
    end

    -- Everything one sign draws inside its 3D2D space (or inside every strip of a curved one): reads ctx
    local function DrawBody( c )
        local config, painted, w, h = c.config, c.painted, c.w, c.h
        local lr, lg, lb = c.lr, c.lg, c.lb
        local tr, tg, tb = c.tr, c.tg, c.tb
        local lineNumber, lines = c.lineNumber, c.lines

        if config.destinationSignShowBackground then
            local bg = config.destinationSignBackground
            surface.SetDrawColor( bg.r * lr, bg.g * lg, bg.b * lb, bg.a )
            surface.DrawRect( 0, 0, w, h )
        end

        -- Line number: fixed on the left, the destination uses the rest of the sign
        local areaX, areaW = 0, w

        if lineNumber ~= "" then
            surface.SetFont( c.lineFont )
            local lw, lh = surface.GetTextSize( lineNumber )
            local pad = config.destinationSignLinePadding
            local boxW = config.destinationSignLineWidth > 0 and config.destinationSignLineWidth or ( lw + pad * 2 )

            local lineColor = config.destinationSignLineColor

            if lineColor then
                surface.SetTextColor( lineColor.r * lr, lineColor.g * lg, lineColor.b * lb, lineColor.a )
            else
                surface.SetTextColor( tr * lr, tg * lg, tb * lb, 255 )
            end

            if painted then
                -- Painted: the number fills the height of the sign. Its width keeps the proportion of the letters (up to a third of the sign),
                -- or fills destinationSignLineWidth when it has one
                local lineLines = c.lineLines
                local sy, th = PaintedScaleY( lineLines, h )
                local inkW = lw - INK_SIDE * 2 * th
                local inkBoxW = config.destinationSignLineWidth > 0 and ( boxW - pad * 2 ) or math.min( inkW * sy, w * 0.33 )

                boxW = inkBoxW + pad * 2
                DrawPaintedLines( lineLines, boxW * 0.5, inkBoxW, h )
            else
                surface.SetTextPos( ( boxW - lw ) * 0.5, ( h - lh ) * 0.5 )
                surface.DrawText( lineNumber )
            end

            areaX, areaW = boxW, w - boxW
        end

        -- Destination: lines are separated by "|" and centered on the area
        surface.SetFont( c.textFont )
        surface.SetTextColor( tr * lr, tg * lg, tb * lb, 255 )

        if painted then
            if #lines > 0 then DrawPaintedLines( lines, areaX + areaW * 0.5, areaW, h ) end
        elseif #lines == 1 then
            local line = lines[1]
            local tw, th = surface.GetTextSize( line )
            local x

            if tw <= areaW - 20 then
                x = areaX + ( areaW - tw ) * 0.5
            else
                -- Marquee: the text scrolls from right to left
                local span = tw + areaW
                x = areaX + areaW - ( CurTime() * config.destinationSignMarqueeSpeed ) % span
            end

            -- Only draw the part of the text inside the area
            if x >= areaX and x + tw <= areaX + areaW then
                surface.SetTextPos( x, ( h - th ) * 0.5 )
                surface.DrawText( line )
            else
                local cx = x

                for _, code in utf8.codes( line ) do
                    local ch = utf8.char( code )
                    local cw = surface.GetTextSize( ch )

                    if cx >= areaX and cx + cw <= areaX + areaW then
                        surface.SetTextPos( cx, ( h - th ) * 0.5 )
                        surface.DrawText( ch )
                    end

                    cx = cx + cw
                end
            end
        elseif #lines > 1 then
            -- Several lines: all the same size, shrunk to fit the height and the widest line (no marquee)
            local _, th = surface.GetTextSize( "A" )
            local maxW = 0

            for _, line in ipairs( lines ) do
                local lw = surface.GetTextSize( line )
                maxW = math.max( maxW, lw )
            end

            local scale = math.min( 1, ( h * 0.9 ) / ( #lines * th ), ( areaW - 20 ) / maxW )
            local m = Matrix()
            m:Translate( Vector( areaX + areaW * 0.5, h * 0.5, 0 ) )
            m:Scale( Vector( scale, scale, 1 ) )

            cam.PushModelMatrix( m, true ) -- multiply: keep the 3D2D transform
                local top = -#lines * th * 0.5

                for i, line in ipairs( lines ) do
                    local tw = surface.GetTextSize( line )
                    surface.SetTextPos( -tw * 0.5, top + ( i - 1 ) * th )
                    surface.DrawText( line )
                end
            cam.PopModelMatrix()
        end

        -- Dot matrix look (only on the LED sign with a background: on a transparent sign the grid would float in the air)
        local grid = config.destinationSignGridSize
        local gridColor = config.destinationSignGridColor

        if config.destinationSignShowBackground and not painted and grid > 0 and gridColor.a > 0 then
            surface.SetDrawColor( gridColor )

            for gx = 0, w, grid do
                surface.DrawRect( gx, 0, 2, h )
            end

            for gy = 0, h, grid do
                surface.DrawRect( 0, gy, w, 2 )
            end
        end
    end

    -- Painted text is not a light source: the light that reaches the sign (map, sun and dynamic lights) darkens its colors, like a real paint
    local function SetPaintedLight( c, pos, normal )
        local light = render.ComputeLighting( pos, normal )

        -- The light is linear and the colors are not: ^ 1 / 2.2 gives the same brightness the engine shows on the models
        c.lr, c.lg, c.lb = math.min( light.x, 1 ) ^ 0.4545, math.min( light.y, 1 ) ^ 0.4545, math.min( light.z, 1 ) ^ 0.4545
    end

    -- Reused by every strip of a curved sign: no new objects per frame
    local stripMatrix, stripShift = Matrix(), Vector()

    -- eye and eyeForward: the position and the direction of the camera in the coordinates of the vehicle (calculated once for all its signs)
    local function DrawSign( vehicle, config, eye, eyeForward )
        if not config.destinationSign then return end

        local painted = config.destinationSignPainted

        -- The LED sign needs power. Painted text is always visible
        if not painted and config.destinationSignRequirePower and vehicle:GetEngineState() == 0 and vehicle:GetHeadlightState() == 0 then
            return
        end

        local text = vehicle:GetDestinationText() or ""
        local lineNumber = isfunction( vehicle.GetDestinationLine ) and vehicle:GetDestinationLine() or ""
        local content = config.destinationSignContent

        if content == "line" then
            text, lineNumber = lineNumber, "" -- the number uses the whole sign, like a destination
        elseif content == "text" then
            lineNumber = ""
        end

        if text == "" and lineNumber == "" then return end

        -- Too far: nothing. The last part of the distance fades out first, so it doesn't pop
        local drawDist = config.destinationSignDrawDistance
        local vehicleDist = eye:Length()

        if vehicleDist > drawDist then return end

        local geo = GetGeometry( vehicle, config )

        -- Seen from behind (3D2D is invisible there, the ends of a curved sign can still be seen a little past 90 degrees) or behind the camera: nothing
        local center, normal = geo.center, geo.normal
        local dx, dy, dz = eye.x - center.x, eye.y - center.y, eye.z - center.z
        local dist = math.sqrt( dx * dx + dy * dy + dz * dz )

        if dx * normal.x + dy * normal.y + dz * normal.z <= geo.facingMargin * dist then return end
        if -( dx * eyeForward.x + dy * eyeForward.y + dz * eyeForward.z ) < -geo.radius then return end

        -- Lines of the text, parsed again only when the text changes
        if geo.textSource ~= text then
            geo.textSource = text
            geo.lines = ParseLines( text )
        end

        if geo.lineSource ~= lineNumber then
            geo.lineSource = lineNumber
            geo.lineLines = { lineNumber }
        end

        -- Text color: the one picked in Edit Properties, or the config color if none was picked (0, 0, 0)
        local textColor = painted and config.destinationSignPaintedColor or config.destinationSignColor
        local tr, tg, tb = textColor.r, textColor.g, textColor.b

        if isfunction( vehicle.GetDestinationColor ) then
            local picked = vehicle:GetDestinationColor()

            if picked.x > 0 or picked.y > 0 or picked.z > 0 then
                tr, tg, tb = picked.x * 255, picked.y * 255, picked.z * 255
            end
        end

        ctx.config, ctx.painted, ctx.w, ctx.h = config, painted, geo.w, geo.h
        ctx.tr, ctx.tg, ctx.tb = tr, tg, tb
        ctx.lr, ctx.lg, ctx.lb = 1, 1, 1
        ctx.lineNumber, ctx.lines, ctx.lineLines = lineNumber, geo.lines, geo.lineLines
        ctx.textFont = painted and config.destinationSignPaintedFont or config.destinationSignFont
        ctx.lineFont = painted and config.destinationSignPaintedFont or config.destinationSignLineFont

        -- The curve fades out with the distance (full up to LOD_NEAR, flat from LOD_FAR) in LOD_LEVELS steps, so it never pops and far signs are cheap
        local level = 0

        if geo.curv ~= 0 then
            local t = math.Clamp( ( dist - LOD_NEAR ) / ( LOD_FAR - LOD_NEAR ), 0, 1 )
            level = math.floor( ( 1 - t * t * ( 3 - 2 * t ) ) * LOD_LEVELS + 0.5 )
        end

        local curve

        if level > 0 then
            curve = geo.levels[level]

            if curve == nil then
                curve = BuildLevel( geo, level )
                geo.levels[level] = curve
            end
        end

        local fadeStart = drawDist * ( 1 - FADE_FRACTION )

        if vehicleDist > fadeStart then surface.SetAlphaMultiplier( ( drawDist - vehicleDist ) / ( drawDist - fadeStart ) ) end

        if curve then
            local oldClipping = render.EnableClipping( true )
            local scale, strips = geo.scale, curve.strips
            local vehicleAngles = vehicle:GetAngles()

            for i = 1, #strips do
                local strip = strips[i]
                local pos = vehicle:LocalToWorld( strip.pos )
                local ang = vehicle:LocalToWorldAngles( strip.ang )
                local planes = 0

                if painted then SetPaintedLight( ctx, pos, ang:Up() ) end

                -- Each strip only draws between the planes that bisect it with the strips next to it
                if strip.leftNormal then
                    local planeNormal = Vector( strip.leftNormal )
                    planeNormal:Rotate( vehicleAngles )

                    render.PushCustomClipPlane( planeNormal, planeNormal:Dot( vehicle:LocalToWorld( strip.leftPoint ) ) )
                    planes = planes + 1
                end

                if strip.rightNormal then
                    local planeNormal = Vector( strip.rightNormal )
                    planeNormal:Rotate( vehicleAngles )

                    render.PushCustomClipPlane( planeNormal, planeNormal:Dot( vehicle:LocalToWorld( strip.rightPoint ) ) )
                    planes = planes + 1
                end

                cam.Start3D2D( pos, ang, scale )
                    stripShift.x = -strip.u0
                    stripMatrix:Identity()
                    stripMatrix:SetTranslation( stripShift )

                    cam.PushModelMatrix( stripMatrix, true )
                        DrawBody( ctx )
                    cam.PopModelMatrix()
                cam.End3D2D()

                for _ = 1, planes do
                    render.PopCustomClipPlane()
                end
            end

            render.EnableClipping( oldClipping )
        else
            local pos = vehicle:LocalToWorld( config.destinationSignPos )
            local ang = vehicle:LocalToWorldAngles( config.destinationSignAng )

            if painted then SetPaintedLight( ctx, pos, ang:Up() ) end

            cam.Start3D2D( pos, ang, geo.scale )
                DrawBody( ctx )
            cam.End3D2D()
        end

        if vehicleDist > fadeStart then surface.SetAlphaMultiplier( 1 ) end
    end

    function BlackterioExtraFunctions:DrawDestinationSign( vehicle, config )
        -- destinationSign = true on the base config turns the feature on (a variant can then hide a sign with destinationSign = false)
        if not config.destinationSign or not isfunction( vehicle.GetDestinationText ) then return end

        -- The camera in the coordinates of the vehicle, once for all its signs
        local eye = vehicle:WorldToLocal( EyePos() )
        local eyeForward = vehicle:WorldToLocalAngles( EyeAngles() ):Forward()
        local signs = config.destinationSigns

        if signs and #signs > 0 then
            for i = 1, #signs do
                local sign = signs[i]
                DrawSign( vehicle, ResolveSign( vehicle, config, sign, sign.id or i ), eye, eyeForward )
            end
        else
            DrawSign( vehicle, ResolveSign( vehicle, config, nil, "main" ), eye, eyeForward )
        end
    end
end

-- Helper function to make custom configurations
function BlackterioExtraFunctions:CreateConfig( customConfig )
    local config = table.Copy( self.DefaultConfig )

    if customConfig then
        for k, v in pairs( customConfig ) do
            if type( v ) == "table" and type( config[k] ) == "table" then
                for k2, v2 in pairs( v ) do
                    config[k][k2] = v2
                end
            else
                config[k] = v
            end
        end
    end

    return config
end

-- Adds the network vars the extra functions read, with the same "Edit Properties" entries on every vehicle.
-- Call it from ENT:SetupDataTables, after BaseClass.SetupDataTables( self ). Pass the keys you need:
--   destinationText = true  -> ENT:GetDestinationText / SetDestinationText (String, for the destination sign)
--                              and ENT:GetDestinationColor / SetDestinationColor (Vector 0-1, text color, always added with it)
--   speedLimit = true       -> ENT:GetSpeedLimit / SetSpeedLimit (Int, km/h as the Glide HUD shows them, 0 = no limit, for the speed limiter)
--   destinationLine = true  -> ENT:GetDestinationLine / SetDestinationLine (String, line number shown fixed at the left of the destination sign)
-- `category` is the Edit Properties category and `order` the position of the first entry (the next one uses order + 1).
function BlackterioExtraFunctions:AddEditableVars( vehicle, options )
    options = options or {}

    local category = options.category or "Extra Functions"
    local order = options.order or 201

    if options.destinationText then
        vehicle:NetworkVar( "String", "DestinationText", { KeyName = "destinationtext", Edit = { type = "Generic", order = order, waitforenter = true, category = category } } )

        -- Always editable with the destination sign. (0, 0, 0) = none picked: the sign uses config.destinationSignColor
        vehicle:NetworkVar( "Vector", "DestinationColor", { KeyName = "destinationcolor", Edit = { type = "VectorColor", order = order + 3, category = category } } )
    end

    if options.speedLimit then
        vehicle:NetworkVar( "Int", "SpeedLimit", { KeyName = "speedlimit", Edit = { type = "Int", order = order + 1, min = 0, max = options.speedLimitMax or 500, category = category } } )
    end

    if options.destinationLine then
        vehicle:NetworkVar( "String", "DestinationLine", { KeyName = "destinationline", Edit = { type = "Generic", order = order + 2, waitforenter = true, category = category } } )
    end
end
