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
local VERSION = 3

if BlackterioExtraFunctions and ( BlackterioExtraFunctions._version or 0 ) >= VERSION then return end

BlackterioExtraFunctions = BlackterioExtraFunctions or {}
BlackterioExtraFunctions._version = VERSION

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

    -- Digital Speedometer configuration
    digitalSpeedoPos = Vector(0, 0, 0), -- Text position in vehicle
    digitalSpeedoAng = Angle(0, 0, 0), -- Text angle
    digitalSpeedoScale = 0.05, -- Text scale
    digitalSpeedoFont = "BlackterioDefaultDigitalSpeedo", -- Text font (custom fonts must be created by the vehicle author with surface.CreateFont)
    digitalSpeedoColor = Color(255, 255, 255), -- Text color
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
    gearLeverMode = "tap",
    gearLeverBone = "gearlever",
    gearLeverAxis = 3,
    gearLeverAngle = 20,
    gearLeverSign = 1,
    gearLeverHold = 0.25,
    gearLeverLerpRate = 0.35,
    gearLeverPositions = {},

    -- Destination sign (3D2D). Needs the DestinationText network var: see BlackterioExtraFunctions:AddEditableVars
    destinationSignPos = Vector(0, 0, 0), -- Top left corner of the sign, seen from the front
    destinationSignAng = Angle(0, 90, 90),
    destinationSignScale = 0.05,
    destinationSignWidth = 716, -- Size in sign pixels (width * scale = units)
    destinationSignHeight = 100,
    destinationSignFont = "BlackterioDefaultDestinationSign", -- Custom fonts must be created by the vehicle author with surface.CreateFont
    destinationSignColor = Color(255, 160, 20),
    destinationSignBackground = Color(8, 6, 2, 255),
    destinationSignGridColor = Color(0, 0, 0, 150), -- Dot matrix look. Alpha 0 or destinationSignGridSize 0 = no grid
    destinationSignGridSize = 6,
    destinationSignMarqueeSpeed = 120, -- Pixels per second when the text doesn't fit
    destinationSignDrawDistance = 3000,
    destinationSignRequirePower = true, -- Only lit with the engine on or the headlights on

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
    surface.CreateFont("BlackterioDefaultDigitalSpeedo", {
        font = "Tahoma",
        size = 20,
        weight = 700,
        antialias = true,
    })

    surface.CreateFont("BlackterioDefaultDestinationSign", {
        font = "Consolas",
        size = 78,
        weight = 900,
        antialias = false,
    })
end

-- Frame-rate independent Lerp helper.
-- `rate` keeps the same feel the old per-frame fractions had at 60 FPS,
-- but the result no longer depends on the client's frame rate.
local function FrameLerp(rate, from, to)
    if rate >= 1 then return to end
    if rate <= 0 then return from end
    return Lerp(1 - (1 - rate) ^ (FrameTime() * 60), from, to)
end

--[[
    Engine states (Glide): 0 = off, 1 = starting, 2 = running, 3 = shutting down.
    Electric gauges (fuel, temp, battery, wipers, ignition key) only react on
    states 1-2: state 3 means the ignition was cut, so needles drop and wipers
    park, like turning the key off in a real car. The oil pressure gauge stays
    up on states 2-3 instead, since pressure exists while the engine spins.
]]
local function AreElectricsOn(vehicle)
    local state = vehicle:GetEngineState()
    return state == 1 or state == 2
end

