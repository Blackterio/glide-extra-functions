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
------------------------------------------]]

BlackterioCustomAnims = BlackterioCustomAnims or {}

local NET_AIM   = "blackterio_anim_aim"
local NET_EXIT  = "blackterio_anim_exit"
local USE_RANGE = 90

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

--[[----------------------------------------
    SERVER: validate and apply
------------------------------------------]]

if SERVER then
    util.AddNetworkString( NET_AIM )

    local REQUEST_INTERVAL = 0.15
    local SERVER_RANGE     = USE_RANGE * 2          -- lenient
    local BOX_PADDING      = Vector( 48, 48, 48 )   -- open doors stick out of the chassis box
    local CLOSE_RETRY_DELAY = 0.55                  -- a bit over the toggle cooldown (0.5 s, Blackterio_Custom_Anims.lua)

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

        -- Respect Glide's vehicle lock (same rule Glide uses to let players in)
        if vehicle:GetIsLocked() and not Glide.CanEnterLockedVehicle( ply, vehicle ) then
            ply:EmitSound( "doors/latchlocked2.wav", 50, 100, 1.0, 6, 0, 0 )
            return
        end

        -- "Glide // Car Keys" lock (NWBool "CarKeys_Locked"): nobody opens anything from outside
        if vehicle:GetNWBool( "CarKeys_Locked", false ) then
            ply:EmitSound( "doors/latchlocked2.wav", 50, 100, 1.0, 6, 0, 0 )
            return
        end

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
        if ply:InVehicle() and ply:GetVehicle() == seat
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

-- [model|names] -> list of { animIndex, bone, mins, maxs }
local partMapCache = {}

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

local function BoneMoved( a, b )
    if not a or not b then return false end
    if a[1]:DistToSqr( b[1] ) > MOVE_EPSILON * MOVE_EPSILON then return true end

    for k = 1, 3 do
        if math.abs( math.AngleDifference( a[2][k], b[2][k] ) ) > ANGLE_EPSILON then return true end
    end

    return false
end

local function BuildPartMap( vehicle, config )
    local boneCount = vehicle:GetBoneCount() or 0
    if boneCount <= 0 then return nil end

    local set     = vehicle:GetHitboxSet() or 0
    local hbCount = vehicle:GetHitBoxCount( set ) or 0
    local lerp    = vehicle._bcaLerp

    -- Bones moved by each eligible animation
    local movedBy = {}   -- animIndex -> { [bone] = true, n = count }

    for i = 1, config.count do
        local poseName = config.names[i]

        if poseName and IsAimEligible( config, i ) and vehicle:LookupPoseParameter( poseName ) >= 0 then
            vehicle:SetPoseParameter( poseName, 0 )
            local closed = SnapshotBones( vehicle, boneCount )

            vehicle:SetPoseParameter( poseName, 1 )
            local open = SnapshotBones( vehicle, boneCount )

            -- UpdateAnimations writes the real value again next frame anyway
            vehicle:SetPoseParameter( poseName, lerp and lerp.poseValues[i] or 0 )

            if next( closed ) == nil then return nil end   -- bones not set up yet, retry later

            local moved = { n = 0 }

            for bone = 0, boneCount - 1 do
                if BoneMoved( closed[bone], open[bone] ) then
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
                end
            end
        end
    end

    return parts
end

local function GetPartMap( vehicle, config )
    local key = vehicle:GetModel() or ""

    for i = 1, config.count do
        key = key .. "|" .. tostring( config.names[i] ) .. ( IsAimEligible( config, i ) and "" or "!" )
    end

    local parts = partMapCache[key]

    if parts == nil then
        parts = BuildPartMap( vehicle, config )
        if not parts then return nil end   -- not cached: retry on a later frame
        partMapCache[key] = parts
    end

    return parts
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

