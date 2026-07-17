-- Location of this file: lua/glide/autoload/
-- Loaded via Glide's IncludeDir (inside lua/autorun/sh_glide.lua).
BlackterioExtraFunctions = BlackterioExtraFunctions or {}

--[[----------------------------------------
    Wiper Control System
    Adds a manual toggle mode for wipers:
      Auto  = wipers follow weather addons (default behavior)
      Manual = wipers toggled with a configurable key (default: T)

    State lives in NW2 vars on the vehicle, so every client
    (including late joiners) sees the same thing:
      "blackterio_wipers_on"          -> manual wiper toggle state
      "blackterio_wipers_manual_mode" -> the DRIVER's wiper mode
        (read from their blackterio_wipers_mode userinfo ConVar when
        they enter seat 1 and refreshed on every toggle; changing the
        setting mid-drive applies on the next toggle or re-entry)
------------------------------------------]]

local NW_WIPERS_ON   = "blackterio_wipers_on"
local NW_MANUAL_MODE = "blackterio_wipers_manual_mode"

local WIPER_COOLDOWN = 0.5

--[[----------------------------------------
    Input — added to door_animations group so it appears under
    "Custom Animations - Controls" alongside animations 1-9
------------------------------------------]]

-- Guarded registration: safe on autorefresh and independent of which
-- Blackterio autoload file happens to run first.
if not Glide.InputGroups["door_animations"] then
    Glide.SetupInputGroup( "door_animations" )
end
if Glide.InputGroups["door_animations"]["toggle_wipers"] == nil then
    Glide.AddInputAction( "door_animations", "toggle_wipers", KEY_T )
end

if CLIENT then
    language.Add( "glide.input.toggle_wipers", "Toggle Wipers" )
end

--[[----------------------------------------
    Toggle logic (SERVER only — Glide calls
    ENT:OnSeatInput on the server realm)
------------------------------------------]]

if SERVER then

    -- Mirror the driver's wiper mode ConVar onto the vehicle, so all
    -- clients animate using the DRIVER's mode instead of their own.
    local function UpdateDriverMode( vehicle, ply )
        if not IsValid( ply ) then return end
        vehicle:SetNW2Bool( NW_MANUAL_MODE, ply:GetInfoNum( "blackterio_wipers_mode", 0 ) ~= 0 )
    end

    hook.Add( "Glide_OnEnterVehicle", "BlackterioWiperDriverMode", function( ply, vehicle, seatIndex )
        if seatIndex ~= 1 then return end
        if not IsValid( vehicle ) or not vehicle.IsGlideVehicle then return end

        UpdateDriverMode( vehicle, ply )
    end )

    local function ToggleManualWipers( vehicle )
        if not IsValid( vehicle ) then return end

        local now = CurTime()
        if ( now - ( vehicle._bwcLastToggle or 0 ) ) < WIPER_COOLDOWN then return end
        vehicle._bwcLastToggle = now

        vehicle:SetNW2Bool( NW_WIPERS_ON, not vehicle:GetNW2Bool( NW_WIPERS_ON, false ) )

        -- Keep the driver's mode fresh in case they changed the setting while seated
        UpdateDriverMode( vehicle, vehicle:GetDriver() )
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

    BlackterioExtraFunctions._HandleWiperInput = HandleWiperInput
end

--[[----------------------------------------
    Auto-inject wiper_control into every Glide vehicle instance.
    Chains correctly with any prior injection (e.g. Custom Anims).
    Input groups / OnSeatInput only matter on the server realm.
------------------------------------------]]

local function InjectWiperControl( ent )
    if not IsValid( ent )     then return end
    if not ent.IsGlideVehicle then return end

    -- Opt-out: vehicles that explicitly declare they don't use the extra
    -- functions (self.HasExtraFunctions = false in Initialize) don't get
    -- the wiper toggle either. nil/unset still injects, so third-party
    -- Glide vehicles keep working like before.
    if ent.HasExtraFunctions == false then return end

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
            local handler = BlackterioExtraFunctions._HandleWiperInput
            return handler and handler( self, seatIndex, action, pressed ) or false
        end
        if origOnSeatInput then
            return origOnSeatInput( self, seatIndex, action, pressed )
        end
        return false
    end
end

if SERVER then
    hook.Add( "OnEntityCreated", "BlackterioWiperControlAutoInject", function( ent )
        -- Defer one tick: Initialize() must run first so ent.IsGlideVehicle is set
        timer.Simple( 0, function()
            if not IsValid( ent ) then return end
            InjectWiperControl( ent )
        end )
    end )
end

--[[----------------------------------------
    Public API — consumed by blackterio_extra_functions.lua
------------------------------------------]]

-- Returns true when the LOCAL client has Manual Mode enabled.
-- Kept for the settings panel and backwards compatibility; vehicle
-- animations now use GetWiperManualMode (the driver's mode) instead.
function BlackterioExtraFunctions:IsWiperManualMode()
    if not CLIENT then return false end
    local cvar = GetConVar( "blackterio_wipers_mode" )
    return cvar ~= nil and cvar:GetBool()
end

-- Returns the wiper mode that applies to this vehicle (the driver's mode).
function BlackterioExtraFunctions:GetWiperManualMode( vehicle )
    if isnumber( vehicle ) then vehicle = Entity( vehicle ) end
    if not IsValid( vehicle ) then return false end
    return vehicle:GetNW2Bool( NW_MANUAL_MODE, false )
end

-- Returns the current manual wiper active-state for a vehicle.
-- Accepts the vehicle entity (preferred) or its EntIndex (legacy).
function BlackterioExtraFunctions:GetManualWiperState( vehicle )
    if isnumber( vehicle ) then vehicle = Entity( vehicle ) end
    if not IsValid( vehicle ) then return false end
    return vehicle:GetNW2Bool( NW_WIPERS_ON, false )
end

-- Returns whether wiper sounds are enabled for the local client.
-- Always returns true on the server (sound emission is neutral server-side).
function BlackterioExtraFunctions:IsWiperSoundEnabled()
    if not CLIENT then return true end
    local cvar = GetConVar( "blackterio_wipers_sound" )
    return cvar == nil or cvar:GetBool()
end