-- Main function to update anims
function BlackterioExtraFunctions:UpdateAnimations(vehicle, config)
    if not IsValid(vehicle) then return end

    -- Use default configuration if a custom one isn't specified
    config = config or self.DefaultConfig

    -- Call the base class' animations first.
    -- `config.baseClass` (a class name string) resolves the base explicitly
    -- for vehicles that derive from another extra-functions vehicle; the
    -- re-entrancy guard prevents an infinite BaseClass recursion (it turns
    -- a would-be stack overflow into a harmless skipped call).
    if not vehicle.befInBaseUpdate then
        local base = config.baseClass and baseclass.Get(config.baseClass) or vehicle.BaseClass
        if base and base.OnUpdateAnimations then
            vehicle.befInBaseUpdate = true
            base.OnUpdateAnimations(vehicle)
            vehicle.befInBaseUpdate = false
        end
    end

    -- Update pedals anim
    if config.pedals then
        self:UpdatePedals(vehicle, config)
    end

    -- Update clutch anim
    if config.clutch then
        self:UpdateClutch(vehicle, config)
    end

    -- Update speedometer and tachometer anims
    if config.speedo or config.tacho then
        self:UpdateGauges(vehicle, config)
    end

    -- Update fuel anim
    if config.fuel then
        self:UpdateFuel(vehicle, config)
    end

    -- Update wipers anim
    if config.wipers then
        self:UpdateWipers(vehicle, config)
    end

    -- Update oil anim
    if config.oil then
        self:UpdateOil(vehicle, config)
    end

    -- Update temperature anim
    if config.temp then
        self:UpdateTemp(vehicle, config)
    end

    -- Update battery anim
    if config.battery then
        self:UpdateBattery(vehicle, config)
    end

    -- Update ignition key anim
    if config.ignitionKey then
        self:UpdateIgnitionKey(vehicle, config)
    end

    -- Update light switch anim
    if config.lightSwitch then
        self:UpdateLightSwitch(vehicle, config)
    end

    -- Update wiper switch anim
    if config.wiperSwitch then
        self:UpdateWiperSwitch(vehicle, config)
    end

    -- Update handbrake lever anim
    if config.handbrake then
        self:UpdateHandbrake(vehicle, config)
    end

    -- Update horn button anim
    if config.horn then
        self:UpdateHorn(vehicle, config)
    end

    -- Update turn signal stalk anim
    if config.turnStalk then
        self:UpdateTurnStalk(vehicle, config)
    end

    -- Update gear lever anim
    if config.gearLever then
        self:UpdateGearLever(vehicle, config)
    end

    -- Update engine anims (belts, fan...)
    if config.engineAnims then
        self:UpdateEngineAnims(vehicle, config)
    end

    -- Invalidate bone cache. This is NOT redundant with the base class call:
    -- our pose parameters were written AFTER the base already invalidated.
    vehicle:InvalidateBoneCache()
end

-- Pedals
function BlackterioExtraFunctions:UpdatePedals(vehicle, config)
    if not vehicle.befGas then
        vehicle.befGas = 0
        vehicle.befBrake = 0
    end

    -- Update accelerator
    vehicle.befGas = FrameLerp(config.pedalLerpRate, vehicle.befGas, vehicle:GetEngineThrottle())

    -- Update brake
    if vehicle:IsBraking() then
        if vehicle:GetEngineState() <= 1 then
            vehicle.befBrake = FrameLerp(config.pedalLerpRate, vehicle.befBrake, 0)
        else
            vehicle.befBrake = FrameLerp(config.pedalLerpRate, vehicle.befBrake, vehicle:GetBrakePower())
        end
    else
        vehicle.befBrake = FrameLerp(config.pedalLerpRate, vehicle.befBrake, 0)
    end

    vehicle:SetPoseParameter(config.poseParameters.gas, vehicle.befGas)
    vehicle:SetPoseParameter(config.poseParameters.brake, vehicle.befBrake)
end

-- Clutch
function BlackterioExtraFunctions:UpdateClutch(vehicle, config)
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
        vehicle.befClutch = Lerp(math.min(elapsed / duration, 1), vehicle.befClutchStart, vehicle.befTargetClutch)

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

        vehicle:SetPoseParameter(config.poseParameters.clutch, vehicle.befClutch)
    end
end

-- Speedometer and tachometer
function BlackterioExtraFunctions:UpdateGauges(vehicle, config)
    if not vehicle.befGauge then
        vehicle.befGauge = 0
        vehicle.befSpeed = 0
        vehicle.befRpm = 0
    end

    -- Update RPM
    if config.tacho then
        local tachoRate = config.tachoLerpRate or 0.15
        if vehicle:GetEngineState() > 0 then
            vehicle.befRpm = FrameLerp(tachoRate, vehicle.befRpm, vehicle:GetEngineRPM() / vehicle:GetMaxRPM() - config.rpmCalibration)
        else
            vehicle.befRpm = FrameLerp(tachoRate, vehicle.befRpm, 0)
        end
        vehicle:SetPoseParameter(config.poseParameters.tacho, vehicle.befRpm)
    end

    -- Update Speedometer
    -- Longitudinal speed via dot product: same value the old
    -- WorldToLocal(velocity + pos).x gave, without allocating vectors.
    if config.speedo then
        vehicle.befSpeed = vehicle:GetVelocity():Dot(vehicle:GetForward()) * 0.03
        vehicle.befGauge = vehicle.befSpeed / config.speedCalibration * config.speedMultiplier
        vehicle:SetPoseParameter(config.poseParameters.speedo, vehicle.befGauge)
    end
