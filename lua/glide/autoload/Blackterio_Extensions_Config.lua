-- Location of this file: lua/glide/autoload/
-- Loaded alphabetically before Blackterio_Wiper_Control.lua, so ConVars
-- declared here are already registered when Wiper_Control reads them.

BlackterioExtraFunctions = BlackterioExtraFunctions or {}

--[[----------------------------------------
    ConVars — persist settings between sessions (CLIENT only)
------------------------------------------]]

if CLIENT then
    -- userinfo = true so the SERVER can read the driver's mode with
    -- ply:GetInfoNum() and mirror it onto the vehicle (see Blackterio_Wiper_Control.lua)
    CreateClientConVar( "blackterio_wipers_mode", "0", true, true,
        "Wiper mode: 0 = Auto (weather-based), 1 = Manual (key toggle)" )
    CreateClientConVar( "blackterio_wipers_sound", "1", true, false,
        "Enable wiper sounds: 0 = disabled, 1 = enabled" )
end

--[[----------------------------------------
    Glide Extensions panel (CLIENT only)
    Add new configurable parameters here.
------------------------------------------]]

if CLIENT then
    list.Set( "GlideConfigExtensions", "BlackterioExtraFunctions", function( config, panel )
        config.CreateHeader( panel, "Extra Functions" )

        -- Checked = Manual mode (toggle with key). Unchecked = Auto (weather-based).
        local cvarMode = GetConVar( "blackterio_wipers_mode" )
        config.CreateToggle( panel, "Manual wipers (toggle with key)", cvarMode:GetBool(), function( value )
            RunConsoleCommand( "blackterio_wipers_mode", value and "1" or "0" )
        end )

        local cvarSound = GetConVar( "blackterio_wipers_sound" )
        config.CreateToggle( panel, "Enable wiper sounds", cvarSound:GetBool(), function( value )
            RunConsoleCommand( "blackterio_wipers_sound", value and "1" or "0" )
        end )
    end )
end
