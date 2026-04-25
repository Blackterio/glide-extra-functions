-- Location of this file: lua/glide/autoload/

Glide.Print( "%s - By Blackterio", "Custom Animations Control" )

--[[----------------------------------------
    Custom Animations Control System
    Control up to 9 animations
    with customizable keys
------------------------------------------]]

-- Public namespace
BlackterioCustomAnims = BlackterioCustomAnims or {}

-- Default sounds

	local INITIAL_DEFAULT_SOUND = "blackterios_glide_vehicles/doors/busopen.wav"
	local FINISH_DEFAULT_SOUND  = "blackterios_glide_vehicles/doors/busclose.wav"
	
	--[[
	Other available sounds in this addon:
	
	"blackterios_glide_vehicles/doors/caropen.wav"
	"blackterios_glide_vehicles/doors/carclose.wav"
	"blackterios_glide_vehicles/doors/trunkhoodopen.wav"
	"blackterios_glide_vehicles/doors/trunkhoodclose.wav"
	"blackterios_glide_vehicles/doors/airrelease.mp3" // this was the original bus door sound before changing to the improved system
	
	--]]


-- Global cooldown (seconds) applied to every animation toggle.
local ANIM_COOLDOWN  = 0.5
local MAX_ANIMATIONS = 9

-- When closing (target = 0), snap to 0 once the value drops to or below this threshold.
local SNAP_THRESHOLD = 0.05

-- Boolean open/closed state per vehicle
local vehicleAnimStates = {}

-- Lerp state per vehicle (CLIENT only)
-- vehicleAnimLerpData[vehicleID] = { poseValues={}, targetValues={}, lerpSpeeds={} }
local vehicleAnimLerpData = {}

-- Last toggle time per vehicle per animation index (0 = "all" slot)
local vehicleAnimCooldownTimers = {}

--[[----------------------------------------
    Input group setup
------------------------------------------]]

Glide.SetupInputGroup( "door_animations" )

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

if CLIENT then
    language.Add( "glide.input.door_animations", "Blackterio's Custom Animations - Controls" )
    language.Add( "glide.input.animation_1",   "Animation 1" )
    language.Add( "glide.input.animation_2",   "Animation 2" )
    language.Add( "glide.input.animation_3",   "Animation 3" )
    language.Add( "glide.input.animation_4",   "Animation 4" )
    language.Add( "glide.input.animation_5",   "Animation 5" )
    language.Add( "glide.input.animation_6",   "Animation 6" )
    language.Add( "glide.input.animation_7",   "Animation 7" )
    language.Add( "glide.input.animation_8",   "Animation 8" )
    language.Add( "glide.input.animation_9",   "Animation 9" )
    language.Add( "glide.input.animation_all", "All Animations" )
end

--[[----------------------------------------
    Config helpers
------------------------------------------]]

-- Returns merged config (vehicle overrides + defaults)
local function GetVehicleAnimConfig( vehicle )
    if not IsValid( vehicle ) then return nil end

    local config = {
        count                = 3,
        names                = { "doorfront", "doormiddle", "doorback", "extra_1", "extra_2", "extra_3", "extra_4", "extra_5", "extra_6" },
        initialSound         = INITIAL_DEFAULT_SOUND,
        finishSound          = FINISH_DEFAULT_SOUND,
        duration             = 2.0,
        lerpType             = "smooth",
        soundFollowsDuration = false
    }

    if vehicle.GetAnimationConfig then
        local v = vehicle:GetAnimationConfig()
        if v then
            config.count        = v.count        or config.count
            config.names        = v.names        or config.names
            config.initialSound = v.initialSound or config.initialSound
            config.finishSound  = v.finishSound  or config.finishSound
            config.duration     = v.duration     or config.duration
            config.lerpType     = v.lerpType     or config.lerpType
            if v.soundFollowsDuration ~= nil then
                config.soundFollowsDuration = v.soundFollowsDuration
            end
        end
    end

    -- Per-animation sound overrides from GetAdvancedAnimationConfig
    -- Supports both function (ENT:GetAdvancedAnimationConfig()) and table property
    local advancedRaw
    if type( vehicle.GetAdvancedAnimationConfig ) == "function" then
        advancedRaw = vehicle:GetAdvancedAnimationConfig()
    elseif type( vehicle.GetAdvancedAnimationConfig ) == "table" then
        advancedRaw = vehicle.GetAdvancedAnimationConfig
    end

    if advancedRaw then
        config.soundOverrides = {}
        for _, entry in ipairs( advancedRaw ) do
            if entry.name then
                config.soundOverrides[entry.name] = {
                    customInitialSound = entry.customInitialSound,
                    customFinishSound  = entry.customFinishSound,
                }
            end
        end
    end

    return config
