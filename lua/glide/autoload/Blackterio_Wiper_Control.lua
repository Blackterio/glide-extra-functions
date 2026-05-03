-- Location of this file: lua/glide/autoload/
-- Loaded after all Glide files. The Glide global is available here.
-- NOTE: This file loads via Glide's IncludeDir (inside lua/autorun/sh_glide.lua)
-- which runs BEFORE lua/autorun/shared/, so BlackterioExtraFunctions may not exist yet.
BlackterioExtraFunctions = BlackterioExtraFunctions or {}

--[[----------------------------------------
    Wiper Control System
    Adds a manual toggle mode for wipers:
      Auto  = wipers follow weather addons (default behavior)
      Manual = wipers toggled with a configurable key (default: T)
------------------------------------------]]

-- State tables indexed by vehicle EntIndex()
local manualWiperStates   = {} -- [vehicleID] = bool
local wiperCooldownTimers = {} -- [vehicleID] = CurTime() of last toggle

local WIPER_COOLDOWN = 0.5

--[[----------------------------------------
    Input — added to door_animations group so it appears under
    "Custom Animations - Controls" alongside animations 1-9
------------------------------------------]]

Glide.AddInputAction( "door_animations", "toggle_wipers", KEY_T )

if CLIENT then
    language.Add( "glide.input.toggle_wipers", "Toggle Wipers" )
end

--[[----------------------------------------
    Network
------------------------------------------]]

if SERVER then
    util.AddNetworkString( "BlackterioWiperToggle" )
end

--[[----------------------------------------
    Toggle logic
------------------------------------------]]

local function ToggleManualWipers( vehicle )
    if not IsValid( vehicle ) then return end

    local vehicleID = vehicle:EntIndex()
    local now       = CurTime()

    local lastTime = wiperCooldownTimers[vehicleID] or 0
    if ( now - lastTime ) < WIPER_COOLDOWN then return end
    wiperCooldownTimers[vehicleID] = now

    -- Update state in the current realm (both server and client update independently)
    manualWiperStates[vehicleID] = not ( manualWiperStates[vehicleID] or false )

    if SERVER then
        net.Start( "BlackterioWiperToggle" )
            net.WriteEntity( vehicle )
            net.WriteBool( manualWiperStates[vehicleID] )
        net.Broadcast()
    end
end

-- Receive server-authoritative state on all clients (including non-driver clients)
if CLIENT then
    net.Receive( "BlackterioWiperToggle", function()
        local vehicle = net.ReadEntity()
        local state   = net.ReadBool()

        if not IsValid( vehicle ) then return end
        manualWiperStates[vehicle:EntIndex()] = state
    end )
end

--[[----------------------------------------
    Input handler (invoked by injected OnSeatInput)
------------------------------------------]]

local function HandleWiperInput( vehicle, seatIndex, action, pressed )
    if not pressed           then return false end
    if not IsValid( vehicle ) then return false end
    if seatIndex ~= 1        then return false end
    if action ~= "toggle_wipers" then return false end

    ToggleManualWipers( vehicle )
    return true
end

--[[----------------------------------------
    Auto-inject wiper_control into every Glide vehicle instance.
    Chains correctly with any prior injection (e.g. Custom Anims).
------------------------------------------]]

local function InjectWiperControl( ent )
    if not IsValid( ent )     then return end
    if not ent.IsGlideVehicle then return end

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
        if action == "toggle_wipers" then
            return HandleWiperInput( self, seatIndex, action, pressed )
        end
        if origOnSeatInput then
            return origOnSeatInput( self, seatIndex, action, pressed )
        end
        return false
    end
end

hook.Add( "OnEntityCreated", "BlackterioWiperControlAutoInject", function( ent )
    -- Defer one tick: Initialize() must run first so ent.IsGlideVehicle is set
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        InjectWiperControl( ent )
    end )
end )

--[[----------------------------------------
    State cleanup on vehicle removal
------------------------------------------]]

hook.Add( "EntityRemoved", "BlackterioWiperControlCleanup", function( ent )
    if IsValid( ent ) and ent.IsGlideVehicle then
        local id = ent:EntIndex()
        manualWiperStates[id]   = nil
        wiperCooldownTimers[id] = nil
    end
end )

--[[----------------------------------------
    Public API — consumed by blackterio_extra_functions.lua
------------------------------------------]]

-- Returns true when the local client has Manual Mode enabled.
-- Always returns false on the server (server never renders animations).
function BlackterioExtraFunctions:IsWiperManualMode()
    if not CLIENT then return false end
    local cvar = GetConVar( "blackterio_wipers_mode" )
    return cvar ~= nil and cvar:GetBool()
end

-- Returns the current manual wiper active-state for a vehicle.
function BlackterioExtraFunctions:GetManualWiperState( vehicleID )
    return manualWiperStates[vehicleID] or false
end

-- Returns whether wiper sounds are enabled for the local client.
-- Always returns true on the server (sound emission is neutral server-side).
function BlackterioExtraFunctions:IsWiperSoundEnabled()
    if not CLIENT then return true end
    local cvar = GetConVar( "blackterio_wipers_sound" )
    return cvar == nil or cvar:GetBool()
end
