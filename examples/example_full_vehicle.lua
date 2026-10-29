-- EXAMPLE: a Glide car that uses EVERY feature of Extra Functions.
-- Copy it to lua/entities/ and keep only what your model has. Names, models and numbers are placeholders.
-- Every Extra Functions option is optional: remove the lines you don't need.

AddCSLuaFile()

-- Load Extra Functions (the vehicle still works if the addon is not installed)
local function LoadExtraFunctions()
    local paths = {
        "autorun/shared/blackterio_extra_functions.lua",
        "lua/autorun/shared/blackterio_extra_functions.lua",
        "blackterio_extra_functions.lua"
    }

    for _, path in ipairs( paths ) do
        if file.Exists( path, "LUA" ) then
            if SERVER then
                AddCSLuaFile( path )
            end
            include( path )
            return true
        end
    end
    return false
end

local extraFunctionsLoaded = LoadExtraFunctions()

local ItHasExtraFunctions = true -- false = no gauges, pedals, etc. on this vehicle

ENT.Type = "anim"
ENT.Base = "base_glide_car"

ENT.PrintName = "Example Full Vehicle"
ENT.GlideCategory = "Examples"
ENT.ChassisModel = "models/path/to/your_vehicle.mdl"

DEFINE_BASECLASS( "base_glide_car" ) -- required for the extra functions

--[[ DOORS, HOOD, TRUNK ]]

-- Pose parameters of the toggle animations (9 max)
function ENT:GetAnimationConfig()
    return {
        count = 4,
        names = { "door_fl", "door_fr", "trunk", "hood" },
        initialSound = "blackterios_glide_vehicles/doors/caropen.wav",
        finishSound = "blackterios_glide_vehicles/doors/carclose.wav",
        duration = 0.5,
        lerpType = "smooth",
        soundFollowsDuration = true,

        aimToSit = true, -- aim at a seat + use key = sit there
        clickToInteract = true, -- free look key + click on the parts while seated
        closesOnEnter = true, -- the door closes after entering
    }
end

-- Per-part overrides
function ENT:GetAdvancedAnimationConfig()
    return {
        { name = "trunk", customInitialSound = "blackterios_glide_vehicles/doors/trunkhoodopen.wav", customFinishSound = "blackterios_glide_vehicles/doors/trunkhoodclose.wav" },
        { name = "hood", customInitialSound = "blackterios_glide_vehicles/doors/trunkhoodopen.wav", customFinishSound = "blackterios_glide_vehicles/doors/trunkhoodclose.wav" },
    }
end

--[[ EXTRA FUNCTIONS CONFIG ]]

-- Shared (client animates, server reads it for handbrake, limiter and clicks). Built only once.
function ENT:GetExtraFunctionsConfig()
    if not BlackterioExtraFunctions then return end

    if not self.AnimationConfig then
        self.AnimationConfig = BlackterioExtraFunctions:CreateConfig( {

            -- Gauges and pedals
            pedals = true,
            clutch = true,
            speedo = true,
            tacho = true,
            fuel = true,
            oil = true,
            temp = true,
            battery = true,

            -- Switches
            ignitionKey = true,
            lightSwitch = true,
            wiperSwitch = true,
            wipers = true,

            -- Controls
            handbrake = true,
            horn = true,
            turnStalk = true,
            gearLever = true,

            -- Gauge tuning
            speedCalibration = 70,
            speedMultiplier = 1,
            rpmCalibration = 0.15,
            pedalLerpRate = 0.2,
            clutchDuration = 0.4,
            wiperSpeed = 0.3,

            -- Parking brake sounds (cabin only, "" = none)
            handbrakeOnSound = "path/to/handbrake_on.wav",
            handbrakeOffSound = "path/to/handbrake_off.wav",

            -- Turn stalk direction for the left signal
            turnStalkLeftSign = -1,

            -- Gear lever: "tap", "position" or "h" (H pattern, 5 gears here)
            gearLeverMode = "h",
            gearLeverH = {
                positions = {
                    [-1] = { 1.5, 0.75 },
                    [0] = { 0, 0 },
                    [1] = { 0.75, 0.75 }, [2] = { 0.75, -1.5 },
                    [3] = { -0.75, 0.75 }, [4] = { -0.75, -1.5 },
                    [5] = { -1.5, 0.75 },
                },
                speedX = 15,
                speedY = 4.5,
                bones = {
                    { name = "gearlever", x = Angle( 0, -4, 0 ), y = Angle( 0, 0, 5 ) },
                },
            },

            -- Looping pose parameters that follow the engine RPM
            engineAnims = {
                { pose = "engine_belts", speed = 0.25 },
                { pose = "engine_fan", speed = 0.4 },
            },

            -- Digital speedometer (3D2D text)
            digitalSpeedometer = true,
            digitalSpeedoPos = Vector( 40, 0, 40 ),
            digitalSpeedoAng = Angle( 0, 90, 70 ),
            digitalSpeedoScale = 0.05,
            digitalSpeedoColor = Color( 255, 255, 255 ),
            digitalSpeedoUnit = "KMH", -- "KMH" or "MPH"
            digitalSpeedoShowUnit = true,
            digitalSpeedoRequireEngine = true,

            -- Destination sign (LED, 3D2D), text editable in "Edit Properties"
            destinationSign = true,
            destinationSignPos = Vector( 100, -20, 80 ),
            destinationSignAng = Angle( 0, 90, 90 ),
            destinationSignColor = Color( 255, 160, 20 ),

            -- Speed limiter, value editable in "Edit Properties"
            speedLimiter = true,
            speedLimiterFade = 0.04,

            -- Click on the switches (free look key + click, driver only). Each needs its function on.
            ignitionKeyClick = true,
            lightSwitchClick = true,
            wiperSwitchClick = true,
            turnStalkClick = true,
            hornClick = true,
            handbrakeClick = true,

            -- Click hitbox size (tiny switches). Use developer 1 to see the boxes.
            clickSwitchPadding = 0.2,
            clickSwitchRadius = 1,
            clickSwitchSizes = {
                ignitionKey = { radius = 1.5 },
            },

            -- Only if your pose parameters have different names:
            -- poseParameters = { gas = "gas", speedo = "speedo" },
        } )
    end

    return self.AnimationConfig
