--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
Character events tracker (XP, Level, etc.)
]]--

local GLV = LibStub("GuidelimeVanilla")

local CharacterTracker = {}
GLV.CharacterTracker = CharacterTracker

-- Initialize character tracking and register event handlers
function CharacterTracker:Init()
    if GLV.Ace then
        GLV.Ace:RegisterEvent("PLAYER_XP_UPDATE", function() self:OnPlayerXPUpdate() end)
        GLV.Ace:RegisterEvent("PLAYER_LEVEL_UP", function() self:OnPlayerXPUpdate() end)
        -- CORRECTION : Utiliser les bons événements pour WoW 1.12
        GLV.Ace:RegisterEvent("SPELLS_CHANGED", function() self:OnSpellLearned() end)
        GLV.Ace:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() self:OnSpellLearned() end)
    end
    
    self.previousPlayerLevel = UnitLevel("player")
    self.previousPlayerXP = UnitXP("player")
    -- CORRECTION : Garder une trace des sorts connus pour détecter les changements
    self.knownSpells = self:BuildKnownSpellsList()
end


--[[ EVENTS ]]--

-- Handle player XP and level updates, check XP requirements
function CharacterTracker:OnPlayerXPUpdate()
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
      
    if currentLevel > self.previousPlayerLevel or (currentLevel == self.previousPlayerLevel and currentXP > self.previousPlayerXP) then
        
        local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()
        
        self.previousPlayerLevel = currentLevel
        self.previousPlayerXP = currentXP
        
        self:ManageXPTimer(hasXPReqs)

    end
end

function CharacterTracker:BuildKnownSpellsList()
    local spells = {}
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        -- Stocker le nom complet avec le rang si disponible
        local fullSpellName = spellRank and (spellName .. "(" .. spellRank .. ")") or spellName
        spells[spellName] = true
        spells[fullSpellName] = true
        i = i + 1
    end
    return spells
end

function CharacterTracker:OnSpellLearned()
    if not GLV.CurrentDisplaySteps then
        return false
    end

    -- Construire la liste actuelle des sorts
    local currentSpells = self:BuildKnownSpellsList()
    
    -- Vérifier s'il y a de nouveaux sorts
    local hasNewSpells = false
    for spellName, _ in pairs(currentSpells) do
        if not self.knownSpells[spellName] then
            hasNewSpells = true
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime]|r New spell detected: " .. spellName)
            break
        end
    end
    
    -- Mettre à jour la liste des sorts connus
    self.knownSpells = currentSpells
    
    -- Si aucun nouveau sort, pas besoin de continuer
    if not hasNewSpells then
        return false
    end

    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    local stepsCompleted = false
    
    for di = 1, diCount do
        local step = GLV.CurrentDisplaySteps[di]
        local origIdx = diToOrig[di]
        
        if step and origIdx and not stepState[origIdx] then
            if step.learnTags and table.getn(step.learnTags) > 0 then
                local allSpellsLearned = true
                
                for _, learnTag in ipairs(step.learnTags) do
                    local spellId = learnTag.spellId
                    local spellName = GLV:getSpellName(spellId)
                    local spellFound = false
                    
                    if spellName then
                        -- CORRECTION : Vérification plus robuste
                        -- 1. Vérification directe du nom
                        if currentSpells[spellName] then
                            spellFound = true
                        else
                            -- 2. Vérification avec comparaison insensible à la casse
                            local lowerSpellName = string.lower(spellName)
                            for knownSpell, _ in pairs(currentSpells) do
                                if string.lower(knownSpell) == lowerSpellName then
                                    spellFound = true
                                    break
                                end
                            end
                            
                            -- 3. Si toujours pas trouvé, chercher par correspondance partielle
                            if not spellFound then
                                for knownSpell, _ in pairs(currentSpells) do
                                    -- Enlever les parenthèses et les rangs pour la comparaison
                                    local cleanKnownSpell = string.gsub(knownSpell, "%b()", "")
                                    cleanKnownSpell = string.gsub(cleanKnownSpell, "%s+$", "") -- enlever espaces finaux
                                    
                                    if string.lower(cleanKnownSpell) == lowerSpellName then
                                        spellFound = true
                                        break
                                    end
                                end
                            end
                        end
                        
                        if GLV.Debug and spellFound then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime]|r Spell found: " .. spellName)
                        elseif GLV.Debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime]|r Spell NOT found: " .. spellName)
                        end
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime]|r Warning: Could not get spell name for ID " .. tostring(spellId))
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
                    
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime]|r Step completed: All required spells learned!")
                end
            end
        end
    end
    
    -- CORRECTION : Mettre à jour la navigation seulement si des étapes ont été complétées
    if stepsCompleted then
        -- Update quest tracker navigation
        if GLV.QuestTracker then
            GLV.QuestTracker:UpdateStepNavigation(true, false)
        end
        
        -- Update guide navigation waypoint for the new active step
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

-- NOUVELLE FONCTION : Vérifier manuellement les sorts appris (pour débogage)
function CharacterTracker:CheckSpellLearning()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime]|r Manual spell check triggered")
    return self:OnSpellLearned()
end

-- NOUVELLE FONCTION : Debug des sorts connus
function CharacterTracker:DebugKnownSpells()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime Debug]|r Known spells:")
    local count = 0
    for spellName, _ in pairs(self.knownSpells or {}) do
        DEFAULT_CHAT_FRAME:AddMessage("  - " .. spellName)
        count = count + 1
        if count > 20 then -- Limiter l'affichage
            DEFAULT_CHAT_FRAME:AddMessage("  ... and " .. (table.getn(self.knownSpells) - count) .. " more")
            break
        end
    end
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
    end
end

-- Check if player meets XP requirements for current guide steps
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
        if self.xpCheckTimer then
            if not self.xpCheckTimer then
                if GLV.Ace then
                    if GLV.Debug then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Starting XP check timer")
                    end
                    self.xpCheckTimer = GLV.Ace:ScheduleRepeatingEvent("XPCheckUpdate", function() self:CheckForXPChanges() end, 2)
                end
            end
        end
    else
        if self.xpCheckTimer then
            if not self.xpCheckTimer then
                if GLV.Ace then
                    if GLV.Debug then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Stopping XP check timer")
                    end
                    self.xpCheckTimer = GLV.Ace:CancelScheduledEvent("XPCheckUpdate")
                end
            end
        end
    end
end

-- Check XP requirements immediately when loading guide or changing steps
function CharacterTracker:CheckCurrentStepXPRequirements()
    local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()
    
    self:ManageXPTimer(hasXPReqs)
    
    return hasXPReqs, stepCompleted
end
