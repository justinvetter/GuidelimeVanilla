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
    
    -- Créer un frame pour surveiller les événements de personnage
    if not self.characterWatchFrame then
        self.characterWatchFrame = CreateFrame("Frame")
        self.characterWatchFrame:RegisterEvent("PLAYER_XP_UPDATE")
        self.characterWatchFrame:RegisterEvent("PLAYER_LEVEL_UP")
        self.characterWatchFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
        self.characterWatchFrame:SetScript("OnEvent", function(event)
            if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
                self:OnPlayerXPUpdate()
            elseif event == "LEARNED_SPELL_IN_TAB" then
                self:OnSpellLearned()
            end
        end)
        
        -- Créer un timer de vérification périodique séparé
        if not self.xpCheckTimer then
            self.xpCheckTimer = CreateFrame("Frame")
            self.xpCheckTimer.TimeSinceLastUpdate = 0
            self.xpCheckTimer:SetScript("OnUpdate", function()
                self.xpCheckTimer.TimeSinceLastUpdate = self.xpCheckTimer.TimeSinceLastUpdate + 0.1
                if self.xpCheckTimer.TimeSinceLastUpdate >= 2 then
                    self:CheckForXPChanges()
                    self.xpCheckTimer.TimeSinceLastUpdate = 0
                end
            end)
        end
    end
    
    -- Stocker l'état XP précédent du joueur
    self.previousPlayerLevel = UnitLevel("player")
    self.previousPlayerXP = UnitXP("player")

end

function CharacterTracker:OnSpellLearned()
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime XP]|r Spell learned")
    end
end

-- Fonction appelée quand l'XP du joueur change
function CharacterTracker:OnPlayerXPUpdate()
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
      
    -- Vérifier seulement si le niveau ou l'XP a augmenté
    if currentLevel > self.previousPlayerLevel or (currentLevel == self.previousPlayerLevel and currentXP > self.previousPlayerXP) then
        
        -- Vérifier toutes les étapes avec des exigences d'XP
        local hasXPReqs, stepCompleted = self:CheckExperienceRequirements()
        
        -- Mettre à jour l'état stocké
        self.previousPlayerLevel = currentLevel
        self.previousPlayerXP = currentXP
        
        -- Gérer le timer selon s'il y a des exigences XP
        self:ManageXPTimer(hasXPReqs)

    end
end

-- Vérification périodique des changements d'XP (pour pallier aux événements manqués)
function CharacterTracker:CheckForXPChanges()
    local currentLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
    
    -- Vérifier seulement si le niveau ou l'XP a changé
    if currentLevel ~= self.previousPlayerLevel or currentXP ~= self.previousPlayerXP then
        
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
        return false -- Aucune étape XP trouvée
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

                    elseif req.type == "level_minus" then
                        -- [XP3-100] -> Il manque 100 XP pour le niveau 3
                        if playerLevel >= req.targetLevel then
                            requirementMet = true

                        elseif playerLevel == (req.targetLevel - 1) then
                            -- Calculer combien d'XP il manque pour le prochain niveau
                            local xpNeeded = playerMaxXP - playerXP
                            requirementMet = (xpNeeded <= req.xpMinus)

                        end
                        
                    elseif req.type == "level_percent" then
                        -- [XP3.5] ou [XP2.925] -> Niveau avec pourcentage d'XP
                        if playerLevel > req.targetLevel then
                            requirementMet = true

                        elseif playerLevel == req.targetLevel then
                            local currentPercent = (playerXP / playerMaxXP) * 100
                            requirementMet = (currentPercent >= req.targetPercent)
                        end
                    end
                    
                    if requirementMet then
                        
                        -- Marquer l'étape comme complétée
                        stepState[origIdx] = true
                        GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
                        
                        -- Mettre à jour la navigation via le QuestTracker
                        if GLV.QuestTracker then
                            GLV.QuestTracker:UpdateStepNavigation(true, false)
                        end
                        stepCompleted = true
                        break -- Une seule exigence d'XP par étape
                    end
                end
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
        end
    else
        -- Désactiver le timer s'il n'y a pas d'exigences XP
        if self.xpCheckTimer then
            self.xpCheckTimer:Hide()
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