end

-- Oil
function BlackterioExtraFunctions:UpdateOil(vehicle, config)
    if not vehicle.befOil then
        vehicle.befOil = 0
    end

    local targetOil = 0

    -- Oil pressure gauge: active while the engine spins (states 2 and 3)
    if vehicle:GetEngineState() > 1 then
        local rpmFraction = vehicle:GetEngineRPM() / vehicle:GetMaxRPM()
        local a, b = config.oilMinValue, config.oilMaxValue
        -- Normalized clamp bounds so inverted gauges (min > max) also work
        targetOil = math.Clamp(a + rpmFraction * (b - a), math.min(a, b), math.max(a, b))
    end

    vehicle.befOil = FrameLerp(config.oilLerpRate, vehicle.befOil, targetOil)
    vehicle:SetPoseParameter(config.poseParameters.oil, vehicle.befOil)
end

-- Temperature
function BlackterioExtraFunctions:UpdateTemp(vehicle, config)
    if not vehicle.befTemp then
        vehicle.befTemp = 0
    end

    if AreElectricsOn(vehicle) then
        vehicle.befTemp = FrameLerp(config.tempLerpRate, vehicle.befTemp, config.tempMaxValue)
    else
        vehicle.befTemp = FrameLerp(config.tempLerpRate, vehicle.befTemp, 0)
    end

    vehicle:SetPoseParameter(config.poseParameters.temp, vehicle.befTemp)
end

-- Battery
function BlackterioExtraFunctions:UpdateBattery(vehicle, config)
    if not vehicle.befBattery then
        vehicle.befBattery = 0
    end

    if AreElectricsOn(vehicle) then
        vehicle.befBattery = FrameLerp(config.batteryLerpRate, vehicle.befBattery, config.batteryMaxValue)
    else
        vehicle.befBattery = FrameLerp(config.batteryLerpRate, vehicle.befBattery, 0)
    end

    vehicle:SetPoseParameter(config.poseParameters.battery, vehicle.befBattery)
end

-- Fuel
function BlackterioExtraFunctions:UpdateFuel(vehicle, config)
    if not vehicle.befFuel then
        vehicle.befFuel = 0
        vehicle.befFuelTarget = 0
        vehicle.befFuelNextRead = 0
    end

    if AreElectricsOn(vehicle) then
        -- Fuel System addon presence is checked on every read tick (cheap),
        -- so it still works if that addon happens to load after us.
        if GlideFuelSystem ~= nil and isfunction(GlideFuelSystem.GetFuel) then
            -- Throttle reads to every 0.25s (matches GlideFuelSystem consumption tick).
            -- Each frame only does a Lerp; NW2 reads happen at most 4x/second.
            local now = CurTime()
            if now >= vehicle.befFuelNextRead then
                vehicle.befFuelNextRead = now + 0.25

                -- Read NW2 floats directly, bypassing ResolveVehicle / IsFuelSystemDisabled overhead.
                local current = vehicle:GetNW2Float("glide_fuel_system_value", -1)
                if current >= 0 then
                    local max = vehicle:GetNW2Float("glide_fuel_system_forced_max", -1)
                    if max <= 0 then max = vehicle:GetNW2Float("glide_fuel_system_max", -1) end
                    if max <= 0 then max = GlideFuelSystem.DefaultTankSize or 0 end

                    if max > 0 then
                        vehicle.befFuelTarget = math.Clamp(current / max, 0, 1)
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

    vehicle.befFuel = FrameLerp(config.fuelLerpRate, vehicle.befFuel, vehicle.befFuelTarget)
    vehicle:SetPoseParameter(config.poseParameters.fuel, vehicle.befFuel)
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

    vehicle:SetPoseParameter(config.poseParameters.wipers1, value)
    vehicle:SetPoseParameter(config.poseParameters.wipers2, value)
    vehicle:SetPoseParameter(config.poseParameters.wipers3, value)
    vehicle:SetPoseParameter(config.poseParameters.wipers4, value)