end

-- Lazy-initializes lerp data for a vehicle (CLIENT only)
local function EnsureLerpData( vehicleID, config )
    if vehicleAnimLerpData[vehicleID] then return end

    local lerpSpeed = 1 / ( config.duration or 2.0 )
    local data = { poseValues = {}, targetValues = {}, lerpSpeeds = {} }

    for i = 1, MAX_ANIMATIONS do
        data.poseValues[i]   = 0
        data.targetValues[i] = 0
        data.lerpSpeeds[i]   = lerpSpeed
    end

    vehicleAnimLerpData[vehicleID] = data
end

-- Ensures vehicleAnimStates[vehicleID] exists
local function EnsureAnimStates( vehicleID )
    if vehicleAnimStates[vehicleID] then return end
    vehicleAnimStates[vehicleID] = {}
    for i = 1, MAX_ANIMATIONS do
        vehicleAnimStates[vehicleID][i] = false
    end
end

--[[----------------------------------------
    Toggle logic
------------------------------------------]]

local function ToggleAnimation( vehicle, animIndex )
    if not IsValid( vehicle ) then return end

    local config = GetVehicleAnimConfig( vehicle )
    if not config or animIndex > config.count then return end

    local vehicleID = vehicle:EntIndex()

    -- Global cooldown gate: blocks animation, sound, and network sync together
    local now = CurTime()
    if not vehicleAnimCooldownTimers[vehicleID] then vehicleAnimCooldownTimers[vehicleID] = {} end
    local lastTime = vehicleAnimCooldownTimers[vehicleID][animIndex] or 0
    if ( now - lastTime ) < ANIM_COOLDOWN then return end
    vehicleAnimCooldownTimers[vehicleID][animIndex] = now

    EnsureAnimStates( vehicleID )

    local newState = not vehicleAnimStates[vehicleID][animIndex]
    vehicleAnimStates[vehicleID][animIndex] = newState

    if CLIENT then
        EnsureLerpData( vehicleID, config )
        local data = vehicleAnimLerpData[vehicleID]
        if data then
            data.targetValues[animIndex] = newState and 1 or 0
            data.lerpSpeeds[animIndex]   = 1 / ( config.duration or 2.0 )
        end
    end

    local animName = config.names[animIndex]
    local override = config.soundOverrides and config.soundOverrides[animName]

    local snd
    if config.soundFollowsDuration then
        if newState then
            snd = ( override and override.customInitialSound ) or config.initialSound
        end
    else
        if newState then
            snd = ( override and override.customInitialSound ) or config.initialSound
        else
            snd = ( override and override.customFinishSound ) or config.finishSound
        end
    end
    if snd and snd ~= "" then
        vehicle:EmitSound( snd, 70, 100, 1, CHAN_AUTO )
    end

    if SERVER then
        net.Start( "BlackterioCustomAnimSync" )
        net.WriteEntity( vehicle )
        net.WriteUInt( animIndex, 4 )
        net.WriteBool( newState )
        net.Broadcast()
    end
end

