-- ABSOLUTELY NOT RECOMMENDED TO ADD SUPPORT FOR THIS ANIMATION SYSTEM YET. 
-- It's still extremely WIP and it WILL change in the future with the possibility of breaking your vehicles temporarily
-- Use it at your own risk


DEFINE_BASECLASS( "base_glide_car" ) -- strictly necessary if you wanna make support for custom anims (for example speedometers or tachometers)



-- Custom config for doors animations
function ENT:GetAnimationConfig()
    return {
        count = 3, -- Door Count (9 max)
        names = { "doorfront", "doormiddle", "doorback" }, -- pose parameter names, IN ORDER
        sound = DEFAULT_SOUND, -- sound
        duration = 1.5, -- Animation duration
        lerpType = "fast_start" -- Lerp type: "linear", "smooth", "fast_start", "slow_start"
    }
end 

function ENT:GetInputGroups(seatIndex)

    -- Get base groups of the vehicle
    local baseGroups = BaseClass.GetInputGroups and BaseClass.GetInputGroups(self, seatIndex) or {}

	-- Make sure that baseGroups is a valid table
    if not istable(baseGroups) then
        baseGroups = {}
    end
    
    -- Create a copy of the base groups
    local groups = {}
    for k, v in pairs(baseGroups) do
        groups[k] = v
    end 
	
	-- Verify if the bus door extension is available
    local hasAnimationExtension = false
    
    -- Verify if global function HandleVehicleAnimationInput exists 
    if HandleVehicleAnimationInput then
        hasAnimationExtension = true
    end
    
	-- Verify if "door_animations" group exists
    if Glide and Glide.InputGroups and Glide.InputGroups["door_animations"] then
        hasAnimationExtension = true
    end
    
	-- Only add animation group if the extension is available
    if hasAnimationExtension then
        if not table.HasValue(groups, "door_animations") then
            table.insert(groups, "door_animations")
        end
    end

    return groups
end

function ENT:OnSeatInput(seatIndex, action, pressed)
    -- Handle animation inputs only if the extension is installed
    if string.find(action, "animation_") then
        -- Verify if function HandleVehicleAnimationInput exists (installed extension)
        if HandleVehicleAnimationInput then
            if HandleVehicleAnimationInput(self, seatIndex, action, pressed) then
                return true
            end
        else
            -- If extension is not found, simply ignore all these inputs
            -- Warning message if door extension is not found
            if not self.AnimationExtensionWarningShown then
                if CLIENT then
                    print("[" .. self.PrintName .. "] Animation extension not installed. Door controls disabled.")
                end
                self.AnimationExtensionWarningShown = true
            end
            return false
        end
    end
	
	-- Call base function for other inputs
    if BaseClass.OnSeatInput then
        return BaseClass.OnSeatInput(self, seatIndex, action, pressed)
    end

    return false
end

if CLIENT then

function ENT:Initialize()
    BaseClass.Initialize(self)
    
    
    -- Verify if bus doors extension exists
    self.HasAnimationExtension = (HandleVehicleAnimationInput ~= nil) or 
                                (Glide and Glide.InputGroups and Glide.InputGroups["door_animations"] ~= nil)
								
    -- Initialize doors states only if extension is available
    if self.HasAnimationExtension then 
        self.doorStates = {}
        self.doorPoseValues = {} -- Current values of pose parameters
        self.doorTargetValues = {} -- Lerp objective values
        self.doorLerpSpeed = {} -- Lerp velocity per door
        
        local config = self:GetAnimationConfig()
        if config then
            for i = 1, config.count do
                self.doorStates[i] = false
                self.doorPoseValues[i] = 0
                self.doorTargetValues[i] = 0
                self.doorLerpSpeed[i] = 1 / (config.duration or 2.0) -- Velocity based on duration
            end
        end
    end

end

-- Update a specific door state
function ENT:UpdateDoorState(doorIndex, isOpen)
    if not self.doorStates then return end
    
    local config = self:GetAnimationConfig()
    if not config or doorIndex > config.count then return end
    
    self.doorStates[doorIndex] = isOpen
    -- Establish objective value instead of changing inmediately
    if config.names[doorIndex] then
        local targetValue = isOpen and 1 or 0
        self.doorTargetValues[doorIndex] = targetValue
        -- Update lerp velocity if its necessary
        self.doorLerpSpeed[doorIndex] = 1 / (config.duration or 2.0)
    end
end

--------


-- Extra functions (animations)
function ENT:OnUpdateAnimations()

    -- Lerp system for door animations
    if self.doorPoseValues and self.doorTargetValues and self.doorLerpSpeed then
        local config = self:GetAnimationConfig()
        if config then
            local deltaTime = FrameTime()
            
            for i = 1, config.count do
                if self.doorPoseValues[i] ~= nil and self.doorTargetValues[i] ~= nil and config.names[i] then
                    local currentValue = self.doorPoseValues[i]
                    local targetValue = self.doorTargetValues[i]
                    local lerpSpeed = self.doorLerpSpeed[i] or 0.5
                    
					-- Only make lerp if there's a difference between actual value and objective
                    if math.abs(currentValue - targetValue) > 0.001 then
						-- Calculate lerp value based on the type
                        local lerpAmount = math.min(lerpSpeed * deltaTime, 1)
                        local newValue
                        
                        -- Different types of lerp
                        local lerpType = config.lerpType or "linear"
                        if lerpType == "smooth" then
                            -- Smooth curve (ease in-out)
                            local t = lerpAmount
                            t = t * t * (3 - 2 * t) -- Smoothstep
                            newValue = currentValue + (targetValue - currentValue) * t
                        elseif lerpType == "fast_start" then
                            -- Starts fast, ends slow
                            local t = 1 - math.pow(1 - lerpAmount, 2)
                            newValue = currentValue + (targetValue - currentValue) * t
                        elseif lerpType == "slow_start" then
                            -- Starts slow, ends fast
                            local t = math.pow(lerpAmount, 2)
                            newValue = currentValue + (targetValue - currentValue) * t
                        else
                            -- Linear (default)
                            newValue = Lerp(lerpAmount, currentValue, targetValue)
                        end
                        
                        -- Update stored value
                        self.doorPoseValues[i] = newValue
                        
                        -- Apply pose parameter
                        self:SetPoseParameter(config.names[i], newValue)
                        
						-- Clamp to avoid smaller values that could cause oscilations
                        if math.abs(newValue - targetValue) < 0.001 then
                            self.doorPoseValues[i] = targetValue
                            self:SetPoseParameter(config.names[i], targetValue)
                        end
                    else
						-- If its already on the objective value, make sure its exact
                        self:SetPoseParameter(config.names[i], targetValue)
                    end
                end
            end
        end
    end

end

end
