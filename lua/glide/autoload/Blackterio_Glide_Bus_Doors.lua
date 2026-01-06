
-- Location of this file: lua/glide/autoload/

-- You can safely access the `Glide` global table in here.
Glide.Print( "%s - By Blackterio", "Doors Animations Control" )

--[[----------------------------------------
    Doors Animations Control System
    Control up to 9 animations 
    with customizable keys
------------------------------------------]]

-- Default configuration
local DEFAULT_SOUND = "blackterios_glide_vehicles/doors/busdoor.mp3"
local MAX_ANIMATIONS = 9

-- State variables for each vehicle
local vehicleAnimStates = {}


-- Create animation control group
Glide.SetupInputGroup( "door_animations" )
 
-- Add input actions for every animation
Glide.AddInputAction( "door_animations", "animation_1", KEY_PAD_1 )
Glide.AddInputAction( "door_animations", "animation_2", KEY_PAD_2 )
Glide.AddInputAction( "door_animations", "animation_3", KEY_PAD_3 )
Glide.AddInputAction( "door_animations", "animation_4", KEY_PAD_4 )
Glide.AddInputAction( "door_animations", "animation_5", KEY_PAD_5 )
Glide.AddInputAction( "door_animations", "animation_6", KEY_PAD_6 )
Glide.AddInputAction( "door_animations", "animation_7", KEY_PAD_7 )
Glide.AddInputAction( "door_animations", "animation_8", KEY_PAD_8 )
Glide.AddInputAction( "door_animations", "animation_9", KEY_PAD_9 )
Glide.AddInputAction( "door_animations", "animation_all", KEY_PAD_0 )

-- Add visualization names for controls
if CLIENT then
    language.Add( "glide.input.door_animations", "Doors Animations - Controls" )
    language.Add( "glide.input.animation_1", "Door/Animation 1" )
    language.Add( "glide.input.animation_2", "Door/Animation 2" )
    language.Add( "glide.input.animation_3", "Door/Animation 3" )
    language.Add( "glide.input.animation_4", "Door/Animation 4" )
    language.Add( "glide.input.animation_5", "Door/Animation 5" )
    language.Add( "glide.input.animation_6", "Door/Animation 6" )
    language.Add( "glide.input.animation_7", "Door/Animation 7" )
    language.Add( "glide.input.animation_8", "Door/Animation 8" )
    language.Add( "glide.input.animation_9", "Door/Animation 9" )
    language.Add( "glide.input.animation_all", "All Doors/Animations" )
end

-- Get animation configurations of a vehicle
local function GetVehicleAnimConfig( vehicle )
    if not IsValid( vehicle ) then return nil end
    
    -- Default configuration
    local config = {
        count = 3, -- Animation number to use (6 max)
        names = { "doorfront", "doormiddle", "doorback", "extra_1", "extra_2", "extra_3", "extra_4", "extra_5", "extra_6" }, -- Animation names (controls order will follow this one)
        sound = DEFAULT_SOUND,
        duration = 2.0, -- Animation duration, in seconds
        lerpType = "smooth" -- Lerp type: "linear", "smooth", "fast_start", "slow_start"
    }
    
            -- Allow vehicle to overwrite default configuration
    if vehicle.GetAnimationConfig then
        local vehicleConfig = vehicle:GetAnimationConfig()
        if vehicleConfig then
            config.count = vehicleConfig.count or config.count
            config.names = vehicleConfig.names or config.names
            config.sound = vehicleConfig.sound or config.sound
            config.duration = vehicleConfig.duration or config.duration
            config.lerpType = vehicleConfig.lerpType or config.lerpType
        end
    end
    
    return config
end

