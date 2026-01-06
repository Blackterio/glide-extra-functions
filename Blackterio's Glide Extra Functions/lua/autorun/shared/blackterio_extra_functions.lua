-- ============================================
-- Extra animations for Glide vehicles
-- lua/autorun/shared/blackterio_extra_functions.lua
-- ============================================


if CLIENT then

    BlackterioExtraFunctions = BlackterioExtraFunctions or {}
 --[[  For debug purposes 
    print("=============================================================================")
    print("||[BlackterioExtraFunctions] Extra functions succesfully loaded client-side||")
    print("=============================================================================") 	
	]]
end

if SERVER then

    BlackterioExtraFunctions = BlackterioExtraFunctions or {}
    
 --[[  For debug purposes 
    print("=============================================================================")
    print("||[BlackterioExtraFunctions] Extra functions succesfully loaded server-side||")
    print("=============================================================================") 
	]]
end

 
BlackterioExtraFunctions = BlackterioExtraFunctions or {}

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
    
    -- Pedals lerp
    pedalLerpRate = 0.2,
    
    -- Clutch Duration (lerp)
    clutchDuration = 0.4,
    
    -- RPM Calibration
    rpmCalibration = 0.15,
	
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
    
    -- Switch lerp rates
    ignitionLerpRate = 0.2,  
    lightSwitchLerpRate = 0.2, 
    wiperSwitchLerpRate = 0.2,
    
    -- Digital Speedometer configuration
    digitalSpeedoPos = Vector(0, 0, 0), -- Text position in vehicle
    digitalSpeedoAng = Angle(0, 0, 0), -- Text angle
    digitalSpeedoScale = 0.05, -- Text scale
    digitalSpeedoFont = "BlackterioDefaultDigitalSpeedo", -- Text font
    digitalSpeedoColor = Color(255, 255, 255), -- Text color
    digitalSpeedoUnit = "KMH", -- "KMH" or "MPH", conversions are automatic
    digitalSpeedoShowUnit = false, -- Show speed unit
    digitalSpeedoRequireEngine = true, -- Only show when engine is on
     
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
        wiperSwitch = "wiperswitch"      
    }
}

-- Create default font for digital speedometer (CLIENT ONLY)
if CLIENT then
    surface.CreateFont("BlackterioDefaultDigitalSpeedo", {
        font = "Tahoma",
        size = 20, 
        weight = 700,
        antialias = true,
    })
end

-- Main function to update anims
function BlackterioExtraFunctions:UpdateAnimations(vehicle, config)
    if not IsValid(vehicle) then return end
    
    -- Use default configuration if a custom one isn't specified
    config = config or self.DefaultConfig
    
    -- Call base function
    if vehicle.BaseClass and vehicle.BaseClass.OnUpdateAnimations then
        vehicle.BaseClass.OnUpdateAnimations(vehicle)
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
    
    -- Invalidate bone cache
    vehicle:InvalidateBoneCache()
end

-- Pedals
function BlackterioExtraFunctions:UpdatePedals(vehicle, config)
    if not vehicle.gas then
        vehicle.gas = 0
        vehicle.brake = 0
    end
    
    -- Update accelerator
    vehicle.gas = Lerp(config.pedalLerpRate, vehicle.gas, vehicle:GetEngineThrottle())
    
    -- Update brake
    if vehicle:IsBraking() and vehicle:GetEngineState() <=1 then
        vehicle.brake = Lerp(config.pedalLerpRate, vehicle.brake, 0)
    else if vehicle:IsBraking() then
         vehicle.brake = Lerp(config.pedalLerpRate, vehicle.brake, vehicle:GetBrakePower() / vehicle.GetBrakePower())
	else 
        vehicle.brake = Lerp(config.pedalLerpRate, vehicle.brake, 0)
    end
    end

    vehicle:SetPoseParameter(config.poseParameters.gas, vehicle.gas)
    vehicle:SetPoseParameter(config.poseParameters.brake, vehicle.brake)
end

-- Clutch
function BlackterioExtraFunctions:UpdateClutch(vehicle, config)
    local gear = vehicle:GetGear()
    
    if gear ~= vehicle.prevGear then
        vehicle.targetClutch = 1
        vehicle.clutchLerpStart = CurTime()
        vehicle.clutchReturning = false
        vehicle.prevGear = gear
    end
    
    if vehicle.targetClutch then
        local elapsed = CurTime() - vehicle.clutchLerpStart
        local duration = config.clutchDuration
        vehicle.clutch1 = Lerp(math.min(elapsed / duration, 1), vehicle.clutch1 or 0, vehicle.targetClutch)
        
        if elapsed >= duration then
            if not vehicle.clutchReturning then
                vehicle.clutchReturning = true
                vehicle.targetClutch = 0
                vehicle.clutchLerpStart = CurTime()
            else
                vehicle.targetClutch = nil
                vehicle.clutchReturning = false
            end
        end
        
        vehicle:SetPoseParameter(config.poseParameters.clutch, vehicle.clutch1)
    end
