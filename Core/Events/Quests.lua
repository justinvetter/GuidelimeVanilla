--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
Quest Tracker. Track when quests are accepted / completed
]]--
local GLV = LibStub("GuidelimeVanilla")

local QuestTracker = {}
QuestTracker.__index = QuestTracker

-- Make QuestTracker inherit from EventFrame
setmetatable(QuestTracker, {__index = CreateFrame("Frame")})

-- Utility function to apply highlighting to all frames
local function applyHighlighting(scrollChild, activeStepIndex)
    if not scrollChild then return end
    
    -- Use CurrentDisplayStepsCount if available, otherwise try to count manually
    local totalSteps = GLV.CurrentDisplayStepsCount or 0
    if totalSteps == 0 then
        -- Fallback: try to count steps manually
        local stepIndex = 1
        while getglobal(scrollChild:GetName().."Step"..stepIndex) do
            totalSteps = stepIndex
            stepIndex = stepIndex + 1
        end
    end
    
    for di = 1, totalSteps do
        local frameName = scrollChild:GetName().."Step"..di
        local frame = getglobal(frameName)
        if frame and frame.SetBackdropColor then
            local color = (di == activeStepIndex) and {0.8,0.8,0.2,0.9} or (isEven(di) and {0.2,0.2,0.2,0.8} or {0.1,0.1,0.1,0.8})
            frame:SetBackdropColor(unpack(color))
        end
    end
end

-- Hook the GOSSIP_SHOW event to detect innkeeper conversations
function QuestTracker:Init()
    -- Initialize or repair store
    local store = GLV.Settings:GetOption({"QuestTracker"}) or {}
    if not store.accepted then store.accepted = {} end
    if not store.completed then store.completed = {} end
    GLV.Settings:SetOption(store, {"QuestTracker"})
    self.store = store

    -- Hook les fonctions originales
    originalQuestDetailAcceptButton_OnClick = QuestDetailAcceptButton_OnClick
    QuestDetailAcceptButton_OnClick = QuestDetailAccept

    originalQuestRewardCompleteButton_OnClick = QuestRewardCompleteButton_OnClick
	QuestRewardCompleteButton_OnClick = QuestRewardCompleteButton
    
    -- Hook quest abandon
    originalAbandonQuest = AbandonQuest
    AbandonQuest = QuestAbandon
    
    -- Créer un frame pour surveiller les événements de quête
    if not self.questWatchFrame then
        self.questWatchFrame = CreateFrame("Frame")
        self.questWatchFrame:RegisterEvent("QUEST_LOG_UPDATE")
        self.questWatchFrame:SetScript("OnEvent", function(event)
            if event == "QUEST_LOG_UPDATE" then
                self:OnQuestLogUpdate()
            end
        end)
    end
    
    -- Stocker l'état précédent des quêtes pour détecter les changements
    self.previousQuestStates = {}
end

-- Fonction appelée quand le journal de quête est mis à jour
function QuestTracker:OnQuestLogUpdate()
    if not GLV.CurrentDisplaySteps then
        return
    end
    
    -- Vérifier si la surveillance automatique des objectifs est activée
    local autoObjectiveTracking = GLV.Settings:GetOption({"QuestTracker", "AutoObjectiveTracking"})
    if autoObjectiveTracking == false then
        return -- Fonctionnalité désactivée
    end
    
    -- Parcourir toutes les quêtes dans le journal
    local numEntries, numQuests = GetNumQuestLogEntries()
    
    for questIndex = 1, numEntries do
        local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(questIndex)
        
        if questLogTitleText and not isHeader then
            local questId = GLV:GetQuestIDByName(questLogTitleText)
            local numId = tonumber(questId)
            
            if numId then
                -- Vérifier si cette quête a des objectifs qui viennent d'être complétés
                self:CheckQuestObjectives(questIndex, numId, questLogTitleText, isComplete)
            end
        end
    end
end

