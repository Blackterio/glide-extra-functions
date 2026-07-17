-- Location of this file: lua/glide/autoload/

Glide.Print( "%s - By Blackterio", "Custom Animations Control" )

--[[----------------------------------------
    Custom Animations Control System
    Control up to 9 animations
    with customizable keys

    State is stored in a NW2Int bitmask on the vehicle
    ("blackterio_anims", bit N-1 = animation N open).
    The server is authoritative; clients (including late
    joiners and players re-entering the PVS) read the
    bitmask every frame and animate towards it.
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

-- Networked bitmask holding the open/closed state of all animations
local NW_ANIMS = "blackterio_anims"

local bit_band, bit_bxor, bit_lshift = bit.band, bit.bxor, bit.lshift

--[[----------------------------------------
    Input group setup
------------------------------------------]]

-- Guarded registration: safe on autorefresh (no group reset, no
-- "Input action already exists" spam) and independent of which
-- Blackterio autoload file happens to run first.
if not Glide.InputGroups["door_animations"] then
    Glide.SetupInputGroup( "door_animations" )
end

local function AddActionOnce( action, defaultButton )
    if Glide.InputGroups["door_animations"][action] == nil then
        Glide.AddInputAction( "door_animations", action, defaultButton )
    end
end

AddActionOnce( "animation_1", KEY_PAD_1 )
AddActionOnce( "animation_2", KEY_PAD_2 )
AddActionOnce( "animation_3", KEY_PAD_3 )
AddActionOnce( "animation_4", KEY_PAD_4 )
AddActionOnce( "animation_5", KEY_PAD_5 )
AddActionOnce( "animation_6", KEY_PAD_6 )
AddActionOnce( "animation_7", KEY_PAD_7 )
AddActionOnce( "animation_8", KEY_PAD_8 )
AddActionOnce( "animation_9", KEY_PAD_9 )
AddActionOnce( "animation_all", KEY_PAD_0 )

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
        config.animOverrides = {}
        for _, entry in ipairs( advancedRaw ) do
            if entry.name then
                config.animOverrides[entry.name] = {
                    customInitialSound   = entry.customInitialSound,
                    customFinishSound    = entry.customFinishSound,
                    duration             = entry.duration,
                    lerpType             = entry.lerpType,
                    soundFollowsDuration = entry.soundFollowsDuration,
                    isDoor               = entry.isDoor,
                }
            end
        end
    end

    return config
end

-- Config is built once per entity (per realm) and cached on it.
-- Call BlackterioCustomAnims.InvalidateConfig( vehicle ) if the
-- vehicle's animation config changes at runtime.
local function GetCachedConfig( vehicle )
    local config = vehicle._bcaConfig

    if config == nil then
        config = GetVehicleAnimConfig( vehicle ) or false
        vehicle._bcaConfig = config
    end

    if config == false then return nil end
    return config
end

function BlackterioCustomAnims.InvalidateConfig( vehicle )
    if not IsValid( vehicle ) then return end
    vehicle._bcaConfig = nil
    vehicle._bcaLerp = nil
end

-- Resolves a per-animation config param, falling back to the global config value.
local function GetAnimParam( config, animName, param )
    if animName then
        local override = config.animOverrides and config.animOverrides[animName]
        if override and override[param] ~= nil then
            return override[param]
        end
    end
    return config[param]
end

--[[----------------------------------------
    Toggle logic (SERVER only — Glide calls
    ENT:OnSeatInput on the server realm)
------------------------------------------]]

local function ToggleAnimation( vehicle, animIndex )
    if not SERVER then return end
    if not IsValid( vehicle ) then return end

    local config = GetCachedConfig( vehicle )
    if not config or animIndex > config.count then return end

    -- Global cooldown gate: blocks animation and sound together
    local now = CurTime()
    local cooldowns = vehicle._bcaCooldown
    if not cooldowns then
        cooldowns = {}
        vehicle._bcaCooldown = cooldowns
    end
    if ( now - ( cooldowns[animIndex] or 0 ) ) < ANIM_COOLDOWN then return end
    cooldowns[animIndex] = now

    local bits = vehicle:GetNW2Int( NW_ANIMS, 0 )
    local mask = bit_lshift( 1, animIndex - 1 )
    local newState = bit_band( bits, mask ) == 0

    -- Flip the bit; clients pick this up in UpdateAnimations
    vehicle:SetNW2Int( NW_ANIMS, bit_bxor( bits, mask ) )

    local animName             = config.names[animIndex]
    local override             = config.animOverrides and config.animOverrides[animName]
    local soundFollowsDuration = GetAnimParam( config, animName, "soundFollowsDuration" )

    local snd
    if soundFollowsDuration then
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
end

local function ToggleAllAnimations( vehicle )
    if not SERVER then return end
    if not IsValid( vehicle ) then return end

    local config = GetCachedConfig( vehicle )
    if not config then return end

    -- Global cooldown gate (slot 0 = "all" toggle)
    local now = CurTime()
    local cooldowns = vehicle._bcaCooldown
    if not cooldowns then
        cooldowns = {}
        vehicle._bcaCooldown = cooldowns
    end
    if ( now - ( cooldowns[0] or 0 ) ) < ANIM_COOLDOWN then return end
    cooldowns[0] = now

    local bits = vehicle:GetNW2Int( NW_ANIMS, 0 )

    -- Open all if any is closed; close all if all are open.
    -- Animations with isDoor == false are excluded from this toggle.
    local shouldOpen = false
    for i = 1, config.count do
        local animName = config.names[i]
        if GetAnimParam( config, animName, "isDoor" ) ~= false
            and bit_band( bits, bit_lshift( 1, i - 1 ) ) == 0 then
            shouldOpen = true
            break
        end
    end

    for i = 1, config.count do
        local animName = config.names[i]
        if GetAnimParam( config, animName, "isDoor" ) ~= false then
            local mask = bit_lshift( 1, i - 1 )
            if shouldOpen then
                bits = bit.bor( bits, mask )
            elseif bit_band( bits, mask ) ~= 0 then
                bits = bit_bxor( bits, mask )
            end
        end
    end

    vehicle:SetNW2Int( NW_ANIMS, bits )

    local snd
    if config.soundFollowsDuration then
        if shouldOpen then snd = config.initialSound end
    else
        snd = shouldOpen and config.initialSound or config.finishSound
    end
    if snd and snd ~= "" then
        vehicle:EmitSound( snd, 70, 100, 1, CHAN_AUTO )
    end
end

--[[----------------------------------------
    Public API
------------------------------------------]]

-- Returns whether an animation is currently open (works on both realms).
function BlackterioCustomAnims.GetAnimationState( vehicle, animIndex )
    if not IsValid( vehicle ) then return false end
    return bit_band( vehicle:GetNW2Int( NW_ANIMS, 0 ), bit_lshift( 1, animIndex - 1 ) ) ~= 0
end

function BlackterioCustomAnims.UpdateAnimations( vehicle )
    if not IsValid( vehicle ) then return end

    local config = GetCachedConfig( vehicle )
    if not config then return end

    local bits = vehicle:GetNW2Int( NW_ANIMS, 0 )
    local data = vehicle._bcaLerp

    if not data then
        -- First frame for this entity on this client: snap straight to the
        -- networked state, so late joiners / full updates / PVS re-entries
        -- see doors already in their real position instead of closed.
        data = { poseValues = {}, targetValues = {}, startValues = {}, startTimes = {}, durations = {}, lastBits = bits }

        for i = 1, MAX_ANIMATIONS do
            local v = bit_band( bits, bit_lshift( 1, i - 1 ) ) ~= 0 and 1 or 0
            local animName = config.names[i]
            data.poseValues[i]   = v
            data.targetValues[i] = v
            data.startValues[i]  = v
            data.startTimes[i]   = 0
            data.durations[i]    = GetAnimParam( config, animName, "duration" ) or 2.0
        end

        vehicle._bcaLerp = data

    elseif bits ~= data.lastBits then
        -- Server toggled something: update targets for the changed bits only.
        -- The animation is TIME-based (start value + start time + duration):
        -- easing is applied to the overall progress, so it takes exactly
        -- `duration` seconds on every client regardless of frame rate.
        -- (The old code applied the easing to a per-frame fraction, which
        -- made doors move faster at LOWER frame rates.)
        for i = 1, config.count do
            local mask = bit_lshift( 1, i - 1 )
            if bit_band( bits, mask ) ~= bit_band( data.lastBits, mask ) then
                local animName = config.names[i]
                data.targetValues[i] = bit_band( bits, mask ) ~= 0 and 1 or 0
                data.startValues[i]  = data.poseValues[i]
                data.startTimes[i]   = CurTime()
                data.durations[i]    = GetAnimParam( config, animName, "duration" ) or 2.0
            end
        end

        data.lastBits = bits
    end

    local now               = CurTime()
    local finishSoundsFired = {}

    for i = 1, config.count do
        local paramName = config.names[i]
        if paramName then
            local currentValue = data.poseValues[i]
            local targetValue  = data.targetValues[i]

            if currentValue ~= targetValue then
                local startValue = data.startValues[i]
                local travel     = math.abs( targetValue - startValue )

                -- Scale the duration by the distance to travel, so a door
                -- re-toggled mid-swing moves at the same speed instead of
                -- taking the full duration for a partial travel.
                local effDuration = data.durations[i] * ( travel > 0 and travel or 1 )
                local progress    = effDuration > 0 and math.min( ( now - data.startTimes[i] ) / effDuration, 1 ) or 1

                local lerpType = GetAnimParam( config, paramName, "lerpType" ) or "smooth"
                local t

                if lerpType == "smooth" then
                    -- Ease in-out
                    t = progress * progress * ( 3 - 2 * progress )
                elseif lerpType == "fast_start" then
                    -- Fast start, slow end
                    t = 1 - ( 1 - progress ) ^ 2
                elseif lerpType == "slow_start" then
                    -- Slow start, fast end
                    t = progress ^ 2
                else
                    -- Linear
                    t = progress
                end

                local newValue = startValue + ( targetValue - startValue ) * t

                if progress >= 1 then
                    local soundFollowsDuration = GetAnimParam( config, paramName, "soundFollowsDuration" )
                    if soundFollowsDuration and targetValue == 0 and startValue > 0.001 then
                        local override = config.animOverrides and config.animOverrides[paramName]
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
    if not string.find( action, "animation_", 1, true ) then return false end

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
        if string.find( action, "animation_", 1, true ) then
            return HandleVehicleAnimationInput( self, seatIndex, action, pressed )
        end
        if origOnSeatInput then
            return origOnSeatInput( self, seatIndex, action, pressed )
        end
        return false
    end
end

-- SERVER only: Glide consumes the per-entity GetInputGroups/OnSeatInput
-- exclusively on the server realm (glide/server/input.lua), so injecting
-- on the client was dead work.
if SERVER then
    hook.Add( "OnEntityCreated", "BlackterioCustomAnimAutoInject", function( ent )
        if not ent.GetAnimationConfig then return end

        -- Defer one tick: Initialize() needs to run first so ent.IsGlideVehicle is set
        timer.Simple( 0, function()
            InjectIntoVehicle( ent )
        end )
    end )
end