local function ToggleAllAnimations( vehicle )
    if not IsValid( vehicle ) then return end

    local config = GetVehicleAnimConfig( vehicle )
    if not config then return end

    local vehicleID = vehicle:EntIndex()

    -- Global cooldown gate (slot 0 = "all" toggle)
    local now = CurTime()
    if not vehicleAnimCooldownTimers[vehicleID] then vehicleAnimCooldownTimers[vehicleID] = {} end
    local lastTime = vehicleAnimCooldownTimers[vehicleID][0] or 0
    if ( now - lastTime ) < ANIM_COOLDOWN then return end
    vehicleAnimCooldownTimers[vehicleID][0] = now

    EnsureAnimStates( vehicleID )

    -- Open all if any is closed; close all if all are open
    local shouldOpen = false
    for i = 1, config.count do
        if not vehicleAnimStates[vehicleID][i] then
            shouldOpen = true
            break
        end
    end

    for i = 1, config.count do
        vehicleAnimStates[vehicleID][i] = shouldOpen
    end

    if CLIENT then
        EnsureLerpData( vehicleID, config )
        local data = vehicleAnimLerpData[vehicleID]
        if data then
            local lerpSpeed = 1 / ( config.duration or 2.0 )
            for i = 1, config.count do
                data.targetValues[i] = shouldOpen and 1 or 0
                data.lerpSpeeds[i]   = lerpSpeed
            end
        end
    end

    local snd
    if config.soundFollowsDuration then
        if shouldOpen then snd = config.initialSound end
    else
        snd = shouldOpen and config.initialSound or config.finishSound
    end
    if snd and snd ~= "" then
        vehicle:EmitSound( snd, 70, 100, 1, CHAN_AUTO )
    end

    if SERVER then
        net.Start( "BlackterioCustomAnimSyncAll" )
        net.WriteEntity( vehicle )
        net.WriteBool( shouldOpen )
        net.WriteUInt( config.count, 4 )
        net.Broadcast()
    end
end

--[[----------------------------------------
    Network synchronization
------------------------------------------]]

if SERVER then
    util.AddNetworkString( "BlackterioCustomAnimSync" )
    util.AddNetworkString( "BlackterioCustomAnimSyncAll" )

elseif CLIENT then

    net.Receive( "BlackterioCustomAnimSync", function()
        local vehicle   = net.ReadEntity()
        local animIndex = net.ReadUInt( 4 )
        local newState  = net.ReadBool()

        if not IsValid( vehicle ) then return end

        local vehicleID = vehicle:EntIndex()
        EnsureAnimStates( vehicleID )
        vehicleAnimStates[vehicleID][animIndex] = newState

        local config = GetVehicleAnimConfig( vehicle )
        if config then
            EnsureLerpData( vehicleID, config )
            local data = vehicleAnimLerpData[vehicleID]
            if data then
                data.targetValues[animIndex] = newState and 1 or 0
                data.lerpSpeeds[animIndex]   = 1 / ( config.duration or 2.0 )
            end
        end
    end )

    net.Receive( "BlackterioCustomAnimSyncAll", function()
        local vehicle    = net.ReadEntity()
        local shouldOpen = net.ReadBool()
        local count      = net.ReadUInt( 4 )

        if not IsValid( vehicle ) then return end

        local vehicleID = vehicle:EntIndex()
        EnsureAnimStates( vehicleID )

        local config = GetVehicleAnimConfig( vehicle )
        if config then
            EnsureLerpData( vehicleID, config )
            local data = vehicleAnimLerpData[vehicleID]
            if data then
                local lerpSpeed = 1 / ( config.duration or 2.0 )
                for i = 1, count do
                    vehicleAnimStates[vehicleID][i] = shouldOpen
                    data.targetValues[i] = shouldOpen and 1 or 0
                    data.lerpSpeeds[i]   = lerpSpeed
                end
            end
        end
    end )

end

--[[----------------------------------------
    State cleanup on vehicle removal
------------------------------------------]]

hook.Add( "EntityRemoved", "BlackterioCustomAnimCleanup", function( ent )
    if IsValid( ent ) and ent.IsGlideVehicle then
        local id = ent:EntIndex()
        vehicleAnimStates[id]          = nil
        vehicleAnimLerpData[id]        = nil
        vehicleAnimCooldownTimers[id]  = nil
    end
end )

--[[----------------------------------------
    Public API
------------------------------------------]]