end

-- Wipers
function BlackterioExtraFunctions:UpdateWipers(vehicle, config)
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
    local engineOn   = AreElectricsOn(vehicle) -- state 3 (shutting down) parks the wipers

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
        vehicle.befWipers = math.sin((CurTime() - vehicle.befOldWipers) / config.wiperSpeed)
    else
        if vehicle.befWipersActive then
            local sinVal = math.sin((CurTime() - vehicle.befOldWipers) / config.wiperSpeed)
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
            if prev == nil or ( prev < 0 and cur > 0 ) then
                if soundEnabled then
                    local snd = ResolveWiperSound( config, "wiperStartCycleSound", self.DefaultConfig )
                    if snd then vehicle:EmitSound( snd ) end
                end
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
function BlackterioExtraFunctions:UpdateIgnitionKey(vehicle, config)
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

    vehicle.befIgnitionKey = FrameLerp(config.ignitionLerpRate, vehicle.befIgnitionKey, targetKeyPosition)
    vehicle:SetPoseParameter(config.poseParameters.ignitionKey, vehicle.befIgnitionKey)
end

-- Light Switch Animation
function BlackterioExtraFunctions:UpdateLightSwitch(vehicle, config)
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

    vehicle.befLightSwitch = FrameLerp(config.lightSwitchLerpRate, vehicle.befLightSwitch, targetSwitchPosition)
    vehicle:SetPoseParameter(config.poseParameters.lightSwitch, vehicle.befLightSwitch)
end

-- Wiper Switch Animation
function BlackterioExtraFunctions:UpdateWiperSwitch(vehicle, config)
    self:_EnsureWeatherChecked()

    if not vehicle.befWiperSwitch then
        vehicle.befWiperSwitch = 0
    end

    local useManualMode = vehicle:GetNW2Bool( "blackterio_wipers_manual_mode", false )
    local manualOn      = vehicle:GetNW2Bool( "blackterio_wipers_on", false )
    local engineOn      = AreElectricsOn(vehicle)
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
    vehicle.befWiperSwitch = FrameLerp(config.wiperSwitchLerpRate, vehicle.befWiperSwitch, targetSwitchPosition)
    vehicle:SetPoseParameter(config.poseParameters.wiperSwitch, vehicle.befWiperSwitch)
end

-- Handbrake lever
-- The state comes from the "blackterio_handbrake" NW2Int, published by the server
-- (Blackterio_Vehicle_Controls.lua): counter * 2 + state, 1 = applied. The counter
-- changes on every press and release, so clients can tell when to play the sounds.
function BlackterioExtraFunctions:UpdateHandbrake(vehicle, config)
    if not vehicle.befHandbrake then
        vehicle.befHandbrake = 0
    end

    local nw = vehicle:GetNW2Int("blackterio_handbrake", 0)
    local applied = nw % 2 == 1

    vehicle.befHandbrake = FrameLerp(config.handbrakeLerpRate, vehicle.befHandbrake, applied and 1 or 0)
    vehicle:SetPoseParameter(config.poseParameters.handbrake, vehicle.befHandbrake)

    -- Cabin sounds, only heard from the inside. The first read is only a baseline
    local last = vehicle.befHandbrakeSeen
    vehicle.befHandbrakeSeen = nw

    if CLIENT and last ~= nil and nw ~= last and vehicle.isLocalPlayerInFirstPerson then
        local onSound, offSound = config.handbrakeOnSound, config.handbrakeOffSound
        local snd = applied and onSound or offSound

        if snd and snd ~= "" then
            local other = applied and offSound or onSound
            if other and other ~= "" then vehicle:StopSound(other) end

            vehicle:EmitSound(snd, 70, 100, 1, CHAN_AUTO)
        end
    end
end

