-- Location of this file: lua/glide/autoload/
-- Loaded via Glide's IncludeDir (inside lua/autorun/sh_glide.lua).
BlackterioExtraFunctions = BlackterioExtraFunctions or {}

--[[----------------------------------------
    Vehicle Controls (server side of the extra functions)
    Handbrake state and speed limiter, driven by the vehicle's extra functions config.

    A vehicle opts in by defining ENT:GetExtraFunctionsConfig() (shared realm),
    which returns the table made with BlackterioExtraFunctions:CreateConfig.
    The same table is passed to BlackterioExtraFunctions:UpdateAnimations on the client:

      config.handbrake     -> mirrors the handbrake key onto a NW2Int, so every client
                              animates the lever and plays the sounds
      config.speedLimiter  -> fades the engine torque out near the speed limit

    State lives in NW2 vars on the vehicle, so every client
    (including late joiners) sees the same thing:
      "blackterio_handbrake" -> counter * 2 + state (1 = applied). The counter
        changes on every press and release.
------------------------------------------]]

local NW_HANDBRAKE = "blackterio_handbrake"

-- Glide HUD / Wire speedometer conversion: source units per second -> km/h
local UNITS_TO_KMH = 3600 * 0.0000254 * 0.75

if SERVER then

    --[[----------------------------------------
        Handbrake (SERVER only — Glide calls
        ENT:OnSeatInput on the server realm)
    ------------------------------------------]]

    -- Glide holds the handbrake action while the key is pressed. This never
    -- consumes the input: Glide still applies the brake.
    local function HandleHandbrakeInput( vehicle, seatIndex, action, pressed )
        if seatIndex ~= 1 then return end
        if action ~= "handbrake" then return end

        local on = pressed and true or false
        if on == ( vehicle._bvcHandbrake or false ) then return end

        vehicle._bvcHandbrake = on

        local counter = math.floor( vehicle:GetNW2Int( NW_HANDBRAKE, 0 ) / 2 ) + 1
        vehicle:SetNW2Int( NW_HANDBRAKE, counter * 2 + ( on and 1 or 0 ) )
    end

    --[[----------------------------------------
        Speed limiter: the torque fades out over the last
        `speedLimiterFade` (fraction) before the limit. Forward only.
    ------------------------------------------]]

    local function ApplySpeedLimiter( vehicle, selfTbl, config )
        local limit = isfunction( vehicle.GetSpeedLimit ) and vehicle:GetSpeedLimit() or config.speedLimit or 0
        if limit <= 0 then return end

        local limitUnits = limit / UNITS_TO_KMH
        local fade = ( limitUnits - selfTbl.forwardSpeed ) / ( limitUnits * ( config.speedLimiterFade or 0.04 ) )

        if fade < 1 then
            fade = math.max( fade, 0 )
            selfTbl.availableFrontTorque = selfTbl.availableFrontTorque * fade
            selfTbl.availableRearTorque = selfTbl.availableRearTorque * fade
        end
    end

    --[[----------------------------------------
        Auto-inject into every Glide vehicle that declares its config.
        Chains correctly with any prior injection (e.g. Custom Anims, Wiper Control).
    ------------------------------------------]]

    local function InjectVehicleControls( ent )
        if not IsValid( ent )                then return end
        if not ent.IsGlideVehicle            then return end
        if not ent.GetExtraFunctionsConfig   then return end
        if ent.HasExtraFunctions == false    then return end
        if ent._bvcInjected                  then return end

        local config = ent:GetExtraFunctionsConfig()
        if not config then return end

        ent._bvcInjected = true

        if config.handbrake then
            local origOnSeatInput = ent.OnSeatInput

            ent.OnSeatInput = function( self, seatIndex, action, pressed )
                HandleHandbrakeInput( self, seatIndex, action, pressed )

                if origOnSeatInput then
                    return origOnSeatInput( self, seatIndex, action, pressed )
                end
                return false
            end
        end

        if config.speedLimiter then
            local origEngineThink = ent.EngineThink

            ent.EngineThink = function( self, dt, selfTbl )
                if origEngineThink then
                    origEngineThink( self, dt, selfTbl )
                end

                ApplySpeedLimiter( self, selfTbl, config )
            end
        end
    end

    hook.Add( "OnEntityCreated", "BlackterioVehicleControlsAutoInject", function( ent )
        if not ent.GetExtraFunctionsConfig then return end

        -- Defer one tick: Initialize() must run first so ent.IsGlideVehicle is set
        timer.Simple( 0, function()
            InjectVehicleControls( ent )
        end )
    end )
end
