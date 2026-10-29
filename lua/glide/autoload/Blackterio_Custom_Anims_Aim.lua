-- Location of this file: lua/glide/autoload/

--[[----------------------------------------
    Aim-to-toggle for Custom Animations
    (doors, hood, trunk), Heavily inspired in LVS style

    On foot, aim at an animated part and:
      [E]          closed part -> open it
      [E]          open door   -> enter the vehicle (the door closes behind you)
      [SHIFT]+[E]  open door   -> close it
      [E]          open hood/trunk -> close it
    [E] anywhere else on the vehicle enters it as usual.

    Detection runs on the CLIENT, because only the client animates
    the bones. For each animation, the bones that its pose parameter
    moves are found once per model (pose 0 -> 1 sweep), and the
    model's hitboxes on those bones become the aim targets.

    The SERVER validates the request and calls the same
    ToggleAnimation used by the keybinds: one bitmask, one cooldown,
    one set of sounds for both paths.

    Vehicle config (all optional):
      GetAnimationConfig().aimToggle = false   -> vehicle opted out
      GetAdvancedAnimationConfig() entry:
        aimToggle = false  -> this part can't be aimed at
                              (default: true, false if isDoor == false)
        aimEnter  = bool   -> [E] on this part while open enters the vehicle
                              (default: the name contains "door")

    Aim-to-sit (off by default):
      GetAnimationConfig().aimToSit = true -> aim at a seat and press [E]
      to sit in it (driver or passenger). Seats are invisible in Glide,
      so a fixed box around each seat is the aim target. If a door and a
      seat are both under the crosshair, the closest one wins.

    Click-to-interact (off by default), seated in any seat:
      Hold the free look key (Glide's control, ALT by default), aim at a
      part with the center of the screen and click the left mouse button
      to open/close it. First person only. While a part is aimed the click
      is not sent to Glide (manual gear shifting, weapons).
      GetAnimationConfig().clickToInteract = true -> all the animations
      GetAdvancedAnimationConfig() entry:
        clickToInteract = bool -> this animation only (overrides the above)

      The switches of the extra functions can be clicked too (driver's seat
      only), each one off by default. Set them in ENT:GetExtraFunctionsConfig:
        ignitionKeyClick -> click starts / stops the engine
        lightSwitchClick -> click cycles the headlights
        wiperSwitchClick -> click turns the wipers on / off
        turnStalkClick   -> left click: left signal, right click: right signal
        hornClick        -> the horn sounds while the click is held
        handbrakeClick   -> click applies / releases the parking brake
      The click doesn't move the pose parameters (the extra functions animate
      them from the real state): it changes that state with the same Glide
      actions the keys use.
------------------------------------------]]

BlackterioCustomAnims = BlackterioCustomAnims or {}

local NET_AIM   = "blackterio_anim_aim"
local NET_EXIT  = "blackterio_anim_exit"
local NET_SEAT  = "blackterio_seat_aim"
local NET_CLICK = "blackterio_anim_click"
local USE_RANGE = 90

-- Aim box of a seat in the seat's local space (a seated player faces +Y):
-- cushion and backrest of a typical seat
local SEAT_MINS = Vector( -11, -11, 0 )
local SEAT_MAXS = Vector( 11, 19, 38 )

local function GetOverride( config, animName )
    return config.animOverrides and config.animOverrides[animName]
end

local function IsAimEligible( config, animIndex )
    if config.aimToggle == false then return false end

    local animName = config.names[animIndex]
    if not animName then return false end

    local override = GetOverride( config, animName )
    if override and override.aimToggle ~= nil then
        return override.aimToggle
    end

    return not ( override and override.isDoor == false )
end

local function IsAimEnter( config, animIndex )
    local animName = config.names[animIndex]
    if not animName then return false end

    local override = GetOverride( config, animName )
    if override and override.aimEnter ~= nil then
        return override.aimEnter
    end

    return string.find( string.lower( animName ), "door", 1, true ) ~= nil
end

-- Whether the door closes by itself after a player enters through it.
-- Per animation first, then the vehicle-wide value, default true.
local function ClosesOnEnter( config, animIndex )
    local override = GetOverride( config, config.names[animIndex] )
    if override and override.closesOnEnter ~= nil then
        return override.closesOnEnter
    end

    return config.closesOnEnter ~= false
end

-- Whether a seated player can click this animation. Per animation first,
-- then the vehicle-wide value, default false.
local function IsClickEligible( config, animIndex )
    local animName = config.names[animIndex]
    if not animName then return false end

    local override = GetOverride( config, animName )
    if override and override.clickToInteract ~= nil then
        return override.clickToInteract
    end

    return config.clickToInteract == true
end

-- Switches of the extra functions: click targets after the 9 animations.
--   flag    = config key that turns the click on
--   feature = config key of the function itself (its pose parameter has to be animated)
--   pose    = key of config.poseParameters with the pose that moves the switch
--   action  = Glide input action to tap (the others are handled in PressSwitch)
local SWITCH_KEY, SWITCH_LIGHTS, SWITCH_WIPERS, SWITCH_STALK, SWITCH_HORN, SWITCH_HANDBRAKE = 10, 11, 12, 13, 14, 15
local SWITCH_FIRST, SWITCH_LAST = SWITCH_KEY, SWITCH_HANDBRAKE

local SWITCHES = {
    [SWITCH_KEY]       = { flag = "ignitionKeyClick", feature = "ignitionKey", pose = "ignitionKey" },
    [SWITCH_LIGHTS]    = { flag = "lightSwitchClick", feature = "lightSwitch", pose = "lightSwitch", action = "headlights" },
    [SWITCH_WIPERS]    = { flag = "wiperSwitchClick", feature = "wiperSwitch", pose = "wiperSwitch", action = "toggle_wipers" },
    [SWITCH_STALK]     = { flag = "turnStalkClick", feature = "turnStalk", pose = "turnStalk" },
    [SWITCH_HORN]      = { flag = "hornClick", feature = "horn", pose = "horn" },
    [SWITCH_HANDBRAKE] = { flag = "handbrakeClick", feature = "handbrake", pose = "handbrake" },
}

-- The config the vehicle gives to the extra functions (nil if it has none)
local function GetExtraConfig( vehicle )
    if vehicle.HasExtraFunctions == false or not vehicle.GetExtraFunctionsConfig then return nil end

    return vehicle:GetExtraFunctionsConfig()
end

local function IsSwitchEligible( extraConfig, id )
    local switch = SWITCHES[id]

    return switch ~= nil and extraConfig ~= nil and extraConfig[switch.flag] == true and extraConfig[switch.feature] == true
end

--[[----------------------------------------
    SERVER: validate and apply
------------------------------------------]]