-- Horn button
function BlackterioExtraFunctions:UpdateHorn(vehicle, config)
    if not vehicle.befHorn then
        vehicle.befHorn = 0
    end

    vehicle.befHorn = FrameLerp(config.hornLerpRate, vehicle.befHorn, vehicle:GetIsHonking() and 1 or 0)
    vehicle:SetPoseParameter(config.poseParameters.horn, vehicle.befHorn)
end

-- Turn signal stalk: 1 = left signal, 2 = right signal, 3 = hazards (leave it centered)
function BlackterioExtraFunctions:UpdateTurnStalk(vehicle, config)
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

    vehicle.befTurnStalk = FrameLerp(config.turnStalkLerpRate, vehicle.befTurnStalk, target)
    vehicle:SetPoseParameter(config.poseParameters.turnStalk, vehicle.befTurnStalk)
end

-- Gear lever (bone or pose parameter, "tap" or "position" mode)
local leverAng = Angle()

function BlackterioExtraFunctions:UpdateGearLever(vehicle, config)
    local boneName = config.gearLeverBone
    local useBone = boneName ~= nil and boneName ~= ""

    if useBone and (vehicle.befLeverBone == nil or vehicle.befLeverModel ~= vehicle:GetModel()) then
        vehicle.befLeverBone = vehicle:LookupBone(boneName) or false
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

        if (vehicle.befLeverTap or 0) ~= 0 and CurTime() > (vehicle.befLeverHoldUntil or 0) then
            vehicle.befLeverTap = 0
        end

        target = (vehicle.befLeverTap or 0) * config.gearLeverSign * (useBone and config.gearLeverAngle or 1)
    end

    vehicle.befLever = FrameLerp(config.gearLeverLerpRate, vehicle.befLever or 0, target)

    if useBone then
        leverAng[1], leverAng[2], leverAng[3] = 0, 0, 0
        leverAng[config.gearLeverAxis] = vehicle.befLever
        vehicle:ManipulateBoneAngles(vehicle.befLeverBone, leverAng)
    else
        vehicle:SetPoseParameter(config.poseParameters.gearLever, vehicle.befLever)
    end
end

-- Engine animations: each entry is a looping pose parameter (0 to 1) that advances
-- with the engine RPM. `speed` = cycles per engine revolution (keep it low, a real
-- belt pattern would look strobed)
function BlackterioExtraFunctions:UpdateEngineAnims(vehicle, config)
    local anims = config.engineAnims
    if type(anims) ~= "table" then return end

    local phases = vehicle.befEnginePhases

    if not phases then
        phases = {}
        vehicle.befEnginePhases = phases
    end

    local rpm = vehicle:GetEngineState() > 0 and vehicle:GetEngineRPM() or 0

    for i, anim in ipairs(anims) do
        local phase = phases[i] or 0

        if rpm > 0 then
            phase = (phase + rpm / 60 * (anim.speed or 0.25) * FrameTime()) % 1
            phases[i] = phase
        end

        vehicle:SetPoseParameter(anim.pose, phase)
    end
end

