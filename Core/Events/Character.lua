--[[
Guidelime Vanilla

Author: Grommey

Description:
Character events tracker (XP, Level, Spells, ..)
]]--

local GLV = LibStub("GuidelimeVanilla")

local CharacterTracker = {}
GLV.CharacterTracker = CharacterTracker

-- Initialize character tracking and register event handlers for XP, level, and spell learning events
function CharacterTracker:Init()
    if GLV.Ace then
        GLV.Ace:RegisterEvent("PLAYER_XP_UPDATE", function() self:OnPlayerXPUpdate() end)
        GLV.Ace:RegisterEvent("PLAYER_LEVEL_UP", function() self:OnPlayerXPUpdate() end)

        GLV.Ace:RegisterEvent("LEARNED_SPELL_IN_TAB", function() self:OnSpellLearned() end)
    end
    
    self.previousPlayerLevel = UnitLevel("player")
    self.previousPlayerXP = UnitXP("player")

    self.knownSpells = self:BuildKnownSpellsList()
end


--[[ EVENTS ]]--

-- Handle player XP and level updates, check XP requirements and manage timers
function CharacterTracker:OnPlayerXPUpdate()
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
      
    if currentLevel > self.previousPlayerLevel or (currentLevel == self.previousPlayerLevel and currentXP > self.previousPlayerXP) then

        local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()

        self.previousPlayerLevel = currentLevel
        self.previousPlayerXP = currentXP

        self:ManageXPTimer(hasXPReqs)

        -- Update XP progress display on UI
        if GLV.UpdateXPProgressDisplay then
            GLV:UpdateXPProgressDisplay()
        end

    end
end

-- Build a list of all currently known spells from the spell book
function CharacterTracker:BuildKnownSpellsList()
    local spells = {}
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        local fullSpellName = spellRank and (spellName .. "(" .. spellRank .. ")") or spellName
        spells[spellName] = true
        spells[fullSpellName] = true
        i = i + 1
    end
    return spells
end

-- Handle spell learning events, check if learned spells complete guide steps
function CharacterTracker:OnSpellLearned()
    if not GLV.CurrentDisplaySteps then
        return false
    end

    local currentSpells = self:BuildKnownSpellsList()
    
    local hasNewSpells = false
    for spellName, _ in pairs(currentSpells) do
        if not self.knownSpells[spellName] then
            hasNewSpells = true
            break
        end
    end
    
    self.knownSpells = currentSpells

    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    local stepsCompleted = false
       
    for di = 1, diCount do
        local step = GLV.CurrentDisplaySteps[di]
        local origIdx = diToOrig[di]

        if step and origIdx and not stepState[origIdx] then
            
            if step.lines then

                for _, line in ipairs(step.lines) do
            
                    if line.learnTags and line.learnTags[origIdx] then
                        
                        local allSpellsLearned = true
                        
                        for _, learnTag in ipairs(line.learnTags[origIdx]) do
                            local spellId = learnTag.spellId
                            local spellName = learnTag.spellName
                            local spellFound = false
                                                    
                            if spellName then
                                if currentSpells[spellName] then
                                    spellFound = true
                                else
                                    local lowerSpellName = string.lower(spellName)
                                    for knownSpell, _ in pairs(currentSpells) do
                                        if string.lower(knownSpell) == lowerSpellName then
                                            spellFound = true
                                            break
                                        end
                                    end
                                    
                                    if not spellFound then
                                        for knownSpell, _ in pairs(currentSpells) do
                                            local cleanKnownSpell = string.gsub(knownSpell, "%b()", "")
                                            cleanKnownSpell = string.gsub(cleanKnownSpell, "%s+$", "")
                                            
                                            if string.lower(cleanKnownSpell) == lowerSpellName then
                                                spellFound = true
                                                break
                                            end
                                        end
                                    end
                                end
                                
                            end
                            
                            if not spellFound then
                                allSpellsLearned = false
                                break
                            end
                        end
                        
                        if allSpellsLearned then
                            stepState[origIdx] = true
                            GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
                            stepsCompleted = true
                        end
                    end                        
                end
            end
        end
    end
    
    if stepsCompleted then
        if GLV.QuestTracker then
            GLV.QuestTracker:UpdateStepNavigation(true, false)
        end
        
        if GLV.GuideNavigation then
            local currentStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
            if currentStep > 0 and GLV.CurrentDisplaySteps and GLV.CurrentDisplaySteps[currentStep] then
                local stepData = GLV.CurrentDisplaySteps[currentStep]
                GLV.GuideNavigation:OnStepChanged(stepData)
            end
        end
    end
    
    return stepsCompleted