-- Returns { vehicle, animIndex, pos, open, enter } or nil
local function FindAimedPart( ply, force )
    local start = ply:GetShootPos()
    local delta = ply:GetAimVector() * USE_RANGE

    RefreshCandidates( start, force )

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

    if not best then return nil end

    -- Occlusion: something (world, another prop, the car's own body
    -- when aiming at the far side) is clearly in front of the part
    local tr = util.TraceLine( { start = start, endpos = start + delta, filter = ply } )
    if tr.Hit and bestDist > tr.Fraction * USE_RANGE + OCCLUSION_SLACK then return nil end

    local vehicle, part = best.vehicle, best.part
    local config = BlackterioCustomAnims.GetConfig( vehicle )

    return {
        vehicle   = vehicle,
        animIndex = part.animIndex,
        pos       = LocalToWorld( ( part.mins + part.maxs ) * 0.5, angle_zero, best.matrix:GetTranslation(), best.matrix:GetAngles() ),
        open      = BlackterioCustomAnims.GetAnimationState( vehicle, part.animIndex ),
        enter     = IsAimEnter( config, part.animIndex )
    }
end

BlackterioCustomAnims.FindAimedPart = FindAimedPart

-- Per-player opt-out (blackterio_aimdoors_enable, Glide config panel).
-- Disabled: [E] is never intercepted, so it always enters the vehicle.
local cvarEnable

local function IsAimEnabled()
    cvarEnable = cvarEnable or GetConVar( "blackterio_aimdoors_enable" )
    return not cvarEnable or cvarEnable:GetBool()
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
    if not IsAimEnabled() then return end

    local aimed = FindAimedPart( ply, true )
    if not aimed then return end   -- normal +use: Glide enters the vehicle

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

local cvarHint
local cvarDeveloper = GetConVar( "developer" )
local currentAim

local function KeyName( bind, fallback )
    return string.upper( input.LookupBinding( bind ) or fallback )
end

hook.Add( "Think", "BlackterioCustomAnims.AimTrack", function()
    cvarHint = cvarHint or GetConVar( "blackterio_aimdoors_hint" )

    local wantHint = cvarHint and cvarHint:GetBool()
    local wantDev  = cvarDeveloper:GetInt() > 0

    currentAim = nil
    if not IsAimEnabled() then return end
    if not wantHint and not wantDev then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) or ply:InVehicle() or not ply:Alive() then return end

    currentAim = FindAimedPart( ply, false )
end )

local COLOR_SHADOW        = Color( 0, 0, 0, 150 )
local COLOR_FRIEND_LOCKED = Color( 255, 210, 60 )   -- Glide lock: owner and friends can still open
local COLOR_LOCKED        = Color( 255, 70, 70 )    -- "Glide // Car Keys" lock: nobody can open

-- Texts: resource/localization/<lang>/blackterio_extra_functions.properties
local GetPhrase = language.GetPhrase

local function DrawHintLine( text, x, y, color )
    draw.DrawText( text, "TargetIDSmall", x + 1, y + 1, COLOR_SHADOW, TEXT_ALIGN_CENTER )
    draw.DrawText( text, "TargetIDSmall", x, y, color, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "BlackterioCustomAnims.AimHint", function()
    -- The vehicle can be removed between Think (where currentAim is set) and this hook
    if not currentAim or not IsValid( currentAim.vehicle ) or not ( cvarHint and cvarHint:GetBool() ) then return end

    local screen = currentAim.pos:ToScreen()
    if not screen.visible then return end

    local useKey = KeyName( "+use", "E" )
    local text

    if not currentAim.open then
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

hook.Add( "PostDrawTranslucentRenderables", "BlackterioCustomAnims.AimDebug", function( depth, skybox )
    if depth or skybox then return end
    if cvarDeveloper:GetInt() < 1 then return end
    if not IsAimEnabled() then return end

    for _, vehicle in ipairs( candidates ) do
        if IsValid( vehicle ) then
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