-- Vérifier les objectifs d'une quête spécifique
function QuestTracker:CheckQuestObjectives(questIndex, questId, questTitle, isComplete)
    -- Sélectionner la quête pour pouvoir lire ses détails
    SelectQuestLogEntry(questIndex)
    
    local questDescription, questObjectives = GetQuestLogQuestText()
    
    -- Analyser les objectifs individuels
    local currentObjectivesState = {}
    local numObjectives = GetNumQuestLeaderBoards()
    
    for i = 1, numObjectives do
        local description, objectiveType, isCompleted = GetQuestLogLeaderBoard(i)
        if description then
            currentObjectivesState[i] = {
                description = description,
                isCompleted = isCompleted
            }
            
            if GLV.Debug and isCompleted then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime Objectives]|r Objective completed: " .. description)
            end
        end
    end
    
    -- Si la quête est complètement terminée (tous objectifs remplis)
    if isComplete and isComplete == 1 then
        -- Vérifier si on n'a pas déjà traité cette complétion
        local currentState = self.previousQuestStates[questId]
        if not currentState or not currentState.wasComplete then
            -- La quête vient d'être complétée !
            if GLV.Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime Objectives]|r Quest completed: " .. questTitle .. " (ID: " .. questId .. ")")
            end
            
            -- Marquer automatiquement les étapes [QC] correspondantes
            self:HandleQuestAction(questId, questTitle, "COMPLETE")
            
            -- Mettre à jour l'état stocké
            self.previousQuestStates[questId] = {
                wasComplete = true,
                lastObjectives = questObjectives,
                objectivesState = currentObjectivesState
            }
        end
    else
        -- La quête n'est pas encore complète, mettre à jour l'état
        self.previousQuestStates[questId] = {
            wasComplete = false,
            lastObjectives = questObjectives,
            objectivesState = currentObjectivesState
        }
    end
end


function QuestTracker:TrackAccepted(id, title)
    if not id or type(id) ~= "number" then
        return
    end

    local store = self.store or GLV.Settings:GetOption({"QuestTracker"}) or {}
    if not store.accepted then store.accepted = {} end

    if id and not store.accepted[id] then
        store.accepted[id] = {
            title = title,
            timestamp = time()
        }
        GLV.Settings:SetOption(store, {"QuestTracker"})
        
        -- Use the centralized function to handle quest actions
        self:HandleQuestAction(id, title, "ACCEPT")
    end
end

function QuestDetailAccept()
    local title = GetTitleText()
    local id = GLV:GetQuestIDByName(title)
    local numId = tonumber(id)
    if numId then
        GLV.QuestTracker:TrackAccepted(numId, title)
    end
    originalQuestDetailAcceptButton_OnClick()
end

function QuestRewardCompleteButton()
    local title = GetTitleText()
    local id = GLV:GetQuestIDByName(title)
    local numId = tonumber(id)
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[GuideLime TURNIN]|r Processing quest turnin: " .. (title or "unknown") .. " (ID: " .. (numId or "nil") .. ")")
    end
    
    -- Optionally mark completed store and refresh UI/advance
    local store = GLV.QuestTracker and GLV.QuestTracker.store or GLV.Settings:GetOption({"QuestTracker"}) or {}
    if store and store.completed and numId then
        store.completed[numId] = { title = title, timestamp = time() }
        GLV.Settings:SetOption(store, {"QuestTracker"})
    end
    
    -- Call the same function used for ACCEPT to handle multi-action steps
    if numId then
        GLV.QuestTracker:HandleQuestAction(numId, title, "TURNIN")
    end
    
    originalQuestRewardCompleteButton_OnClick();
end