end


--[[ OBJECTS FUNCTIONS ]]--

-- Check for XP changes and update step completion status
function CharacterTracker:CheckForXPChanges()
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")

    if currentLevel ~= self.previousPlayerLevel or currentXP ~= self.previousPlayerXP then

        local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()

        self.previousPlayerLevel = currentLevel
        self.previousPlayerXP = currentXP

        self:ManageXPTimer(hasXPReqs)

        -- Update XP progress display on UI
        if GLV.UpdateXPProgressDisplay then
            GLV:UpdateXPProgressDisplay()
        end
    end
end

-- Create a colored progress bar string
-- current: current value, target: target value, barLength: number of characters (default 10)
local function CreateProgressBar(current, target, barLength)
    barLength = barLength or 10
    local percent = math.min(current / target, 1)
    local filled = math.floor(percent * barLength)
    local empty = barLength - filled

    -- Build the bar with colors
    local filledColor = "|cFF00FF00"  -- Green for filled
    local emptyColor = "|cFF666666"   -- Gray for empty
    local resetColor = "|r"

    local filledStr = ""
    local emptyStr = ""

    for i = 1, filled do
        filledStr = filledStr .. "="
    end
    for i = 1, empty do
        emptyStr = emptyStr .. "-"
    end

    return "[" .. filledColor .. filledStr .. resetColor .. emptyColor .. emptyStr .. resetColor .. "]"
end

-- Get XP progress text for display (e.g., "(1250/1500)" or "(Level 3, 50%)")
function CharacterTracker:GetXPProgress(experienceRequirement)
    if not experienceRequirement then return nil end

    local req = experienceRequirement
    local playerLevel = UnitLevel("player")
    local playerXP = UnitXP("player")
    local playerMaxXP = UnitXPMax("player")

    if req.type == "level" then
        -- [XP4] - just show current level
        if playerLevel >= req.targetLevel then
            return "(Done)", true
        else
            return "(Lvl " .. playerLevel .. "/" .. req.targetLevel .. ")", false
        end

    elseif req.type == "level_minus" then
        -- [XP4-290] - grind until only 290 XP remains before level up
        if playerLevel >= req.targetLevel then
            return "(Done)", true
        elseif playerLevel == (req.targetLevel - 1) then
            local xpNeeded = playerMaxXP - playerXP  -- XP remaining to level up
            if xpNeeded <= req.xpMinus then
                return "(Done)", true
            else
                -- How much XP to grind to reach the target state
                local xpToGrind = xpNeeded - req.xpMinus
                local xpGrinded = (playerMaxXP - req.xpMinus) - (playerMaxXP - playerXP - req.xpMinus)
                local xpTarget = playerMaxXP - req.xpMinus
                local bar = CreateProgressBar(playerXP, xpTarget)
                return bar .. " (" .. xpToGrind .. " XP)", false
            end
        else
            -- Not at target level - 1 yet, show level needed
            return "(Lvl " .. playerLevel .. "/" .. (req.targetLevel - 1) .. ")", false
        end

    elseif req.type == "level_plus" then
        -- [XP9+1000] - grind until you have 1000 XP into level 9
        if playerLevel > req.targetLevel then
            return "(Done)", true
        elseif playerLevel == req.targetLevel then
            if playerXP >= req.xpPlus then
                return "(Done)", true
            else
                local bar = CreateProgressBar(playerXP, req.xpPlus)
                return bar .. " (" .. playerXP .. "/" .. req.xpPlus .. " XP)", false
            end
        else
            -- Below target level: show level progress + XP goal
            return "(Lvl " .. playerLevel .. "/" .. req.targetLevel .. " + " .. req.xpPlus .. " XP)", false
        end

    elseif req.type == "level_percent" then
        -- [XP3.5] - grind until you reach 50% into level 3
        if playerLevel > req.targetLevel then
            return "(Done)", true
        elseif playerLevel == req.targetLevel then
            local targetXP = math.floor((req.targetPercent / 100) * playerMaxXP)
            if playerXP >= targetXP then
                return "(Done)", true
            else
                local bar = CreateProgressBar(playerXP, targetXP)
                return bar .. " (" .. playerXP .. "/" .. targetXP .. " XP)", false
            end
        else
            return "(Lvl " .. playerLevel .. "/" .. req.targetLevel .. ")", false
        end
    end

    return nil