end

--[[ EDITABLE VARS ]]

function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    if BlackterioExtraFunctions then
        BlackterioExtraFunctions:AddEditableVars( self, {
            category = "Example Full Vehicle",
            order = 201,
            destinationText = true, -- GetDestinationText / SetDestinationText
            speedLimit = true, -- GetSpeedLimit / SetSpeedLimit (km/h)
            -- speedLimitMax = 500,
        } )
    else
        -- Without the addon: same vars, just not editable
        self:NetworkVar( "String", "DestinationText" )
        self:NetworkVar( "Int", "SpeedLimit" )
    end
end

--[[ CLIENT ]]

if CLIENT then
    ENT.CameraOffset = Vector( -200, 0, 30 )
    ENT.HornSound = "glide/horns/car_horn_med_5.wav"

    ENT.Headlights = {
        { offset = Vector( 100, 30, 30 ) },
        { offset = Vector( 100, -30, 30 ) },
    }

    ENT.LightSprites = {
        { type = "headlight", offset = Vector( 100, 30, 30 ), dir = Vector( 1, 0, 0 ), size = 50 },
        { type = "headlight", offset = Vector( 100, -30, 30 ), dir = Vector( 1, 0, 0 ), size = 50 },
        { type = "brake", offset = Vector( -100, 30, 30 ), dir = Vector( -1, 0, 0 ), size = 30 },
        { type = "brake", offset = Vector( -100, -30, 30 ), dir = Vector( -1, 0, 0 ), size = 30 },
    }

    function ENT:OnCreateEngineStream( stream )
        stream.offset = Vector( 70, 0, 30 )
        stream:LoadPreset( "your_preset_name" )
    end

    -- Turn the extra functions on for this vehicle
    function ENT:Initialize()
        BaseClass.Initialize( self )
        self.HasExtraFunctions = ItHasExtraFunctions
    end

    function ENT:OnUpdateAnimations()
        -- Doors, hood, trunk
        if BlackterioCustomAnims then
            BlackterioCustomAnims.UpdateAnimations( self )
        end

        -- Gauges, pedals, switches, controls... (it already calls the base class)
        if BlackterioExtraFunctions and extraFunctionsLoaded and self.HasExtraFunctions then
            BlackterioExtraFunctions:UpdateAnimations( self, self:GetExtraFunctionsConfig() )
        else
            BaseClass.OnUpdateAnimations( self )
        end
    end

    -- Digital speedometer and destination sign are drawn here
    function ENT:Draw( flags )
        BaseClass.Draw( self, flags )

        if BlackterioExtraFunctions and extraFunctionsLoaded and self.HasExtraFunctions then
            local config = self:GetExtraFunctionsConfig()

            BlackterioExtraFunctions:DrawDigitalSpeedometer( self, config )
            BlackterioExtraFunctions:DrawDestinationSign( self, config )
        end
    end
end

--[[ SERVER ]]

if SERVER then
    ENT.SpawnPositionOffset = Vector( 0, 0, 20 )
    ENT.ChassisMass = 1500

    function ENT:GetGears()
        return { [-1] = 4.5, [0] = 0, [1] = 3.5, [2] = 2.2, [3] = 1.5, [4] = 1.0, [5] = 0.75 }
    end

    function ENT:CreateFeatures()
        self:SetDestinationText( "CITY" ) -- starting text of the sign
        self:SetSpeedLimit( 120 ) -- starting limit (km/h)

        self:SetMinRPM( 1000 )
        self:SetMaxRPM( 5000 )
        self:SetPowerDistribution( -1 ) -- 1 = front, 0 = all, -1 = back

        -- First seat is the driver
        self:CreateSeat( Vector( 0, 19, 12 ), Angle( 0, -90, 0 ), Vector( 15, 75, 30 ), true )
        self:CreateSeat( Vector( 0, -19, 12 ), Angle( 0, -90, 0 ), Vector( 15, -75, 30 ), true )

        self:CreateWheel( Vector( 75, 33, 16 ), { steerMultiplier = 1 } )
        self:CreateWheel( Vector( 75, -33, 16 ), { steerMultiplier = 1 } )
        self:CreateWheel( Vector( -59, 33, 16 ) )
        self:CreateWheel( Vector( -59, -33, 16 ) )
    end
end