end

-- Speedometer and tachometer
function BlackterioExtraFunctions:UpdateGauges(vehicle, config)
    if not vehicle.gauge then
        vehicle.gauge = 0
    end
    if not vehicle.speed then
        vehicle.speed = 0
    end
    if not vehicle.rpm then
        vehicle.rpm = 0
    end
    
    -- Update RPM
    if config.tacho then
        if vehicle:GetEngineState() then
            vehicle.rpm = Lerp(0.15, vehicle.rpm, vehicle:GetEngineRPM() / vehicle:GetMaxRPM() - config.rpmCalibration)
        else
            vehicle.rpm = Lerp(0.15, vehicle.rpm, 0)
        end
        vehicle:SetPoseParameter(config.poseParameters.tacho, vehicle.rpm)
    end
    
    -- Update Speedometer
    if config.speedo then
        vehicle.speed = (vehicle:WorldToLocal(vehicle:GetVelocity(0) + vehicle:GetPos())[1] * 0.06 * 0.5)
        vehicle.gauge = vehicle.speed / config.speedCalibration * config.speedMultiplier
        vehicle:SetPoseParameter(config.poseParameters.speedo, vehicle.gauge)
    end
end

-- Oil
function BlackterioExtraFunctions:UpdateOil(vehicle, config)
    if not vehicle.oil then
        vehicle.oil = 0
    end

    local targetOil = 0

    if vehicle:GetEngineState() > 1 then
        local rpmFraction = vehicle:GetEngineRPM() / vehicle:GetMaxRPM()
        targetOil = math.Clamp(config.oilMinValue + rpmFraction * (config.oilMaxValue - config.oilMinValue), config.oilMinValue, config.oilMaxValue)
    end

    vehicle.oil = Lerp(config.oilLerpRate, vehicle.oil, targetOil)
    vehicle:SetPoseParameter(config.poseParameters.oil, vehicle.oil)
end

-- Temperature
function BlackterioExtraFunctions:UpdateTemp(vehicle, config)
    if not vehicle.temp then
        vehicle.temp = 0
    end
    
    if vehicle:GetEngineState() > 0 then
        vehicle.temp = Lerp(config.tempLerpRate, vehicle.temp, config.tempMaxValue)
    else
        vehicle.temp = Lerp(config.tempLerpRate, vehicle.temp, 0)
    end
    
    vehicle:SetPoseParameter(config.poseParameters.temp, vehicle.temp)
end

-- Battery
function BlackterioExtraFunctions:UpdateBattery(vehicle, config)
    if not vehicle.battery then
        vehicle.battery = 0
    end
    
    if vehicle:GetEngineState() > 0 then
        vehicle.battery = Lerp(config.batteryLerpRate, vehicle.battery, config.batteryMaxValue)
    else
        vehicle.battery = Lerp(config.batteryLerpRate, vehicle.battery, 0)
    end
    
    vehicle:SetPoseParameter(config.poseParameters.battery, vehicle.battery)
end

-- Fuel
function BlackterioExtraFunctions:UpdateFuel(vehicle, config)
    if not vehicle.fuel then
        vehicle.fuel = 0
    end
    
    if vehicle:GetEngineState() > 0 then
        vehicle.fuel = Lerp(config.fuelLerpRate, vehicle.fuel, 1)
    else
        vehicle.fuel = Lerp(config.fuelLerpRate, vehicle.fuel, 0)
    end
    
    vehicle:SetPoseParameter(config.poseParameters.fuel, vehicle.fuel)
end

-- Wipers
function BlackterioExtraFunctions:UpdateWipers(vehicle, config)

