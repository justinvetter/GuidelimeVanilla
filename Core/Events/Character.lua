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

function CharacterTracker:Init()
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Initializing Character Tracker")
    end
    
    -- Créer un frame pour surveiller les événements de personnage
    if not self.characterWatchFrame then
        self.characterWatchFrame = CreateFrame("Frame")
        self.characterWatchFrame:RegisterEvent("PLAYER_XP_UPDATE")
        self.characterWatchFrame:RegisterEvent("PLAYER_LEVEL_UP")
        self.characterWatchFrame:SetScript("OnEvent", function(event)
            if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
                self:OnPlayerXPUpdate()
            end
        end)
        
        -- Créer un timer de vérification périodique séparé
        if not self.xpCheckTimer then
            self.xpCheckTimer = CreateFrame("Frame")
            self.xpCheckTimer.TimeSinceLastUpdate = 0
            self.xpCheckTimer:SetScript("OnUpdate", function()
                self.xpCheckTimer.TimeSinceLastUpdate = self.xpCheckTimer.TimeSinceLastUpdate + 0.1
                if self.xpCheckTimer.TimeSinceLastUpdate >= 2 then
                    if GLV.Debug then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Timer check triggered")
                    end
                    self:CheckForXPChanges()
                    self.xpCheckTimer.TimeSinceLastUpdate = 0
                end
            end)
        end
    end
    
    -- Stocker l'état XP précédent du joueur
    self.previousPlayerLevel = UnitLevel("player")
    self.previousPlayerXP = UnitXP("player")
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Initial state: Level " .. self.previousPlayerLevel .. " (" .. self.previousPlayerXP .. " XP)")
    end
end

-- Fonction appelée quand l'XP du joueur change
function CharacterTracker:OnPlayerXPUpdate()
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r XP Event triggered - Level " .. currentLevel .. " (" .. currentXP .. " XP) - Previous: Level " .. (self.previousPlayerLevel or "nil") .. " (" .. (self.previousPlayerXP or "nil") .. " XP)")
    end
    
    -- Vérifier seulement si le niveau ou l'XP a augmenté
    if currentLevel > self.previousPlayerLevel or (currentLevel == self.previousPlayerLevel and currentXP > self.previousPlayerXP) then
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Player XP updated: Level " .. currentLevel .. " (" .. currentXP .. " XP)")
        end
        
        -- Vérifier toutes les étapes avec des exigences d'XP
        local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()
        
        -- Mettre à jour l'état stocké
        self.previousPlayerLevel = currentLevel
        self.previousPlayerXP = currentXP
        
        -- Gérer le timer selon s'il y a des exigences XP
        self:ManageXPTimer(hasXPReqs)
    else
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r XP didn't increase, skipping check")
        end
    end
end

-- Vérification périodique des changements d'XP (pour pallier aux événements manqués)
function CharacterTracker:CheckForXPChanges()
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
    
    -- Vérifier seulement si le niveau ou l'XP a changé
    if currentLevel ~= self.previousPlayerLevel or currentXP ~= self.previousPlayerXP then
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Periodic check detected XP change: Level " .. currentLevel .. " (" .. currentXP .. " XP) - was Level " .. self.previousPlayerLevel .. " (" .. self.previousPlayerXP .. " XP)")
        end
        
        -- Vérifier toutes les étapes avec des exigences d'XP
        local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()
        
        -- Mettre à jour l'état stocké
        self.previousPlayerLevel = currentLevel
        self.previousPlayerXP = currentXP
        
        -- Gérer le timer selon s'il y a des exigences XP
        self:ManageXPTimer(hasXPReqs)
    end
end