-- Digital Speedometer (CLIENT ONLY)
if CLIENT then
    function BlackterioExtraFunctions:DrawDigitalSpeedometer(vehicle, config)
        -- Check if engine state requirement is met
        if config.digitalSpeedoRequireEngine and (not vehicle:GetEngineState() or vehicle:GetEngineState() == 0) then
            return
        end

        -- Calculate speed based on unit
        local speedMultiplier = config.digitalSpeedoUnit == "MPH" and 0.04261363636 or 0.06858
		-- MPH and KMH values from: https://github.com/wiremod/wire/blob/master/lua/entities/gmod_wire_speedometer.lua
        -- Longitudinal speed only: falling or sliding sideways shouldn't
        -- register on the speedometer.
        local speed = math.floor(math.abs(vehicle:GetVelocity():Dot(vehicle:GetForward())) * speedMultiplier)
        local unitText = config.digitalSpeedoUnit == "MPH" and "MPH" or "KM/H"

        -- Custom fonts (digitalSpeedoFont) must be created by the vehicle
        -- author with surface.CreateFont before this is drawn.

        -- Calculate position and angle
        local pos = vehicle:LocalToWorld(config.digitalSpeedoPos)
        local ang = vehicle:LocalToWorldAngles(config.digitalSpeedoAng)

        -- Draw 3D2D speedometer
        cam.Start3D2D(pos, ang, config.digitalSpeedoScale)
            local displayText = config.digitalSpeedoShowUnit and (speed .. " " .. unitText) or tostring(speed)
            draw.SimpleText(displayText, config.digitalSpeedoFont, 0, 0, config.digitalSpeedoColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end

-- Destination sign (CLIENT ONLY): LED panel with the text of the vehicle's DestinationText network var
if CLIENT then
    function BlackterioExtraFunctions:DrawDestinationSign(vehicle, config)
        if not config.destinationSign or not isfunction(vehicle.GetDestinationText) then return end

        if config.destinationSignRequirePower and vehicle:GetEngineState() == 0 and vehicle:GetHeadlightState() == 0 then
            return
        end

        local text = vehicle:GetDestinationText()
        if not text or text == "" then return end

        local drawDist = config.destinationSignDrawDistance
        if EyePos():DistToSqr(vehicle:GetPos()) > drawDist * drawDist then return end

        local w, h = config.destinationSignWidth, config.destinationSignHeight
        local pos = vehicle:LocalToWorld(config.destinationSignPos)
        local ang = vehicle:LocalToWorldAngles(config.destinationSignAng)

        cam.Start3D2D(pos, ang, config.destinationSignScale)
            surface.SetDrawColor(config.destinationSignBackground)
            surface.DrawRect(0, 0, w, h)

            surface.SetFont(config.destinationSignFont)
            local tw, th = surface.GetTextSize(text)
            local x

            if tw <= w - 20 then
                x = (w - tw) * 0.5
            else
                -- Marquee: the text scrolls from right to left
                local span = tw + w
                x = w - (CurTime() * config.destinationSignMarqueeSpeed) % span
            end

            surface.SetTextColor(config.destinationSignColor)
            surface.SetTextPos(x, (h - th) * 0.5)

            -- Only draw the part of the text inside the sign
            if x >= 0 and x + tw <= w then
                surface.DrawText(text)
            else
                local cx = x

                for _, c in utf8.codes(text) do
                    local ch = utf8.char(c)
                    local cw = surface.GetTextSize(ch)

                    if cx >= 0 and cx + cw <= w then
                        surface.SetTextPos(cx, (h - th) * 0.5)
                        surface.DrawText(ch)
                    end

                    cx = cx + cw
                end
            end

            -- Dot matrix look
            local grid = config.destinationSignGridSize
            local gridColor = config.destinationSignGridColor

            if grid > 0 and gridColor.a > 0 then
                surface.SetDrawColor(gridColor)

                for gx = 0, w, grid do
                    surface.DrawRect(gx, 0, 2, h)
                end

                for gy = 0, h, grid do
                    surface.DrawRect(0, gy, w, 2)
                end
            end
        cam.End3D2D()
    end
end

-- Helper function to make custom configurations
function BlackterioExtraFunctions:CreateConfig(customConfig)
    local config = table.Copy(self.DefaultConfig)

    if customConfig then
        for k, v in pairs(customConfig) do
            if type(v) == "table" and type(config[k]) == "table" then
                for k2, v2 in pairs(v) do
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
--   speedLimit = true       -> ENT:GetSpeedLimit / SetSpeedLimit (Int, km/h as the Glide HUD shows them, 0 = no limit, for the speed limiter)
-- `category` is the Edit Properties category and `order` the position of the first entry (the next one uses order + 1).
function BlackterioExtraFunctions:AddEditableVars(vehicle, options)
    options = options or {}

    local category = options.category or "Extra Functions"
    local order = options.order or 201

    if options.destinationText then
        vehicle:NetworkVar("String", "DestinationText", { KeyName = "destinationtext", Edit = { type = "Generic", order = order, waitforenter = true, category = category } })
    end

    if options.speedLimit then
        vehicle:NetworkVar("Int", "SpeedLimit", { KeyName = "speedlimit", Edit = { type = "Int", order = order + 1, min = 0, max = options.speedLimitMax or 500, category = category } })
    end
end