-- Nouvelle fonction centralisée pour gérer les actions de quête
function QuestTracker:HandleQuestAction(questId, title, actionType)
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[GuideLime " .. actionType .. "]|r Handling quest action: " .. actionType .. " for quest " .. questId)
    end
    
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local stepQuestState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepQuestState"}) or {}
    
    local stepMarked = false
    local multiActionStepFound = false
    
    if not GLV.CurrentDisplaySteps then
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime]|r No CurrentDisplaySteps available")
        end
        return
    end
    
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    
    -- Parcourir toutes les étapes d'affichage
    for di = 1, diCount do
        local step = GLV.CurrentDisplaySteps[di]
        local origIdx = diToOrig[di]
        
        if step and origIdx then
            if GLV.Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Checking display step " .. di .. " (orig " .. origIdx .. ")")
                if step.questTags then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r  Step has " .. table.getn(step.questTags) .. " questTags")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r  Step has no questTags")
                end
            end
            
            -- Vérifier si cette étape contient des questTags
            if step.questTags and table.getn(step.questTags) > 0 then
                -- Initialiser le suivi de cette étape si nécessaire
                if not stepQuestState[origIdx] then
                    stepQuestState[origIdx] = {}
                end
                
                local hasMatchingAction = false
                local allActionsDone = true
                
                -- Vérifier chaque questTag dans l'étape
                for _, questTag in ipairs(step.questTags) do
                    local actionKey = questTag.questId .. "_" .. questTag.tag
                    
                    if questTag.tag == actionType and questTag.questId == questId then
                        -- On vient de compléter cette action
                        stepQuestState[origIdx][actionKey] = true
                        hasMatchingAction = true
                        multiActionStepFound = true
                        
                        if GLV.Debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Marked action completed: " .. actionKey)
                        end
                    end
                    
                    -- Vérifier si cette action est complétée
                    if not stepQuestState[origIdx][actionKey] then
                        allActionsDone = false
                    end
                end
                
                -- Si on a trouvé une action correspondante dans cette étape
                if hasMatchingAction then
                    -- Sauvegarder l'état des actions
                    GLV.Settings:SetOption(stepQuestState, {"Guide","Guides", currentGuideId, "StepQuestState"})
                    
                    -- Si toutes les actions de l'étape sont complétées
                    if allActionsDone then
                        stepState[origIdx] = true
                        stepMarked = true
                        
                        if GLV.Debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r All actions completed for step " .. origIdx .. ", marking as done")
                        end
                    else
                        if GLV.Debug then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Step " .. origIdx .. " has remaining actions, not marking as done yet")
                        end
                    end
                    
                    break -- On a trouvé l'étape correspondante, on peut sortir
                end
            end
        end
    end
    
    -- Sauvegarder l'état des étapes
    if stepMarked then
        GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
    end
    
    -- Gérer la navigation des étapes
    self:UpdateStepNavigation(stepMarked, multiActionStepFound)
    
    -- Vérifier les exigences d'XP après toute action de quête
    if GLV.CharacterTracker then
        GLV.CharacterTracker:CheckCurrentStepXPRequirements()
    end
end