function BlackterioCustomAnims.UpdateAnimations( vehicle )
    if not IsValid( vehicle ) then return end

    local vehicleID = vehicle:EntIndex()
    local config    = GetVehicleAnimConfig( vehicle )
    if not config then return end

    EnsureLerpData( vehicleID, config )
    local data = vehicleAnimLerpData[vehicleID]
    if not data then return end

    local deltaTime        = FrameTime()
    local lerpType         = config.lerpType or "smooth"
    local finishSoundsFired = {}

    for i = 1, config.count do
        local paramName = config.names[i]
        if paramName then
            local currentValue = data.poseValues[i]
            local targetValue  = data.targetValues[i]

            if math.abs( currentValue - targetValue ) > 0.001 then
                local lerpAmount = math.min( data.lerpSpeeds[i] * deltaTime, 1 )
                local newValue

                if lerpType == "smooth" then
                    -- Ease in-out
                    local t = lerpAmount * lerpAmount * ( 3 - 2 * lerpAmount )
                    newValue = currentValue + ( targetValue - currentValue ) * t
                elseif lerpType == "fast_start" then
                    -- Fast start, slow end
                    local t = 1 - ( 1 - lerpAmount ) ^ 2
                    newValue = currentValue + ( targetValue - currentValue ) * t
                elseif lerpType == "slow_start" then
                    -- Slow start, fast end
                    local t = lerpAmount ^ 2
                    newValue = currentValue + ( targetValue - currentValue ) * t
                else
                    -- Linear (default)
                    newValue = Lerp( lerpAmount, currentValue, targetValue )
                end

                -- Snap to target when close enough, or when closing and within SNAP_THRESHOLD
                if math.abs( newValue - targetValue ) < 0.001
                    or ( targetValue == 0 and newValue <= SNAP_THRESHOLD ) then
                    if config.soundFollowsDuration and targetValue == 0 and currentValue > 0.001 then
                        local override = config.soundOverrides and config.soundOverrides[paramName]
                        local snd = ( override and override.customFinishSound ) or config.finishSound
                        if snd and snd ~= "" and not finishSoundsFired[snd] then
                            vehicle:EmitSound( snd, 70, 100, 1, CHAN_AUTO )
                            finishSoundsFired[snd] = true
                        end
                    end
                    newValue = targetValue
                end

                data.poseValues[i] = newValue
                vehicle:SetPoseParameter( paramName, newValue )
            else
                vehicle:SetPoseParameter( paramName, targetValue )
            end
        end
    end
end

--[[----------------------------------------
    Global input handler (called by vehicles)
------------------------------------------]]

function HandleVehicleAnimationInput( vehicle, seatIndex, action, pressed )
    if not pressed then return false end
    if not IsValid( vehicle ) then return false end
    if seatIndex ~= 1 then return false end
    if not string.find( action, "animation_" ) then return false end

    local idx = tonumber( action:match( "^animation_(%d+)$" ) )
    if idx then
        ToggleAnimation( vehicle, idx )
        return true
    end

    if action == "animation_all" then
        ToggleAllAnimations( vehicle )
        return true
    end

    return false
end


local function InjectIntoVehicle( ent )
    if not IsValid( ent ) then return end
    if not ent.IsGlideVehicle then return end
    if not ent.GetAnimationConfig then return end

    local origGetInputGroups = ent.GetInputGroups
    ent.GetInputGroups = function( self, seatIndex )
        local groups = origGetInputGroups and origGetInputGroups( self, seatIndex ) or {}
        if not table.HasValue( groups, "door_animations" ) then
            table.insert( groups, "door_animations" )
        end
        return groups
    end

    local origOnSeatInput = ent.OnSeatInput
    ent.OnSeatInput = function( self, seatIndex, action, pressed )
        if string.find( action, "animation_" ) then
            return HandleVehicleAnimationInput( self, seatIndex, action, pressed )
        end
        if origOnSeatInput then
            return origOnSeatInput( self, seatIndex, action, pressed )
        end
        return false
    end
end

hook.Add( "OnEntityCreated", "BlackterioCustomAnimAutoInject", function( ent )
    if not ent.GetAnimationConfig then return end

    -- Defer one tick: Initialize() needs to run first so ent.IsGlideVehicle is set
    timer.Simple( 0, function()
        InjectIntoVehicle( ent )
    end )
end )