if SERVER then
    util.AddNetworkString( NET_AIM )

    local REQUEST_INTERVAL = 0.15
    local SERVER_RANGE     = USE_RANGE * 2          -- lenient
    local BOX_PADDING      = Vector( 48, 48, 48 )   -- open doors stick out of the chassis box
    local CLOSE_RETRY_DELAY = 0.55                  -- a bit over the toggle cooldown (0.5 s, Blackterio_Custom_Anims.lua)

    -- Glide's vehicle lock (same rule Glide uses to let players in) and
    -- the "Glide // Car Keys" lock (NWBool "CarKeys_Locked": nobody gets in)
    local function IsLockedFor( ply, vehicle )
        if ( vehicle:GetIsLocked() and not Glide.CanEnterLockedVehicle( ply, vehicle ) )
            or vehicle:GetNWBool( "CarKeys_Locked", false ) then
            ply:EmitSound( "doors/latchlocked2.wav", 50, 100, 1.0, 6, 0, 0 )
            return true
        end

        return false
    end

    net.Receive( NET_AIM, function( _, ply )
        if not IsValid( ply ) or not ply:Alive() or ply:InVehicle() then return end

        local now = CurTime()
        if ( ply.bcaNextAimRequest or 0 ) > now then return end
        ply.bcaNextAimRequest = now + REQUEST_INTERVAL

        local vehicle   = net.ReadEntity()
        local animIndex = net.ReadUInt( 4 )
        local wantEnter = net.ReadBool()
        local doorPos   = wantEnter and net.ReadVector() or nil

        -- GetAnimationConfig check too: other addons' entities may define an
        -- IsGlideVehicle *method* (e.g. the Car Keys SWEPs), which is truthy
        if not IsValid( vehicle ) or not vehicle.IsGlideVehicle or not vehicle.GetAnimationConfig then return end
        if not BlackterioCustomAnims.GetConfig or not BlackterioCustomAnims.ToggleAnimation then return end

        local config = BlackterioCustomAnims.GetConfig( vehicle )
        if not config or animIndex < 1 or animIndex > config.count then return end
        if not IsAimEligible( config, animIndex ) then return end

        -- The player must be in reach and aiming at the vehicle
        local hit = util.IntersectRayWithOBB( ply:GetShootPos(), ply:GetAimVector() * SERVER_RANGE,
            vehicle:GetPos(), vehicle:GetAngles(), vehicle:OBBMins() - BOX_PADDING, vehicle:OBBMaxs() + BOX_PADDING )
        if not hit then return end

        if IsLockedFor( ply, vehicle ) then return end

        if not wantEnter then
            BlackterioCustomAnims.ToggleAnimation( vehicle, animIndex )
            return
        end

        if not IsAimEnter( config, animIndex ) then return end
        if not BlackterioCustomAnims.GetAnimationState( vehicle, animIndex ) then return end

        -- Enter the free seat closest to the open door (not to the player),
        -- after checking the client-sent point is in reach and on the vehicle
        if not doorPos or doorPos:Distance( ply:GetShootPos() ) > SERVER_RANGE then return end
        if not vehicle:WorldToLocal( doorPos ):WithinAABox( vehicle:OBBMins() - BOX_PADDING, vehicle:OBBMaxs() + BOX_PADDING ) then return end

        local seat = vehicle:GetClosestAvailableSeat( doorPos )
        if not seat then return end

        Glide.EnterVehicleSeat( ply, vehicle, seat )

        -- Close the door behind the player
        if ClosesOnEnter( config, animIndex ) and ply:InVehicle() and ply:GetVehicle() == seat
            and BlackterioCustomAnims.GetAnimationState( vehicle, animIndex ) then
            BlackterioCustomAnims.ToggleAnimation( vehicle, animIndex )

            -- Opened less than the toggle cooldown ago: the close was blocked.
            -- Retry once the cooldown is over, or the door stays open for good.
            if BlackterioCustomAnims.GetAnimationState( vehicle, animIndex ) then
                timer.Simple( CLOSE_RETRY_DELAY, function()
                    if IsValid( vehicle ) and BlackterioCustomAnims.GetAnimationState( vehicle, animIndex ) then
                        BlackterioCustomAnims.ToggleAnimation( vehicle, animIndex )
                    end
                end )
            end
        end
    end )

    -- Aim-to-sit: enter the seat the player is aiming at
    util.AddNetworkString( NET_SEAT )

    net.Receive( NET_SEAT, function( _, ply )
        if not IsValid( ply ) or not ply:Alive() or ply:InVehicle() then return end

        local now = CurTime()
        if ( ply.bcaNextAimRequest or 0 ) > now then return end
        ply.bcaNextAimRequest = now + REQUEST_INTERVAL

        local vehicle = net.ReadEntity()
        local seat    = net.ReadEntity()

        if not IsValid( vehicle ) or not vehicle.IsGlideVehicle or not vehicle.GetAnimationConfig then return end
        if not IsValid( seat ) or not seat.GlideSeatIndex or seat:GetParent() ~= vehicle then return end
        if not BlackterioCustomAnims.GetConfig then return end

        local config = BlackterioCustomAnims.GetConfig( vehicle )
        if not config or not config.aimToSit then return end

        -- In reach and free
        if seat:GetPos():Distance( ply:GetShootPos() ) > SERVER_RANGE then return end
        if IsValid( seat:GetDriver() ) then return end

        if IsLockedFor( ply, vehicle ) then return end

        Glide.EnterVehicleSeat( ply, vehicle, seat )
    end )

    --[[
        Click-to-interact: the seated player's client reports which part is
        under the crosshair (while the free look key is held), the click
        itself is read here, so it can also be kept away from Glide.
        Targets 1-9 are animations, SWITCH_FIRST-SWITCH_LAST the switches
        of the extra functions (driver's seat only, like their Glide actions).
    ]]
    util.AddNetworkString( NET_CLICK )

    local SWITCH_COOLDOWN = 0.25

    -- The check Glide runs on a real key press (other addons can veto the action)
    local function CanInput( ply, vehicle, action, pressed )
        return hook.Run( "Glide_CanPlayerVehicleInput", ply, vehicle, action, pressed ) ~= false
    end

    -- Input of the driver's seat, as if the key was pressed or released: the vehicle's
    -- OnSeatInput (and hold actions) see it. IsClickBlocking skips it (the action could be bound to the mouse)
    local function SendInput( vehicle, action, pressed )
        vehicle.bcaSyntheticInput = true
        vehicle:SetInputBool( 1, action, pressed )
        vehicle.bcaSyntheticInput = nil
    end

    local function TapAction( ply, vehicle, action )
        if not CanInput( ply, vehicle, action, true ) then return end

        SendInput( vehicle, action, true )
        SendInput( vehicle, action, false )
    end

    local function ReleaseHorn( ply )
        local vehicle = ply.bcaHornVehicle
        ply.bcaHornVehicle = nil

        if IsValid( vehicle ) then
            SendInput( vehicle, "horn", false )
        end
    end

    local function PressSwitch( ply, vehicle, id, button )
        if id == SWITCH_HORN then
            -- Sounds until the click is released (PlayerButtonUp), the crosshair leaves or the player exits
            if button == MOUSE_LEFT and not ply.bcaHornVehicle and CanInput( ply, vehicle, "horn", true ) then
                ply.bcaHornVehicle = vehicle
                SendInput( vehicle, "horn", true )
            end

            return
        end

        -- Only the turn stalk uses the right button
        if button ~= MOUSE_LEFT and id ~= SWITCH_STALK then return end

        local now = CurTime()
        local nextTimes = vehicle.bcaSwitchNext

        if not nextTimes then
            nextTimes = {}
            vehicle.bcaSwitchNext = nextTimes
        end

        if ( nextTimes[id] or 0 ) > now then return end
        nextTimes[id] = now + SWITCH_COOLDOWN

        if id == SWITCH_KEY then
            if CanInput( ply, vehicle, "toggle_engine", true ) then
                local state = vehicle:GetEngineState()

                -- 1 starting and 2 running stop; 0 off and 3 shutting down start
                if state == 1 or state == 2 then
                    vehicle:TurnOff()
                else
                    vehicle:TurnOn()
                end
            end

        elseif id == SWITCH_STALK then
            TapAction( ply, vehicle, button == MOUSE_LEFT and "signal_left" or "signal_right" )

        elseif id == SWITCH_HANDBRAKE then
            -- Latched: Glide resets the driver's inputs on exit, which releases it
            local apply = not vehicle:GetInputBool( 1, "handbrake" )

            if CanInput( ply, vehicle, "handbrake", apply ) then
                SendInput( vehicle, "handbrake", apply )
            end

        else
            TapAction( ply, vehicle, SWITCHES[id].action )
        end
    end

    net.Receive( NET_CLICK, function( _, ply )
        local vehicle   = net.ReadEntity()
        local animIndex = net.ReadUInt( 5 )

        if not IsValid( ply ) then return end

        ply.bcaClickTarget = nil
        ReleaseHorn( ply )   -- the crosshair left the horn
        if animIndex == 0 then return end   -- the crosshair left the part

        if not ply:Alive() or not IsValid( vehicle ) or not vehicle.IsGlideVehicle then return end
        if ply:GlideGetVehicle() ~= vehicle then return end

        if animIndex >= SWITCH_FIRST then
            if ply:GlideGetSeatIndex() ~= 1 then return end
            if not IsSwitchEligible( GetExtraConfig( vehicle ), animIndex ) then return end
        else
            if not vehicle.GetAnimationConfig or not BlackterioCustomAnims.GetConfig then return end

            local config = BlackterioCustomAnims.GetConfig( vehicle )
            if not config or animIndex > config.count then return end
            if not IsClickEligible( config, animIndex ) then return end
        end

        ply.bcaClickTarget = { vehicle = vehicle, animIndex = animIndex }
    end )

    hook.Add( "PlayerButtonDown", "BlackterioCustomAnims.ClickToggle", function( ply, button )
        if button ~= MOUSE_LEFT and button ~= MOUSE_RIGHT then return end

        local target = ply.bcaClickTarget
        if not target then return end

        if not IsValid( target.vehicle ) or ply:GlideGetVehicle() ~= target.vehicle then
            ply.bcaClickTarget = nil
            return
        end

        if target.animIndex >= SWITCH_FIRST then
            PressSwitch( ply, target.vehicle, target.animIndex, button )
        elseif button == MOUSE_LEFT then
            BlackterioCustomAnims.ToggleAnimation( target.vehicle, target.animIndex )
        end
    end )

    hook.Add( "PlayerButtonUp", "BlackterioCustomAnims.ClickRelease", function( ply, button )
        if button == MOUSE_LEFT and ply.bcaHornVehicle then
            ReleaseHorn( ply )
        end
    end )

    hook.Add( "Glide_OnExitVehicle", "BlackterioCustomAnims.ClickClear", function( ply )
        ply.bcaClickTarget = nil
        ReleaseHorn( ply )
    end )

    hook.Add( "PlayerDisconnected", "BlackterioCustomAnims.ClickClear", ReleaseHorn )

    -- Used by the OnSeatInput injected in Blackterio_Custom_Anims.lua (and in
    -- Blackterio_Vehicle_Controls.lua for vehicles without animations): while
    -- a seated player aims at a part, the Glide actions on the mouse button
    -- that clicks it (manual gear shifting, weapons) don't fire. The left
    -- button clicks everything, the right one only the turn stalk.
    -- Releases always go through.
    function BlackterioCustomAnims.IsClickBlocking( vehicle, seatIndex, action )
        if vehicle.bcaSyntheticInput then return false end   -- the click itself (SendInput)

        local ply = vehicle:GetSeatDriver( seatIndex )
        if not IsValid( ply ) then return false end

        local target = ply.bcaClickTarget
        if not target or target.vehicle ~= vehicle then return false end

        local settings = Glide.playerSettings and Glide.playerSettings[ply]
        if not settings then return false end

        for _, actions in pairs( settings.binds ) do
            local button = actions[action]

            if button == MOUSE_LEFT or ( button == MOUSE_RIGHT and target.animIndex == SWITCH_STALK ) then
                return true
            end
        end

        return false
    end

    --[[
        Open and close the door closest to the exit point when a player
        leaves the vehicle. The server knows the exit point, only the
        client knows where the doors are: server -> client (vehicle, exit
        point), client -> server (closest door), server validates.
    ]]
    util.AddNetworkString( NET_EXIT )

    local EXIT_WINDOW = 2     -- seconds the client has to answer after exiting
    local EXIT_HOLD   = 0.6   -- seconds the door stays open after its opening animation

    hook.Add( "Glide_OnExitVehicle", "BlackterioCustomAnims.ExitDoor", function( ply, vehicle )
        if not IsValid( vehicle ) or not vehicle.GetAnimationConfig then return end

        ply.bcaLastExit = { vehicle = vehicle, time = CurTime() }

        net.Start( NET_EXIT )
        net.WriteEntity( vehicle )
        net.WriteVector( ply:GetPos() )   -- Glide already moved the player to the exit point
        net.Send( ply )
    end )

    net.Receive( NET_EXIT, function( _, ply )
        local vehicle   = net.ReadEntity()
        local animIndex = net.ReadUInt( 4 )

        local last = ply.bcaLastExit
        ply.bcaLastExit = nil   -- one answer per exit

        if not last or last.vehicle ~= vehicle or CurTime() - last.time > EXIT_WINDOW then return end
        if not IsValid( vehicle ) or not ply:Alive() or ply:InVehicle() then return end
        if ply.GlideRagdoll then return end   -- thrown out in a crash
        if not BlackterioCustomAnims.GetConfig or not BlackterioCustomAnims.ToggleAnimation then return end

        local config = BlackterioCustomAnims.GetConfig( vehicle )
        if not config or animIndex < 1 or animIndex > config.count then return end
        if not IsAimEligible( config, animIndex ) or not IsAimEnter( config, animIndex ) then return end
        if BlackterioCustomAnims.GetAnimationState( vehicle, animIndex ) then return end   -- already open

        BlackterioCustomAnims.ToggleAnimation( vehicle, animIndex )
        if not BlackterioCustomAnims.GetAnimationState( vehicle, animIndex ) then return end   -- cooldown

        local override = GetOverride( config, config.names[animIndex] )
        local duration = ( override and override.duration ) or config.duration or 0

        timer.Simple( duration + EXIT_HOLD, function()
            -- Someone may have closed it meanwhile: then there's nothing to do
            if IsValid( vehicle ) and BlackterioCustomAnims.GetAnimationState( vehicle, animIndex ) then
                BlackterioCustomAnims.ToggleAnimation( vehicle, animIndex )
            end
        end )
    end )

    --[[
        Require entering through an open door (server rule).
        Only blocks the plain [E] on the vehicle (Glide's ENT:Use); entering
        through an open door, seat switching and other EnterVehicle calls
        don't go through PlayerUse and keep working.
        Exempt: players in noclip, players who disabled the aim system on
        their client, and vehicles without an enterable door.
    ]]
    local cvarRequireDoor = CreateConVar( "blackterio_aimdoors_require_door", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY },
        "Vehicles with animated doors can only be entered through an open door: 0 = [E] anywhere enters (Glide default), 1 = door required" )

    -- Server-side check: an aimable piece with aimEnter whose pose parameter exists on the model
    local function HasEnterDoor( vehicle, config )
        local cached = vehicle.bcaHasEnterDoor
        if cached ~= nil then return cached end

        local has = false

        for i = 1, config.count do
            local poseName = config.names[i]

            if poseName and IsAimEligible( config, i ) and IsAimEnter( config, i )
                and vehicle:LookupPoseParameter( poseName ) >= 0 then
                has = true
                break
            end
        end

        vehicle.bcaHasEnterDoor = has

        return has
    end

    hook.Add( "PlayerUse", "BlackterioCustomAnims.RequireDoor", function( ply, ent )
        if not cvarRequireDoor:GetBool() then return end
        if not IsValid( ent ) then return end

        local vehicle = ent

        if not ent.IsGlideVehicle then
            -- One of the vehicle's seats
            local parent = ent:GetParent()
            if not ent.GlideSeatIndex or not IsValid( parent ) or not parent.IsGlideVehicle then return end
            vehicle = parent
        end

        if not vehicle.GetAnimationConfig then return end
        if ply:GetMoveType() == MOVETYPE_NOCLIP then return end
        if ply:GetInfoNum( "blackterio_aimdoors_enable", 1 ) == 0 then return end
        if not BlackterioCustomAnims.GetConfig then return end

        local config = BlackterioCustomAnims.GetConfig( vehicle )
        if not config or config.aimToggle == false then return end
        if not HasEnterDoor( vehicle, config ) then return end

        return false
    end )

    return
end

--[[----------------------------------------
    CLIENT: part map (pose parameter -> hitboxes)
------------------------------------------]]

local SCAN_RADIUS     = 200
local SCAN_INTERVAL   = 0.25
local OCCLUSION_SLACK = 12     -- a closed door's hitbox sits slightly inside the collision hull
local MOVE_EPSILON    = 0.05   -- units
local ANGLE_EPSILON   = 0.1    -- degrees
local NOISE_MARGIN    = 3      -- times a bone's noise that the animation has to move it

local PART_MAP_TRIES = 6      -- builds before the last one is accepted as it is
local PART_MAP_RETRY = 0.25   -- seconds between builds

-- [model|names] -> list of { animIndex, bone, mins, maxs }
local partMapCache = {}

-- [model|names] -> { signature, tries, nextTry } of the build waiting for a second, equal one
local pendingMaps = {}

local function SnapshotBones( vehicle, boneCount )
    vehicle:InvalidateBoneCache()
    vehicle:SetupBones()

    local snap = {}

    for bone = 0, boneCount - 1 do
        local m = vehicle:GetBoneMatrix( bone )
        if m then
            snap[bone] = { m:GetTranslation(), m:GetAngles() }
        end
    end

    return snap
end

-- How far a bone moved between two snapshots, in multiples of the movement epsilons
local function BoneMovement( a, b )
    if not a or not b then return 0 end

    local movement = a[1]:Distance( b[1] ) / MOVE_EPSILON

    for k = 1, 3 do
        movement = math.max( movement, math.abs( math.AngleDifference( a[2][k], b[2][k] ) ) / ANGLE_EPSILON )
    end

    return movement
end

-- isEligible picks the animations that get hitboxes (default: aim-to-toggle)
local function BuildPartMap( vehicle, config, isEligible )
    isEligible = isEligible or IsAimEligible

    local boneCount = vehicle:GetBoneCount() or 0
    if boneCount <= 0 then return nil end

    local set     = vehicle:GetHitboxSet() or 0
    local hbCount = vehicle:GetHitBoxCount( set ) or 0
    local lerp    = vehicle._bcaLerp

    -- Bones moved by each eligible animation
    local movedBy = {}   -- animIndex -> { [bone] = true, n = count }

    for i = 1, config.count do
        local poseName = config.names[i]

        if poseName and isEligible( config, i ) and vehicle:LookupPoseParameter( poseName ) >= 0 then
            -- Each pose is captured twice. A jigglebone keeps moving between captures of the
            -- same pose (noise) and only sometimes gets over the epsilon, so a bone counts as
            -- moved by the animation only if even its smallest closed -> open difference
            -- is well above its noise
            vehicle:SetPoseParameter( poseName, 0 )
            local closed  = SnapshotBones( vehicle, boneCount )
            local closed2 = SnapshotBones( vehicle, boneCount )

            vehicle:SetPoseParameter( poseName, 1 )
            local open  = SnapshotBones( vehicle, boneCount )
            local open2 = SnapshotBones( vehicle, boneCount )

            -- UpdateAnimations writes the real value again next frame anyway
            vehicle:SetPoseParameter( poseName, lerp and lerp.poseValues[i] or 0 )

            if next( closed ) == nil then return nil end   -- bones not set up yet, retry later

            local moved = { n = 0 }

            for bone = 0, boneCount - 1 do
                local noise  = math.max( BoneMovement( closed[bone], closed2[bone] ), BoneMovement( open[bone], open2[bone] ) )
                local signal = math.min(
                    BoneMovement( closed[bone], open[bone] ), BoneMovement( closed[bone], open2[bone] ),
                    BoneMovement( closed2[bone], open[bone] ), BoneMovement( closed2[bone], open2[bone] )
                )

                if signal > 1 and signal > NOISE_MARGIN * noise then
                    moved[bone] = true
                    moved.n = moved.n + 1
                end
            end

            movedBy[i] = moved
        end
    end

    vehicle:InvalidateBoneCache()

    -- Each hitbox goes to the most specific animation that moves its bone
    -- (a mirror on a door belongs to the door; the rear wiper on the
    -- trunk belongs to the trunk unless the wiper itself is aimable).
    local parts = {}
    local hasPart = {}   -- animIndex -> true once one of its hitboxes was found

    for hb = 0, hbCount - 1 do
        local bone = vehicle:GetHitBoxBone( hb, set )

        if bone and bone > 0 then
            local bestIndex, bestCount

            for i, moved in pairs( movedBy ) do
                if moved[bone] and ( not bestCount or moved.n < bestCount ) then
                    bestIndex, bestCount = i, moved.n
                end
            end

            if bestIndex then
                local mins, maxs = vehicle:GetHitBoxBounds( hb, set )

                if mins then
                    parts[#parts + 1] = { animIndex = bestIndex, bone = bone, mins = mins, maxs = maxs }
                    hasPart[bestIndex] = true
                end
            end
        end
    end

    -- A switch whose bones have no hitbox (a key, for example): the box goes around the origin
    -- of the lowest bone it moves (a parent always comes before its children), sized in SizeSwitchParts
    for i, moved in pairs( movedBy ) do
        if i >= SWITCH_FIRST and not hasPart[i] then
            for bone = 1, boneCount - 1 do
                if moved[bone] then
                    parts[#parts + 1] = { animIndex = i, bone = bone, fallback = true }
                    break
                end
            end
        end
    end

    return parts
end

-- Same parts in any order, as a string
local function PartMapSignature( parts )
    local tokens = {}

    for i, part in ipairs( parts ) do
        tokens[i] = part.animIndex .. ":" .. part.bone
    end

    table.sort( tokens )

    return table.concat( tokens, "," )
end

-- Every eligible switch got at least one part
local function SwitchesHaveParts( config, isEligible, parts )
    local hasPart = {}

    for _, part in ipairs( parts ) do
        hasPart[part.animIndex] = true
    end

    for i = SWITCH_FIRST, config.count do
        if config.names[i] and isEligible( config, i ) and not hasPart[i] then return false end
    end

    return true
end

local function GetPartMap( vehicle, config, isEligible, keyPrefix )
    isEligible = isEligible or IsAimEligible

    local key = ( keyPrefix or "" ) .. ( vehicle:GetModel() or "" )

    for i = 1, config.count do
        key = key .. "|" .. tostring( config.names[i] ) .. ( isEligible( config, i ) and "" or "!" )
    end

    local parts = partMapCache[key]
    if parts ~= nil then return parts end

    local pending = pendingMaps[key]
    local now     = RealTime()

    if pending and now < pending.nextTry then return nil end

    parts = BuildPartMap( vehicle, config, isEligible )
    if not parts then return nil end   -- not cached: retry on a later frame

    -- The map is cached once two builds in a row agree and every switch found a part.
    -- A bad build (bones not ready, a jigglebone still settling) would otherwise stick
    -- to the model until the game restarts. After PART_MAP_TRIES the last build is kept.
    local signature = PartMapSignature( parts )
    local tries     = pending and pending.tries + 1 or 1

    if tries >= PART_MAP_TRIES or ( pending and pending.signature == signature and SwitchesHaveParts( config, isEligible, parts ) ) then
        partMapCache[key] = parts
        pendingMaps[key]  = nil

        return parts
    end

    pendingMaps[key] = { signature = signature, tries = tries, nextTry = now + PART_MAP_RETRY }

    return nil
end

-- Returns the aimable parts of a vehicle (also used for debugging/testing).
-- Cached on the entity after the first successful build (false = none), so
-- the per-frame path doesn't rebuild the cache key.
function BlackterioCustomAnims.GetAimPartMap( vehicle )
    if not IsValid( vehicle ) then return nil end

    local parts = vehicle._bcaAimParts
    if parts ~= nil then return parts or nil end

    if not BlackterioCustomAnims.GetConfig then return nil end

    local config = BlackterioCustomAnims.GetConfig( vehicle )

    if not config or config.aimToggle == false then
        vehicle._bcaAimParts = false
        return nil
    end

    parts = GetPartMap( vehicle, config )
    if parts then vehicle._bcaAimParts = parts end   -- nil = bones not ready yet, retry later

    return parts
end

-- The animations and the switches a seated player can click, as one list for the
-- part map: 1-9 are the animations, SWITCH_FIRST-SWITCH_LAST the switches.
-- Cached on the entity (false = nothing to click).
local function GetClickConfig( vehicle )
    local cached = vehicle._bcaClickCfg
    if cached ~= nil then return cached or nil end

    local animConfig  = vehicle.GetAnimationConfig and BlackterioCustomAnims.GetConfig( vehicle )
    local extraConfig = GetExtraConfig( vehicle )

    local config = {
        count           = SWITCH_LAST,
        names           = {},
        animOverrides   = animConfig and animConfig.animOverrides,
        clickToInteract = animConfig and animConfig.clickToInteract,
        extraConfig     = extraConfig
    }

    local any = false

    if animConfig then
        for i = 1, math.min( animConfig.count, SWITCH_FIRST - 1 ) do
            config.names[i] = animConfig.names[i]
            if IsClickEligible( config, i ) then any = true end
        end
    end

    -- Only the switches that can be clicked get a name, that's what makes them eligible
    for id, switch in pairs( SWITCHES ) do
        if IsSwitchEligible( extraConfig, id ) then
            config.names[id] = extraConfig.poseParameters[switch.pose]
            any = true
        end
    end

    vehicle._bcaClickCfg = any and config or false

    return any and config or nil
end

local function IsClickPartEligible( config, animIndex )
    if animIndex >= SWITCH_FIRST then return config.names[animIndex] ~= nil end

    return IsClickEligible( config, animIndex )
end

-- The switches are tiny: grow their hitboxes, or make a box around the bone when it has none.
-- clickSwitchPadding / clickSwitchRadius are the defaults, clickSwitchSizes[feature] overrides them per switch
local function SizeSwitchParts( parts, extraConfig )
    local sizes = extraConfig and extraConfig.clickSwitchSizes
    local sized = {}

    for i, part in ipairs( parts ) do
        if part.animIndex < SWITCH_FIRST then
            sized[i] = part
        else
            local size    = sizes and sizes[SWITCHES[part.animIndex].feature]
            local padding = size and size.padding or extraConfig and extraConfig.clickSwitchPadding or 0.2
            local radius  = size and size.radius or extraConfig and extraConfig.clickSwitchRadius or 1

            if part.fallback then
                local box = Vector( radius, radius, radius )
                sized[i] = { animIndex = part.animIndex, bone = part.bone, mins = -box, maxs = box }
            else
                local grow = Vector( padding, padding, padding )
                sized[i] = { animIndex = part.animIndex, bone = part.bone, mins = part.mins - grow, maxs = part.maxs + grow }
            end
        end
    end

    return sized
end

-- Same for the animations and switches a seated player can click (click-to-interact).
-- It's a separate map: its animations (a window, a blind...) can take
-- hitboxes that the aim-to-toggle map gives to the door.
function BlackterioCustomAnims.GetClickPartMap( vehicle )
    if not IsValid( vehicle ) then return nil end

    local parts = vehicle._bcaClickParts
    if parts ~= nil then return parts or nil end

    if not BlackterioCustomAnims.GetConfig then return nil end

    local config = GetClickConfig( vehicle )

    if not config then
        vehicle._bcaClickParts = false
        return nil
    end

    parts = GetPartMap( vehicle, config, IsClickPartEligible, "click|" )
    if not parts then return nil end   -- bones not ready yet, retry later

    parts = SizeSwitchParts( parts, config.extraConfig )
    vehicle._bcaClickParts = parts

    return parts
end

--[[----------------------------------------
    CLIENT: what is the player aiming at
------------------------------------------]]

local candidates = {}
local nextScan   = 0

local function RefreshCandidates( origin, force )
    local now = RealTime()
    if not force and now < nextScan then return end
    nextScan = now + SCAN_INTERVAL

    table.Empty( candidates )

    for _, ent in ipairs( ents.FindInSphere( origin, SCAN_RADIUS ) ) do
        if ent.IsGlideVehicle and ent.GetAnimationConfig and not ent:IsDormant() then
            candidates[#candidates + 1] = ent
        end
    end
end

-- Closest door part hit by the ray: { vehicle, part, matrix }, distance
local function TraceParts( start, delta )
    local best, bestDist

    for _, vehicle in ipairs( candidates ) do
        if IsValid( vehicle ) then
            local parts = BlackterioCustomAnims.GetAimPartMap( vehicle )

            if parts then
                for _, part in ipairs( parts ) do
                    local m = vehicle:GetBoneMatrix( part.bone )

                    if m then
                        local hit = util.IntersectRayWithOBB( start, delta, m:GetTranslation(), m:GetAngles(), part.mins, part.maxs )

                        if hit then
                            local dist = start:Distance( hit )

                            if not bestDist or dist < bestDist then
                                best, bestDist = { vehicle = vehicle, part = part, matrix = m }, dist
                            end
                        end
                    end
                end
            end
        end
    end

    return best, bestDist
end

-- Closest seat of an aimToSit vehicle hit by the ray: { vehicle, seat }, distance
local function TraceSeats( start, delta )
    local best, bestDist

    for _, vehicle in ipairs( candidates ) do
        if IsValid( vehicle ) and vehicle.seats then
            local config = BlackterioCustomAnims.GetConfig( vehicle )

            if config and config.aimToSit then
                for _, seat in ipairs( vehicle.seats ) do
                    if IsValid( seat ) then
                        local hit = util.IntersectRayWithOBB( start, delta, seat:GetPos(), seat:GetAngles(), SEAT_MINS, SEAT_MAXS )

                        if hit then
                            local dist = start:Distance( hit )

                            if not bestDist or dist < bestDist then
                                best, bestDist = { vehicle = vehicle, seat = seat }, dist
                            end
                        end
                    end
                end
            end
        end
    end

    return best, bestDist
end

-- Returns { vehicle, animIndex, pos, open, enter } for a door part,
-- { vehicle, seat, pos, occupied } for a seat, or nil
local function FindAimed( ply, force, doors, seats )
    local start = ply:GetShootPos()
    local delta = ply:GetAimVector() * USE_RANGE

    RefreshCandidates( start, force )

    local best, bestDist

    if doors then
        best, bestDist = TraceParts( start, delta )
    end

    if seats then
        local seatHit, seatDist = TraceSeats( start, delta )

        if seatHit and ( not bestDist or seatDist < bestDist ) then
            best, bestDist = seatHit, seatDist
        end
    end

    if not best then return nil end

    -- Occlusion: something (world, another prop, the car's own body
    -- when aiming at the far side) is clearly in front of the part
    local tr = util.TraceLine( { start = start, endpos = start + delta, filter = ply } )
    if tr.Hit and bestDist > tr.Fraction * USE_RANGE + OCCLUSION_SLACK then return nil end

    local vehicle = best.vehicle
    local seat    = best.seat

    if seat then
        return {
            vehicle  = vehicle,
            seat     = seat,
            pos      = LocalToWorld( ( SEAT_MINS + SEAT_MAXS ) * 0.5, angle_zero, seat:GetPos(), seat:GetAngles() ),
            occupied = IsValid( seat:GetDriver() )
        }
    end

    local part   = best.part
    local config = BlackterioCustomAnims.GetConfig( vehicle )

    return {
        vehicle   = vehicle,
        animIndex = part.animIndex,
        pos       = LocalToWorld( ( part.mins + part.maxs ) * 0.5, angle_zero, best.matrix:GetTranslation(), best.matrix:GetAngles() ),
        open      = BlackterioCustomAnims.GetAnimationState( vehicle, part.animIndex ),
        enter     = IsAimEnter( config, part.animIndex )
    }
end

function BlackterioCustomAnims.FindAimedPart( ply, force )
    return FindAimed( ply, force, true, false )
end

-- Per-player opt-outs (blackterio_aimdoors_enable / blackterio_aimseats_enable,
-- Glide config panel). Disabled: [E] is never intercepted for doors / seats.
local cvarEnable, cvarSeatEnable

local function IsAimEnabled()
    cvarEnable = cvarEnable or GetConVar( "blackterio_aimdoors_enable" )
    return not cvarEnable or cvarEnable:GetBool()
end

local function IsSeatAimEnabled()
    cvarSeatEnable = cvarSeatEnable or GetConVar( "blackterio_aimseats_enable" )
    return not cvarSeatEnable or cvarSeatEnable:GetBool()
end

--[[----------------------------------------
    CLIENT: door to animate when exiting
------------------------------------------]]

local EXIT_MAX_DIST   = 120                  -- only doors right next to the exit point
local EXIT_REF_OFFSET = Vector( 0, 0, 36 )  -- exit point is at the feet; measure from the body

net.Receive( NET_EXIT, function()
    local vehicle = net.ReadEntity()
    local exitPos = net.ReadVector()

    if not IsValid( vehicle ) or not IsAimEnabled() then return end
    if not BlackterioCustomAnims.GetConfig then return end

    local config = BlackterioCustomAnims.GetConfig( vehicle )
    local parts  = BlackterioCustomAnims.GetAimPartMap( vehicle )
    if not config or not parts then return end

    local ref = exitPos + EXIT_REF_OFFSET
    local bestIndex, bestDist

    for _, part in ipairs( parts ) do
        if IsAimEnter( config, part.animIndex ) then
            local m = vehicle:GetBoneMatrix( part.bone )

            if m then
                local center = LocalToWorld( ( part.mins + part.maxs ) * 0.5, angle_zero, m:GetTranslation(), m:GetAngles() )
                local dist = ref:Distance( center )

                if dist <= EXIT_MAX_DIST and ( not bestDist or dist < bestDist ) then
                    bestIndex, bestDist = part.animIndex, dist
                end
            end
        end
    end

    if not bestIndex then return end

    net.Start( NET_EXIT )
    net.WriteEntity( vehicle )
    net.WriteUInt( bestIndex, 4 )
    net.SendToServer()
end )

--[[----------------------------------------
    CLIENT: input
------------------------------------------]]

hook.Add( "PlayerBindPress", "BlackterioCustomAnims.AimUse", function( ply, bind, pressed )
    if not pressed then return end
    if not string.find( bind, "+use", 1, true ) then return end
    if ply:InVehicle() then return end

    local doors, seats = IsAimEnabled(), IsSeatAimEnabled()
    if not doors and not seats then return end

    local aimed = FindAimed( ply, true, doors, seats )
    if not aimed then return end   -- normal +use: Glide enters the vehicle

    if aimed.seat then
        -- Occupied: swallow the +use, so Glide doesn't put the player in another seat
        if not aimed.occupied then
            net.Start( NET_SEAT )
            net.WriteEntity( aimed.vehicle )
            net.WriteEntity( aimed.seat )
            net.SendToServer()
        end

        return true
    end

    local wantEnter = aimed.enter and aimed.open and not ply:KeyDown( IN_SPEED )

    net.Start( NET_AIM )
    net.WriteEntity( aimed.vehicle )
    net.WriteUInt( aimed.animIndex, 4 )
    net.WriteBool( wantEnter )
    if wantEnter then net.WriteVector( aimed.pos ) end   -- open door center: picks the seat
    net.SendToServer()

    return true   -- the server never sees this +use, so Glide won't also enter
end )

--[[----------------------------------------
    CLIENT: hint and developer boxes
------------------------------------------]]

local cvarHint, cvarSeatHint
local cvarDeveloper = GetConVar( "developer" )
local currentAim

local function KeyName( bind, fallback )
    return string.upper( input.LookupBinding( bind ) or fallback )
end

hook.Add( "Think", "BlackterioCustomAnims.AimTrack", function()
    cvarHint     = cvarHint or GetConVar( "blackterio_aimdoors_hint" )
    cvarSeatHint = cvarSeatHint or GetConVar( "blackterio_aimseats_hint" )

    local doors, seats = IsAimEnabled(), IsSeatAimEnabled()
    local doorHint = doors and cvarHint and cvarHint:GetBool()
    local seatHint = seats and cvarSeatHint and cvarSeatHint:GetBool()
    local wantDev  = cvarDeveloper:GetInt() > 0

    currentAim = nil
    if not doors and not seats then return end
    if not doorHint and not seatHint and not wantDev then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) or ply:InVehicle() or not ply:Alive() then return end

    currentAim = FindAimed( ply, false, doors, seats )

    if currentAim then
        if currentAim.seat then
            currentAim.hint = seatHint and true or false
        else
            currentAim.hint = doorHint and true or false
        end
    end
end )

local COLOR_SHADOW        = Color( 0, 0, 0, 150 )
local COLOR_FRIEND_LOCKED = Color( 255, 210, 60 )   -- Glide lock: owner and friends can still open
local COLOR_LOCKED        = Color( 255, 70, 70 )    -- "Glide // Car Keys" lock: nobody can open
local COLOR_OCCUPIED      = Color( 170, 170, 170 )

-- Texts: resource/localization/<lang>/blackterio_extra_functions.properties
local GetPhrase = language.GetPhrase

local function DrawHintLine( text, x, y, color )
    draw.DrawText( text, "TargetIDSmall", x + 1, y + 1, COLOR_SHADOW, TEXT_ALIGN_CENTER )
    draw.DrawText( text, "TargetIDSmall", x, y, color, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "BlackterioCustomAnims.AimHint", function()
    -- The vehicle can be removed between Think (where currentAim is set) and this hook
    if not currentAim or not IsValid( currentAim.vehicle ) or not currentAim.hint then return end

    local screen = currentAim.pos:ToScreen()
    if not screen.visible then return end

    local useKey = KeyName( "+use", "E" )
    local text

    if currentAim.seat then
        if currentAim.occupied then
            DrawHintLine( GetPhrase( "blackterio.aim.occupied" ), screen.x, screen.y, COLOR_OCCUPIED )
            return
        end

        text = string.format( GetPhrase( "blackterio.aim.sit" ), useKey )
    elseif not currentAim.open then
        text = string.format( GetPhrase( "blackterio.aim.open" ), useKey )
    elseif currentAim.enter then
        text = string.format( GetPhrase( "blackterio.aim.enter" ), useKey ) .. "\n"
            .. string.format( GetPhrase( "blackterio.aim.close_shift" ), KeyName( "+speed", "SHIFT" ), useKey )
    else
        text = string.format( GetPhrase( "blackterio.aim.close" ), useKey )
    end

    DrawHintLine( text, screen.x, screen.y, color_white )

    -- Lock states below the action, each on its own line and color
    surface.SetFont( "TargetIDSmall" )
    local _, lineHeight = surface.GetTextSize( "A" )
    local y = screen.y + lineHeight * ( select( 2, string.gsub( text, "\n", "" ) ) + 1 )
    local vehicle = currentAim.vehicle

    if vehicle:GetIsLocked() then
        DrawHintLine( GetPhrase( "blackterio.aim.friend_locked" ), screen.x, y, COLOR_FRIEND_LOCKED )
        y = y + lineHeight
    end

    if vehicle:GetNWBool( "CarKeys_Locked", false ) then
        DrawHintLine( GetPhrase( "blackterio.aim.locked" ), screen.x, y, COLOR_LOCKED )
    end
end )

local COLOR_PART  = Color( 255, 60, 60 )
local COLOR_AIMED = Color( 60, 255, 60 )
local COLOR_SEAT  = Color( 255, 255, 255 )

-- Box around the aimed seat (seats are invisible in Glide, so no outline)
hook.Add( "PostDrawTranslucentRenderables", "BlackterioCustomAnims.AimSeatBox", function( depth, skybox )
    if depth or skybox then return end
    if not currentAim or not currentAim.seat or not currentAim.hint then return end

    local seat = currentAim.seat
    if not IsValid( seat ) then return end

    render.DrawWireframeBox( seat:GetPos(), seat:GetAngles(), SEAT_MINS, SEAT_MAXS, currentAim.occupied and COLOR_OCCUPIED or COLOR_SEAT, true )
end )

hook.Add( "PostDrawTranslucentRenderables", "BlackterioCustomAnims.AimDebug", function( depth, skybox )
    if depth or skybox then return end
    if cvarDeveloper:GetInt() < 1 then return end

    local doors, seats = IsAimEnabled(), IsSeatAimEnabled()

    for _, vehicle in ipairs( candidates ) do
        if IsValid( vehicle ) and seats and vehicle.seats then
            local config = BlackterioCustomAnims.GetConfig( vehicle )

            if config and config.aimToSit then
                for _, seat in ipairs( vehicle.seats ) do
                    if IsValid( seat ) then
                        local aimed = currentAim and currentAim.seat == seat
                        render.DrawWireframeBox( seat:GetPos(), seat:GetAngles(), SEAT_MINS, SEAT_MAXS, aimed and COLOR_AIMED or COLOR_PART, true )
                    end
                end
            end
        end

        if IsValid( vehicle ) and doors then
            local parts = BlackterioCustomAnims.GetAimPartMap( vehicle )

            if parts then
                for _, part in ipairs( parts ) do
                    local m = vehicle:GetBoneMatrix( part.bone )

                    if m then
                        local aimed = currentAim and currentAim.vehicle == vehicle and currentAim.animIndex == part.animIndex
                        render.DrawWireframeBox( m:GetTranslation(), m:GetAngles(), part.mins, part.maxs, aimed and COLOR_AIMED or COLOR_PART, true )
                    end
                end
            end
        end
    end
end )

--[[----------------------------------------
    CLIENT: click to interact (seated)
------------------------------------------]]

local CLICK_RANGE         = 300   -- from the driver's seat of a coach to its middle door
local CLICK_SEND_INTERVAL = 0.1   -- seconds between reports to the server

local cvarClickEnable, cvarClickHint
local clickHeld = false   -- free look key down, first person, a clickable vehicle
local clickAim            -- { vehicle, animIndex, open } while the crosshair is on a part
local clickVehicle, clickParts   -- vehicle and parts that can be clicked while clickHeld (developer boxes)
local clickSent = 0       -- animation last reported to the server (0 = none)
local nextClickSend = 0

-- The free look key of Glide's controls (ALT by default)
local function IsClickKeyDown()
    local binds = Glide.Config and Glide.Config.binds
    local key = binds and binds.general_controls and binds.general_controls.free_look

    return key ~= nil and key > KEY_NONE and input.IsKeyDown( key )
end

-- Closest clickable part under the center of the screen: { vehicle, animIndex, open }
-- (the switches only count for the driver)
local function FindClickAimed( vehicle, parts, isDriver )
    local start = EyePos()
    local delta = EyeAngles():Forward() * CLICK_RANGE
    local best, bestDist

    for _, part in ipairs( parts ) do
        local m = ( isDriver or part.animIndex < SWITCH_FIRST ) and vehicle:GetBoneMatrix( part.bone )

        if m then
            local hit = util.IntersectRayWithOBB( start, delta, m:GetTranslation(), m:GetAngles(), part.mins, part.maxs )

            if hit then
                local dist = start:Distance( hit )

                if not bestDist or dist < bestDist then
                    best, bestDist = part, dist
                end
            end
        end
    end

    if not best then return nil end

    -- Only the world blocks the view: the vehicle's own hull is around the player
    local tr = util.TraceLine( { start = start, endpos = start + delta, mask = MASK_SOLID_BRUSHONLY } )
    if tr.Hit and bestDist > tr.Fraction * CLICK_RANGE + OCCLUSION_SLACK then return nil end

    return {
        vehicle   = vehicle,
        animIndex = best.animIndex,
        open      = best.animIndex < SWITCH_FIRST and BlackterioCustomAnims.GetAnimationState( vehicle, best.animIndex )
    }
end

hook.Add( "Think", "BlackterioCustomAnims.ClickTrack", function()
    cvarClickEnable = cvarClickEnable or GetConVar( "blackterio_clickinteract_enable" )

    clickHeld, clickAim = false, nil
    clickVehicle, clickParts = nil, nil

    local ply = LocalPlayer()
    local vehicle = IsValid( ply ) and ply:Alive() and ply:GlideGetVehicle() or NULL
    local inFirstPerson = IsValid( vehicle ) and vehicle.isLocalPlayerInFirstPerson

    if inFirstPerson and ( not cvarClickEnable or cvarClickEnable:GetBool() )
        and IsClickKeyDown() and not vgui.CursorVisible() and not gui.IsGameUIVisible() then

        local parts = ( vehicle.GetAnimationConfig or vehicle.GetExtraFunctionsConfig ) and BlackterioCustomAnims.GetClickPartMap( vehicle )

        if parts then
            clickHeld = true
            clickVehicle, clickParts = vehicle, parts
            clickAim  = FindClickAimed( vehicle, parts, ply:GlideGetSeatIndex() == 1 )
        end
    end

    -- Tell the server when the part under the crosshair changes
    local animIndex = clickAim and clickAim.animIndex or 0

    if animIndex ~= clickSent and RealTime() >= nextClickSend then
        nextClickSend = RealTime() + CLICK_SEND_INTERVAL
        clickSent = animIndex

        net.Start( NET_CLICK )
        net.WriteEntity( vehicle )
        net.WriteUInt( animIndex, 5 )
        net.SendToServer()
    end
end )

-- Phrase of each switch's hint (the key also changes with the engine, the stalk has two)
local SWITCH_PHRASES = {
    [SWITCH_LIGHTS]    = "blackterio.click.headlights",
    [SWITCH_WIPERS]    = "blackterio.click.wipers",
    [SWITCH_HORN]      = "blackterio.click.horn",
    [SWITCH_HANDBRAKE] = "blackterio.click.handbrake"
}

local function GetClickHint( aim, clickKey )
    local id = aim.animIndex

    if id < SWITCH_FIRST then
        return string.format( GetPhrase( aim.open and "blackterio.aim.close" or "blackterio.aim.open" ), clickKey )
    end

    if id == SWITCH_STALK then
        return string.format( GetPhrase( "blackterio.click.signals" ), clickKey, string.upper( input.GetKeyName( MOUSE_RIGHT ) or "MOUSE2" ) )
    end

    if id == SWITCH_KEY then
        local state = IsValid( aim.vehicle ) and aim.vehicle:GetEngineState() or 0

        return string.format( GetPhrase( ( state == 1 or state == 2 ) and "blackterio.click.engine_stop" or "blackterio.click.engine_start" ), clickKey )
    end

    return string.format( GetPhrase( SWITCH_PHRASES[id] ), clickKey )
end

hook.Add( "HUDPaint", "BlackterioCustomAnims.ClickHint", function()
    if not clickHeld then return end

    cvarClickHint = cvarClickHint or GetConVar( "blackterio_clickinteract_hint" )
    if cvarClickHint and not cvarClickHint:GetBool() then return end

    local x, y = ScrW() * 0.5, ScrH() * 0.5

    -- Crosshair: a dot, green while a part is aimed
    surface.SetDrawColor( COLOR_SHADOW )
    surface.DrawRect( x - 3, y - 3, 6, 6 )
    surface.SetDrawColor( clickAim and COLOR_AIMED or color_white )
    surface.DrawRect( x - 2, y - 2, 4, 4 )

    if not clickAim then return end

    local clickKey = string.upper( input.GetKeyName( MOUSE_LEFT ) or "MOUSE1" )
    DrawHintLine( GetClickHint( clickAim, clickKey ), x, y + 12, color_white )
end )

-- developer 1: boxes of everything that can be clicked, the aimed one in green
hook.Add( "PostDrawTranslucentRenderables", "BlackterioCustomAnims.ClickDebug", function( depth, skybox )
    if depth or skybox then return end
    if not clickHeld or not IsValid( clickVehicle ) or cvarDeveloper:GetInt() < 1 then return end

    local isDriver = LocalPlayer():GlideGetSeatIndex() == 1

    for _, part in ipairs( clickParts ) do
        local m = ( isDriver or part.animIndex < SWITCH_FIRST ) and clickVehicle:GetBoneMatrix( part.bone )

        if m then
            local aimed = clickAim and clickAim.animIndex == part.animIndex
            render.DrawWireframeBox( m:GetTranslation(), m:GetAngles(), part.mins, part.maxs, aimed and COLOR_AIMED or COLOR_PART, true )
        end
    end
end )
