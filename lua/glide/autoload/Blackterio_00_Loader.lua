-- Location of this file: lua/glide/autoload/
-- Loads the main Extra Functions library on both realms.
--
-- GMod does NOT auto-run lua/autorun/shared/: until now the library only
-- existed because each vehicle include()d it manually from its entity file.
-- Loading it here guarantees it exists even with zero vehicles installed,
-- and the version guard inside the file turns the vehicles' legacy
-- include()s into cheap no-ops.
--
-- (Named _00_ so Glide's IncludeDir runs it before the other Blackterio
-- autoload files.)

local PATH = "autorun/shared/blackterio_extra_functions.lua"

if SERVER then
    AddCSLuaFile( PATH )
end

include( PATH )