-- Fonction pour gérer la navigation entre les étapes
function QuestTracker:UpdateStepNavigation(stepMarked, multiActionStepFound)
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local stepQuestState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepQuestState"}) or {}
    
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local hasCb = GLV.CurrentDisplayHasCheckbox or {}
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    
    local firstUnchecked = 0
    
    -- Trouver la prochaine étape non cochée
    for di = 1, diCount do
        if hasCb[di] then
            local origIdx = diToOrig[di]
            if origIdx then
                -- Vérifier si cette étape est complètement terminée
                local stepCompleted = stepState[origIdx]
                
                -- Pour les étapes multi-actions, vérifier si toutes les actions sont faites
                if not stepCompleted then
                    local step = GLV.CurrentDisplaySteps[di]
                    if step and step.questTags and table.getn(step.questTags) > 1 and stepQuestState[origIdx] then
                        local allDone = true
                        for _, questTag in ipairs(step.questTags) do
                            local actionKey = questTag.questId .. "_" .. questTag.tag
                            if not stepQuestState[origIdx][actionKey] then
                                allDone = false
                                break
                            end
                        end
                        if allDone then
                            stepCompleted = true
                        end
                    end
                end
                
                if not stepCompleted then
                    firstUnchecked = di
                    break
                end
            end
        end
    end
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Setting current step to: " .. firstUnchecked)
    end
    
    GLV.Settings:SetOption(firstUnchecked, {"Guide", "Guides", currentGuideId, "CurrentStep"})
    
    -- Mettre à jour l'interface
    if firstUnchecked > 0 then
        local scrollChild = GLV_MainScrollFrameScrollChild
        if scrollChild then
            -- Mettre à jour les checkboxes
            for di = 1, diCount do
                if hasCb[di] then
                    local origIdx = diToOrig[di]
                    if origIdx and stepState[origIdx] then
                        local frameName = scrollChild:GetName().."Step"..di
                        local check = getglobal(frameName.."Check")
                        if check and check.SetChecked then
                            check:SetChecked(true)
                        end
                    end
                end
            end
            
            -- Appliquer la surbrillance
            applyHighlighting(scrollChild, firstUnchecked)
            
            -- Scroll automatique vers la nouvelle étape active
            if firstUnchecked > 0 and GLV_MainScrollFrame then
                -- Calculer la position exacte : somme des hauteurs des étapes précédentes + spacing
                local targetScroll = 0
                for i = 1, firstUnchecked - 1 do
                    local stepFrameName = scrollChild:GetName().."Step"..i
                    local stepFrame = getglobal(stepFrameName)
                    if stepFrame and stepFrame.GetHeight then
                        targetScroll = targetScroll + stepFrame:GetHeight()
                    end
                end
                -- Ajouter l'espacement entre les frames (spacing * (nombre d'étapes - 1))
                if firstUnchecked > 1 then
                    local spacing = -4 -- CONFIG.spacing from GuideWriter
                    targetScroll = targetScroll + (math.abs(spacing) * (firstUnchecked - 1))
                end
                -- S'assurer qu'on ne scroll pas en dessous de 0
                targetScroll = math.max(0, targetScroll)
                -- Ajuster le scroll pour ne pas dépasser la limite
                local maxScroll = GLV_MainScrollFrame:GetVerticalScrollRange()
                if maxScroll and maxScroll > 0 then
                    targetScroll = math.min(targetScroll, maxScroll)
                end
                GLV_MainScrollFrame:SetVerticalScroll(targetScroll)
                
                if GLV.Debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Auto-scrolled to step " .. firstUnchecked .. " (scroll position: " .. targetScroll .. ")")
                end
            end
            
            -- Mettre à jour TomTom
            if GLV.TomTomIntegration and GLV.CurrentDisplaySteps and GLV.CurrentDisplaySteps[firstUnchecked] then
                local stepData = GLV.CurrentDisplaySteps[firstUnchecked]
                GLV.TomTomIntegration:OnStepChanged(stepData)
            end
        end
    end
end

function QuestAbandon()
    local title = GetAbandonQuestName()
    if title then
        local id = GLV:GetQuestIDByName(title)
        local numId = tonumber(id)
        if numId and GLV.QuestTracker then
            local store = GLV.QuestTracker.store or GLV.Settings:GetOption({"QuestTracker"}) or {}
            if store.accepted and store.accepted[numId] then
                store.accepted[numId] = nil
                GLV.Settings:SetOption(store, {"QuestTracker"})
            end
        end
    end
    originalAbandonQuest()
end



-- Public function to refresh highlighting (can be called from GuideWriter)
function QuestTracker:RefreshHighlighting()
    local scrollChild = getglobal("GLV_MainScrollFrameScrollChild")
    if scrollChild then
        -- Get the current guide ID and then the current step for that guide
        local currentGuideId = GLV.Settings:GetOption({"Guide", "CurrentGuide"}) or "Unknown"
        local activeStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
        if activeStep > 0 then
            -- Use the utility function to apply highlighting
            applyHighlighting(scrollChild, activeStep)
        end
    end
end

GLV.QuestTracker = QuestTracker