-- Vérifier si le joueur a atteint les exigences d'XP pour les étapes actuelles
function CharacterTracker:CheckExperienceRequirements()
    if not GLV.CurrentDisplaySteps then
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r No current display steps to check")
        end
        return false -- Aucune étape XP trouvée
    end
    
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    
    local playerLevel = UnitLevel("player")
    local playerXP = UnitXP("player")
    local playerMaxXP = UnitXPMax("player")
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Checking XP requirements - Player: Level " .. playerLevel .. " (" .. playerXP .. "/" .. playerMaxXP .. " XP)")
    end
    
    -- Parcourir toutes les étapes
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Found " .. diCount .. " display steps to check")
    end
    
    local hasAnyXPRequirements = false
    local stepCompleted = false
    
    for di = 1, diCount do
        local step = GLV.CurrentDisplaySteps[di]
        local origIdx = diToOrig[di]
        
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Step " .. di .. " (orig: " .. (origIdx or "nil") .. ") - completed: " .. (stepState[origIdx] and "YES" or "NO"))
        end
        
        if step and origIdx and not stepState[origIdx] then
            -- Vérifier dans les lignes de l'étape
            local hasXPReq = false
            for _, line in ipairs(step.lines or {}) do
                if line.experienceRequirement then
                    hasXPReq = true
                    hasAnyXPRequirements = true
                    local req = line.experienceRequirement
                    local requirementMet = false
                    
                    if req.type == "level" then
                        -- [XP3] -> Atteindre le niveau 3
                        requirementMet = (playerLevel >= req.targetLevel)
                        if GLV.Debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Checking level requirement: Level " .. req.targetLevel .. " (player is Level " .. playerLevel .. ") -> " .. (requirementMet and "MET" or "NOT MET"))
                        end
                        
                    elseif req.type == "level_minus" then
                        -- [XP3-100] -> Il manque 100 XP pour le niveau 3
                        if playerLevel >= req.targetLevel then
                            requirementMet = true
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Level already reached: " .. playerLevel .. " >= " .. req.targetLevel .. " -> MET")
                            end
                        elseif playerLevel == (req.targetLevel - 1) then
                            -- Calculer combien d'XP il manque pour le prochain niveau
                            local xpNeeded = playerMaxXP - playerXP
                            requirementMet = (xpNeeded <= req.xpMinus)
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Checking XP requirement: need " .. req.xpMinus .. " XP away from level " .. req.targetLevel .. " (current: " .. xpNeeded .. " away) -> " .. (requirementMet and "MET" or "NOT MET"))
                            end
                        else
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Level too low: " .. playerLevel .. " vs " .. (req.targetLevel - 1) .. " -> NOT MET")
                            end
                        end
                        
                    elseif req.type == "level_percent" then
                        -- [XP3.5] ou [XP2.925] -> Niveau avec pourcentage d'XP
                        if playerLevel > req.targetLevel then
                            requirementMet = true
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Level exceeded: " .. playerLevel .. " > " .. req.targetLevel .. " -> MET")
                            end
                        elseif playerLevel == req.targetLevel then
                            local currentPercent = (playerXP / playerMaxXP) * 100
                            requirementMet = (currentPercent >= req.targetPercent)
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Checking percent requirement: " .. req.targetPercent .. "% (current: " .. currentPercent .. "%) -> " .. (requirementMet and "MET" or "NOT MET"))
                            end
                        else
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Level too low for percent check: " .. playerLevel .. " vs " .. req.targetLevel .. " -> NOT MET")
                            end
                        end
                    end
                    
                    if requirementMet then
                        if GLV.Debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Experience requirement met for step " .. origIdx .. ": " .. req.type)
                        end
                        
                        -- Marquer l'étape comme complétée
                        stepState[origIdx] = true
                        GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
                        
                        -- Mettre à jour la navigation via le QuestTracker
                        if GLV.QuestTracker then
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Calling UpdateStepNavigation for step " .. origIdx)
                            end
                            GLV.QuestTracker:UpdateStepNavigation(true, false)
                        else
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime XP]|r QuestTracker not available for navigation update")
                            end
                        end
                        stepCompleted = true
                        break -- Une seule exigence d'XP par étape
                    end
                end
            end
            
            if GLV.Debug and not hasXPReq then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Step " .. di .. " has no XP requirements")
            end
        end
    end
    
    return hasAnyXPRequirements, stepCompleted
end

-- Vérifier et mettre à jour le timer XP selon les exigences actuelles
function CharacterTracker:CheckAndUpdateXPTimer()
    local hasXPReqs = self:CheckExperienceRequirements()
    self:ManageXPTimer(hasXPReqs)
end

-- Gérer le timer XP selon s'il y a des exigences à surveiller
function CharacterTracker:ManageXPTimer(hasXPRequirements)
    if hasXPRequirements then
        -- Activer le timer s'il y a des exigences XP
        if self.xpCheckTimer then
            self.xpCheckTimer:Show()
            if GLV.Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r XP Timer activated - monitoring XP changes")
            end
        end
    else
        -- Désactiver le timer s'il n'y a pas d'exigences XP
        if self.xpCheckTimer then
            self.xpCheckTimer:Hide()
            if GLV.Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r XP Timer deactivated - no XP requirements to monitor")
            end
        end
    end
end

-- Vérifier immédiatement les exigences d'XP quand on charge un guide ou change d'étape
function CharacterTracker:CheckCurrentStepXPRequirements()
    -- Forcer la vérification des exigences d'XP pour l'étape actuelle
    local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()
    
    -- Gérer le timer selon le résultat
    self:ManageXPTimer(hasXPReqs)
    
    return hasXPReqs, stepCompleted
end