-- Alternate a specific animation
local function ToggleAnimation( vehicle, animIndex )
    if not IsValid( vehicle ) then return end
    
    local config = GetVehicleAnimConfig( vehicle )
    if not config or animIndex > config.count then return end
    
    local vehicleID = vehicle:EntIndex()
    
    -- Initialize vehicle state if it doesn't exist
    if not vehicleAnimStates[vehicleID] then
        vehicleAnimStates[vehicleID] = {}
        for i = 1, MAX_ANIMATIONS do
            vehicleAnimStates[vehicleID][i] = false
        end
    end
    
    -- Alternate animation state
    local currentState = vehicleAnimStates[vehicleID][animIndex]
    local newState = not currentState
    vehicleAnimStates[vehicleID][animIndex] = newState
    
    -- IMPORTANT: Use specific function of the vehicle if it exists
    if CLIENT and vehicle.UpdateDoorState then
        vehicle:UpdateDoorState(animIndex, newState)
    else
        -- Apply animation using pose parameters (fallback)
        local paramName = config.names[animIndex]
        if paramName then
            local targetValue = newState and 1 or 0
            vehicle:SetPoseParameter( paramName, targetValue )
        end
    end
    
    -- Sound
    if config.sound and config.sound ~= "" then
        vehicle:EmitSound( config.sound, 70, 100, 1, CHAN_AUTO )
    end
    
    -- Syncronize with other clients
    if SERVER then
        net.Start( "GlideBusDoorAnimationSync" )
        net.WriteEntity( vehicle )
        net.WriteUInt( animIndex, 4 )
        net.WriteBool( newState )
        net.Broadcast()
    end
	
  --[[ Debug print 
  
    if CLIENT then
        print("[Bus Doors Animations Controls] Toggled animation " .. animIndex .. " to " .. (newState and "OPEN" or "CLOSED"))
    end	
	]]  

end

-- Alternate all animations
local function ToggleAllAnimations( vehicle )
    if not IsValid( vehicle ) then return end
    
    local config = GetVehicleAnimConfig( vehicle )
    if not config then return end
    
    local vehicleID = vehicle:EntIndex()
    
    -- Initialize vehicle state if it doesn't exist
    if not vehicleAnimStates[vehicleID] then
        vehicleAnimStates[vehicleID] = {}
        for i = 1, MAX_ANIMATIONS do
            vehicleAnimStates[vehicleID][i] = false
        end
    end
    
    -- Should we open or close all animations
    -- If any is closed, we open all of them; if all are open, we close them all
    local shouldOpen = false
    for i = 1, config.count do
        if not vehicleAnimStates[vehicleID][i] then
            shouldOpen = true
            break
        end
    end
    
    -- Apply state to all animations
    for i = 1, config.count do
        vehicleAnimStates[vehicleID][i] = shouldOpen
        
    -- IMPORTANT: Use specific function of the vehicle if it exists
        if CLIENT and vehicle.UpdateDoorState then
            vehicle:UpdateDoorState(i, shouldOpen)
        else
        -- Apply animation using pose parameters (fallback)
            local paramName = config.names[i]
            if paramName then
                local targetValue = shouldOpen and 1 or 0
                vehicle:SetPoseParameter( paramName, targetValue )
            end
        end
    end
    
    -- Sound
    if config.sound and config.sound ~= "" then
        vehicle:EmitSound( config.sound, 70, 100, 1, CHAN_AUTO )
    end
    
    -- Syncronize with other clients
    if SERVER then
        net.Start( "GlideBusDoorAnimationSyncAll" )
        net.WriteEntity( vehicle )
        net.WriteBool( shouldOpen )
        net.WriteUInt( config.count, 4 )
        net.Broadcast()
    end
    
  --[[ Debug print
    if CLIENT then
        print("[Bus Doors Animations Controls] Toggled ALL animations to " .. (shouldOpen and "OPEN" or "CLOSED"))
    end
	]]  
end

--[[--------------------------
    Red syncronization
------------------------------]]

if SERVER then
    -- Register network messages
    util.AddNetworkString( "GlideBusDoorAnimationSync" )
    util.AddNetworkString( "GlideBusDoorAnimationSyncAll" )
    
elseif CLIENT then
    -- Receive individual animation syncronization
    net.Receive( "GlideBusDoorAnimationSync", function()
        local vehicle = net.ReadEntity()
        local animIndex = net.ReadUInt( 4 )
        local newState = net.ReadBool()
        
        if IsValid( vehicle ) then
            local vehicleID = vehicle:EntIndex()
            
            if not vehicleAnimStates[vehicleID] then
                vehicleAnimStates[vehicleID] = {}
                for i = 1, MAX_ANIMATIONS do
                    vehicleAnimStates[vehicleID][i] = false
                end
            end
            
            vehicleAnimStates[vehicleID][animIndex] = newState
            
    -- IMPORTANT: Use specific function of the vehicle if it exists
            if vehicle.UpdateDoorState then
                vehicle:UpdateDoorState(animIndex, newState)
            else
        -- Apply animation using pose parameters (fallback)
                local config = GetVehicleAnimConfig( vehicle )
                if config and config.names[animIndex] then
                    local targetValue = newState and 1 or 0
                    vehicle:SetPoseParameter( config.names[animIndex], targetValue )
                end
            end
            

        end
    end )
    
    -- Receive syncronization of all animations
    net.Receive( "GlideBusDoorAnimationSyncAll", function()
        local vehicle = net.ReadEntity()
        local shouldOpen = net.ReadBool()
        local count = net.ReadUInt( 4 )
        
        if IsValid( vehicle ) then
            local vehicleID = vehicle:EntIndex()
            
            if not vehicleAnimStates[vehicleID] then
                vehicleAnimStates[vehicleID] = {}
                for i = 1, MAX_ANIMATIONS do
                    vehicleAnimStates[vehicleID][i] = false
                end
            end
            
            for i = 1, count do
                vehicleAnimStates[vehicleID][i] = shouldOpen
                
    -- IMPORTANT: Use specific function of the vehicle if it exists
                if vehicle.UpdateDoorState then
                    vehicle:UpdateDoorState(i, shouldOpen)
                else
                    -- Fallback using pose parameters directly
                    local config = GetVehicleAnimConfig( vehicle )
                    if config and config.names[i] then
                        local targetValue = shouldOpen and 1 or 0
                        vehicle:SetPoseParameter( config.names[i], targetValue )
                    end
                end
            end
            

        end
    end )