end

-- Check if player meets XP requirements for current guide steps and mark completed ones
function CharacterTracker:CheckExperienceRequirements()
    if not GLV.CurrentDisplaySteps then
        return false
    end
    
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    
    local playerLevel = UnitLevel("player")
    local playerXP = UnitXP("player")
    local playerMaxXP = UnitXPMax("player")
    
    local hasAnyXPRequirements = false
    local stepCompleted = false
    
    for di = 1, diCount do
        local step = GLV.CurrentDisplaySteps[di]
        local origIdx = diToOrig[di]
        
        if step and origIdx and not stepState[origIdx] then
            local hasXPReq = false
            for _, line in ipairs(step.lines or {}) do
                if line.experienceRequirement then
                    hasXPReq = true
                    hasAnyXPRequirements = true
                    local req = line.experienceRequirement
                    local requirementMet = false
                    
                    if req.type == "level" then
                        requirementMet = (playerLevel >= req.targetLevel)

                    elseif req.type == "level_minus" then
                        if playerLevel >= req.targetLevel then
                            requirementMet = true

                        elseif playerLevel == (req.targetLevel - 1) then
                            local xpNeeded = playerMaxXP - playerXP
                            requirementMet = (xpNeeded <= req.xpMinus)

                        end

                    elseif req.type == "level_plus" then
                        if playerLevel >= req.targetLevel then
                            requirementMet = (playerXP >= req.xpPlus)
                        end

                    elseif req.type == "level_percent" then
                        if playerLevel > req.targetLevel then
                            requirementMet = true

                        elseif playerLevel == req.targetLevel then
                            local currentPercent = (playerXP / playerMaxXP) * 100
                            requirementMet = (currentPercent >= req.targetPercent)
                        end
                    end
                    
                    if requirementMet then
                        stepState[origIdx] = true
                        GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
                        
                        if GLV.QuestTracker then
                            GLV.QuestTracker:UpdateStepNavigation(true, false)
                        end
                        stepCompleted = true
                        break
                    end
                end
            end
            
        end
    end
    
    return hasAnyXPRequirements, stepCompleted
end

-- Check and update XP timer based on current requirements
function CharacterTracker:CheckAndUpdateXPTimer()
    local hasXPReqs = self:CheckExperienceRequirements()
    self:ManageXPTimer(hasXPReqs)
end

-- Manage XP timer based on whether there are requirements to monitor
function CharacterTracker:ManageXPTimer(hasXPRequirements)
    if hasXPRequirements then
        -- Start timer if not already running
        if not self.xpCheckTimer and GLV.Ace then
            if GLV.Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Starting XP check timer")
            end
            self.xpCheckTimer = GLV.Ace:ScheduleRepeatingEvent("XPCheckUpdate", function() self:CheckForXPChanges() end, 5)
        end
    else
        -- Stop timer if running
        if self.xpCheckTimer and GLV.Ace then
            if GLV.Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Stopping XP check timer")
            end
            GLV.Ace:CancelScheduledEvent("XPCheckUpdate")
            self.xpCheckTimer = nil
        end
    end
end

-- Check XP requirements immediately when loading guide or changing steps
function CharacterTracker:CheckCurrentStepXPRequirements()
    local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()
    
    self:ManageXPTimer(hasXPReqs)
    
    return hasXPReqs, stepCompleted
end