-- Check if Stormfox, Stormfox 2 or Gweather is installed
    if not (StormFox or StormFox2 or gWeatherInstalled) then
        vehicle.wipers = 0
        vehicle:SetPoseParameter(config.poseParameters.wipers1, vehicle.wipers)
        vehicle:SetPoseParameter(config.poseParameters.wipers2, vehicle.wipers)
        vehicle:SetPoseParameter(config.poseParameters.wipers3, vehicle.wipers)
        vehicle:SetPoseParameter(config.poseParameters.wipers4, vehicle.wipers)
        return
    end
    
    if not vehicle.oldwipers then
        vehicle.oldwipers = 0
        vehicle.wipers = 0
    end
    
    local shouldWipe = false
    
    -- Verify climate conditions
    if StormFox then
        shouldWipe = StormFox.IsRaining() and vehicle:GetEngineState() >= 1
    elseif StormFox2 then
        shouldWipe = StormFox2.Weather.HasDownfall() and vehicle:GetEngineState() >= 1
    elseif gWeatherInstalled then
        shouldWipe = (gWeather:IsRaining() or gWeather:IsSnowing()) and vehicle:GetEngineState() >= 1
    end
    
    if shouldWipe then
        vehicle.wipers = math.sin((CurTime() - vehicle.oldwipers) / config.wiperSpeed)
    else
        if vehicle:GetPoseParameter(config.poseParameters.wipers1, config.poseParameters.wipers2) > 0.01 then
            vehicle.wipers = math.sin((CurTime() - vehicle.oldwipers) / config.wiperSpeed)
        else
            vehicle.oldwipers = CurTime()
        end
    end
    
    vehicle:SetPoseParameter(config.poseParameters.wipers1, vehicle.wipers)
    vehicle:SetPoseParameter(config.poseParameters.wipers2, vehicle.wipers)
    vehicle:SetPoseParameter(config.poseParameters.wipers3, vehicle.wipers)
    vehicle:SetPoseParameter(config.poseParameters.wipers4, vehicle.wipers)
end

-- Ignition Key Animation
function BlackterioExtraFunctions:UpdateIgnitionKey(vehicle, config)
    if not vehicle.ignitionKeyAnim then
        vehicle.ignitionKeyAnim = 0
    end
    
    local engineState = vehicle:GetEngineState()
    local targetKeyPosition = 0
    

    if engineState == 0 then
        targetKeyPosition = 0
    elseif engineState == 1 then
        targetKeyPosition = 0.5
    elseif engineState >= 2 then
        targetKeyPosition = 1
    end
    
    vehicle.ignitionKeyAnim = Lerp(config.ignitionLerpRate, vehicle.ignitionKeyAnim, targetKeyPosition)
    vehicle:SetPoseParameter(config.poseParameters.ignitionKey, vehicle.ignitionKeyAnim)
end

-- Light Switch Animation
function BlackterioExtraFunctions:UpdateLightSwitch(vehicle, config)
    if not vehicle.lightSwitchAnim then
        vehicle.lightSwitchAnim = 0
    end
    
    local headlightState = vehicle:GetHeadlightState()
    local targetSwitchPosition = 0
    
    if headlightState == 0 then
        targetSwitchPosition = 0
    elseif headlightState == 1 then
        targetSwitchPosition = 0.5
    elseif headlightState == 2 then
        targetSwitchPosition = 1
    end
    
    vehicle.lightSwitchAnim = Lerp(config.lightSwitchLerpRate, vehicle.lightSwitchAnim, targetSwitchPosition)
    vehicle:SetPoseParameter(config.poseParameters.lightSwitch, vehicle.lightSwitchAnim)
end

-- Wiper Switch Animation
function BlackterioExtraFunctions:UpdateWiperSwitch(vehicle, config)
    if not vehicle.wiperSwitchAnim then
        vehicle.wiperSwitchAnim = 0
    end
    
    local shouldWipe = false
    local targetSwitchPosition = 0
    
    if StormFox then
        shouldWipe = StormFox.IsRaining() and vehicle:GetEngineState() >= 1
    elseif StormFox2 then
        shouldWipe = StormFox2.Weather.HasDownfall() and vehicle:GetEngineState() >= 1
    elseif gWeatherInstalled then
        shouldWipe = (gWeather:IsRaining() or gWeather:IsSnowing()) and vehicle:GetEngineState() >= 1
    end
    
    local wipersActive = false
    if vehicle:GetPoseParameter(config.poseParameters.wipers1) ~= 0 or 
       vehicle:GetPoseParameter(config.poseParameters.wipers2) ~= 0 or
       vehicle:GetPoseParameter(config.poseParameters.wipers3) ~= 0 or
       vehicle:GetPoseParameter(config.poseParameters.wipers4) ~= 0 then
        wipersActive = true
    end
    
    if shouldWipe or wipersActive then
        targetSwitchPosition = 1  
    else
        targetSwitchPosition = 0  
    end
    
    vehicle.wiperSwitchAnim = Lerp(config.wiperSwitchLerpRate, vehicle.wiperSwitchAnim, targetSwitchPosition)
    vehicle:SetPoseParameter(config.poseParameters.wiperSwitch, vehicle.wiperSwitchAnim)
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
        local speed = math.floor(vehicle:GetVelocity():Length() * speedMultiplier)
        local unitText = config.digitalSpeedoUnit == "MPH" and "MPH" or "KM/H"
        
        -- Create custom font if specified and doesn't exist
        if config.digitalSpeedoFont ~= "BlackterioDefaultDigitalSpeedo" and not surface.HasFont(config.digitalSpeedoFont) then
            surface.CreateFont(config.digitalSpeedoFont, {
                font = "Tahoma",
                size = 20,
                weight = 700,
                antialias = true,
            })
        end
        
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