end

--[[----------------------------------------
    Clean deleted vehicles states
------------------------------------------]]

hook.Add( "EntityRemoved", "GlideAnimationCleanup", function( ent )
    if IsValid( ent ) and ent:IsVehicle() then
        local vehicleID = ent:EntIndex()
        vehicleAnimStates[vehicleID] = nil
    end
end )

--[[----------------------------------------
    Global functions to use in vehicles
------------------------------------------]]

function HandleVehicleAnimationInput( vehicle, seatIndex, action, pressed )
    if not pressed then return false end
    if not IsValid( vehicle ) then return false end
    
    -- Only driver can control the animations (seat 1)
    if seatIndex ~= 1 then return false end
    
    -- IMPORTANT: Only handle animations that start with "animation_"
    if not string.find(action, "animation_") then
        return false -- Not an animation action
    end
    
 --[[   -- Debug print
    if CLIENT then
        print("[Bus Doors Animations Controls] Input received: " .. action .. " from seat " .. seatIndex)
    end
 ]]   
    if action == "animation_1" then
        ToggleAnimation( vehicle, 1 )
        return true
    elseif action == "animation_2" then
        ToggleAnimation( vehicle, 2 ) 
        return true
    elseif action == "animation_3" then
        ToggleAnimation( vehicle, 3 )  
        return true
    elseif action == "animation_4" then
        ToggleAnimation( vehicle, 4 )
        return true
    elseif action == "animation_5" then
        ToggleAnimation( vehicle, 5 )
        return true
    elseif action == "animation_6" then
        ToggleAnimation( vehicle, 6 )
        return true
    elseif action == "animation_7" then
        ToggleAnimation( vehicle, 7 )
        return true
    elseif action == "animation_8" then
        ToggleAnimation( vehicle, 8 )
        return true
    elseif action == "animation_9" then
        ToggleAnimation( vehicle, 9 )
        return true	
    elseif action == "animation_all" then
        ToggleAllAnimations( vehicle )
        return true
    end
    
    return false
end

--[[----------------------------------------
    Configuration panel
------------------------------------------]]

list.Set( "GlideConfigExtensions", "BusDoorsAnimationsControls", function( config, panel )
    
    config.CreateHeader( panel, "Doors Animations Controls" )
    
    config.CreateButton( panel, "Test Doors System", function()
        chat.AddText( Color(100, 255, 100), "[Doors Animations Controls] ", Color(255, 255, 255), "Animation system loaded successfully!" )
        chat.AddText( Color(200, 200, 200), "Use the configured keys while in a vehicle to control animations." )
    end )
    
    -- Information about this system
    local infoText = [[
This extension adds doors controls to GLIDE vehicles.
It can also be used to control other type of animations.

Features:
• Control up to 6 animations with customizable keys
• Default: Numpad 1-6 for individual animations, Numpad 0 for all
• Synchronized across all players
• Customizable sounds and pose parameter names
• Only the driver can control animations

To use in your vehicle:
1. Add "door_animations" to GetInputGroups()
2. Call HandleVehicleAnimationInput() in OnSeatInput()
3. Optionally add GetAnimationConfig() to customize settings

Animation Types Available:
• "linear" - Constant speed animation
• "smooth" - Smooth ease in-out (default)
• "fast_start" - Fast start, slow end
• "slow_start" - Slow start, fast end
]]
    
    -- Information panel
    config.CreateButton( panel, "Show Information For Devs", function()
        chat.AddText( Color(100, 200, 255), "[Info] ", Color(255, 255, 255), infoText )
    end )
    
end )