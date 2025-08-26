--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
Quest Tracker. Track when quests are accepted / completed
]]--
local GLV = LibStub("GuidelimeVanilla")

local QuestTracker = {}
GLV.QuestTracker = QuestTracker

-- Initialize quest tracking, hook original functions and register event handlers
function QuestTracker:Init()
    local store = GLV.Settings:GetOption({"QuestTracker"}) or {}
    self.store = store

    if GLV.Ace then
        GLV.Ace:Hook("QuestDetailAcceptButton_OnClick", HookQuestAccept)
        GLV.Ace:Hook("QuestRewardCompleteButton_OnClick", HookQuestComplete)
        GLV.Ace:Hook("AbandonQuest", HookQuestAbandon)

        GLV.Ace:RegisterEvent("QUEST_LOG_UPDATE", function() self:OnQuestLogUpdate() end)
    end
    
    self.previousQuestStates = {}
end


--[[ LOCAL FUNCTIONS ]]--

-- Utility function to apply highlighting to all frames
local function applyHighlighting(scrollChild, activeStepIndex)
    if not scrollChild then return end
    
    local totalSteps = GLV.CurrentDisplayStepsCount or 0
    if totalSteps == 0 then
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


--[[ EVENTS ]]--

-- Handle quest log updates and check for completed objectives
function QuestTracker:OnQuestLogUpdate()
    if not GLV.CurrentDisplaySteps then
        return
    end
    
    local autoObjectiveTracking = GLV.Settings:GetOption({"QuestTracker", "AutoObjectiveTracking"}) or true
    if autoObjectiveTracking == false then
        return
    end
    
    local numEntries, numQuests = GetNumQuestLogEntries()
    
    for questIndex = 1, numEntries do
        local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(questIndex)
        
        if questLogTitleText and not isHeader then
            local questId = GLV:GetQuestIDByName(questLogTitleText)
            local numId = tonumber(questId)

            GLV:GetQuestAllCoords()
            
            if numId then
                self:CheckQuestObjectives(questIndex, numId, questLogTitleText, isComplete)
            end
        end
    end
end


--[[ OBJECTS FUNCTIONS ]]--

-- Check objectives for a specific quest and handle completion
function QuestTracker:CheckQuestObjectives(questIndex, questId, questTitle, isComplete)
    SelectQuestLogEntry(questIndex)
    
    local questDescription, questObjectives = GetQuestLogQuestText()
    
    local currentObjectivesState = {}
    local numObjectives = GetNumQuestLeaderBoards()
    
    for i = 1, numObjectives do
        local description, objectiveType, isCompleted = GetQuestLogLeaderBoard(i)
        if description then
            currentObjectivesState[i] = {
                description = description,
                isCompleted = isCompleted
            }
        end
    end
    
    if isComplete and isComplete == 1 then
        local currentState = self.previousQuestStates[questId]
        if not currentState or not currentState.wasComplete then
            
            self:HandleQuestAction(questId, questTitle, "COMPLETE")
            
            self.previousQuestStates[questId] = {
                wasComplete = true,
                lastObjectives = questObjectives,
                objectivesState = currentObjectivesState
            }
        end
    else
        self.previousQuestStates[questId] = {
            wasComplete = false,
            lastObjectives = questObjectives,
            objectivesState = currentObjectivesState
        }
    end
end


-- Track when a quest is accepted and handle related actions
function QuestTracker:TrackAccepted(id, title)
    if not id or type(id) ~= "number" then
        return
    end

    local store = self.store or GLV.Settings:GetOption({"QuestTracker"}) or {}
    if not store.Accepted then store.Accepted = {} end

    if id and not store.Accepted[id] then
        store.Accepted[id] = {
            title = title,
            timestamp = time()
        }
        GLV.Settings:SetOption(store, {"QuestTracker"})
        
        self:HandleQuestAction(id, title, "ACCEPT")
    end
end

-- Centralized function to handle quest actions (accept, complete, turnin)
function QuestTracker:HandleQuestAction(questId, title, actionType)
    
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local stepQuestState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepQuestState"}) or {}
    
    local stepMarked = false
    local multiActionStepFound = false
    local questStateChanged = false
    
    if not GLV.CurrentDisplaySteps then
        return
    end
    
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    
    for di = 1, diCount do
        local step = GLV.CurrentDisplaySteps[di]
        local origIdx = diToOrig[di]
        
        if step and origIdx then
            
            if step.questTags and table.getn(step.questTags) > 0 then
                if not stepQuestState[origIdx] then
                    stepQuestState[origIdx] = {}
                end
                
                local hasMatchingAction = false
                local allActionsDone = true
                
                for _, questTag in ipairs(step.questTags) do
                    local actionKey = questTag.questId .. "_" .. questTag.tag
                    
                    if questTag.tag == actionType and questTag.questId == questId then
                        stepQuestState[origIdx][actionKey] = true
                        hasMatchingAction = true
                        multiActionStepFound = true
                        questStateChanged = true
                    end
                    
                    if not stepQuestState[origIdx][actionKey] then
                        allActionsDone = false
                    end
                end
                
                if hasMatchingAction then
                    -- CORRECTION : Sauvegarder stepQuestState immédiatement
                    GLV.Settings:SetOption(stepQuestState, {"Guide","Guides", currentGuideId, "StepQuestState"})
                    
                    -- CORRECTION : Ne marquer stepState que si TOUTES les actions sont terminées
                    if allActionsDone and not stepState[origIdx] then
                        stepState[origIdx] = true
                        stepMarked = true
                        -- Sauvegarder stepState immédiatement
                        GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
                    end
                    
                    break
                end
            end
        end
    end
    
    -- CORRECTION : Passer aussi questStateChanged pour indiquer un changement d'état
    self:UpdateStepNavigation(stepMarked, multiActionStepFound or questStateChanged)
    
    if GLV.CharacterTracker then
        GLV.CharacterTracker:CheckCurrentStepXPRequirements()
    end
end

-- Handle navigation between steps and update UI highlighting
function QuestTracker:UpdateStepNavigation(stepMarked, multiActionStepFound)
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local stepQuestState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepQuestState"}) or {}
    
    local diCount = GLV.CurrentDisplayStepsCount or 0
    local hasCb = GLV.CurrentDisplayHasCheckbox or {}
    local diToOrig = GLV.CurrentDisplayToOriginal or {}
    
    -- Get current active step before potentially changing it
    local currentActiveStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
    local newActiveStep = currentActiveStep
    
    -- CORRECTION : Synchroniser stepState avec stepQuestState pour les étapes multi-actions
    local stateChanged = false
    for di = 1, diCount do
        local step = GLV.CurrentDisplaySteps[di]
        local origIdx = diToOrig[di]
        
        if step and origIdx and step.questTags and table.getn(step.questTags) > 0 then
            if stepQuestState[origIdx] then
                local allActionsDone = true
                for _, questTag in ipairs(step.questTags) do
                    local actionKey = questTag.questId .. "_" .. questTag.tag
                    if not stepQuestState[origIdx][actionKey] then
                        allActionsDone = false
                        break
                    end
                end
                
                -- CORRECTION : Mettre à jour stepState si toutes les actions sont terminées
                if allActionsDone and not stepState[origIdx] then
                    stepState[origIdx] = true
                    stateChanged = true
                elseif not allActionsDone and stepState[origIdx] then
                    -- Si une action a été annulée, décocher l'étape
                    stepState[origIdx] = false
                    stateChanged = true
                end
            end
        end
    end
    
    -- Sauvegarder les changements d'état
    if stateChanged then
        GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
    end
    
    -- Only recalculate if we really need to (step was marked as completed)
    if stepMarked or stateChanged then
        local firstUnchecked = 0
        
        for di = 1, diCount do
            if hasCb[di] then
                local origIdx = diToOrig[di]
                if origIdx then
                    local stepCompleted = stepState[origIdx]
                    
                    -- CORRECTION : Vérifier aussi les étapes multi-actions
                    if not stepCompleted then
                        local step = GLV.CurrentDisplaySteps[di]
                        if step and step.questTags and table.getn(step.questTags) > 0 and stepQuestState[origIdx] then
                            local allDone = true
                            for _, questTag in ipairs(step.questTags) do
                                local actionKey = questTag.questId .. "_" .. questTag.tag
                                if not stepQuestState[origIdx][actionKey] then
                                    allDone = false
                                    break
                                end
                            end
                            stepCompleted = allDone
                        end
                    end
                    
                    if not stepCompleted then
                        firstUnchecked = di
                        break
                    end
                end
            end
        end
        
        -- CORRECTION : Logique de navigation plus précise
        if firstUnchecked > 0 then
            -- Il y a encore des étapes non terminées
            newActiveStep = firstUnchecked
        else
            -- Toutes les étapes sont terminées, rester sur la dernière étape valide
            newActiveStep = currentActiveStep > 0 and currentActiveStep or diCount
        end
    else
        -- Si aucune étape n'a été modifiée, garder l'étape active actuelle
        newActiveStep = currentActiveStep
    end
    
    -- Only update if step actually changed
    if newActiveStep ~= currentActiveStep then
        GLV.Settings:SetOption(newActiveStep, {"Guide", "Guides", currentGuideId, "CurrentStep"})
        -- CORRECTION : Mettre à jour le compteur immédiatement
        if GLV_MainLoadedGuideCounter then
            GLV_MainLoadedGuideCounter:SetText("("..tostring(newActiveStep).."/"..tostring(diCount)..")")
        end
    end
    
    if newActiveStep > 0 then
        local scrollChild = GLV_MainScrollFrameScrollChild
        if scrollChild then
            -- CORRECTION : Mettre à jour toutes les cases à cocher selon l'état réel
            for di = 1, diCount do
                if hasCb[di] then
                    local origIdx = diToOrig[di]
                    if origIdx then
                        local frameName = scrollChild:GetName().."Step"..di
                        local check = getglobal(frameName.."Check")
                        if check and check.SetChecked then
                            local isCompleted = stepState[origIdx] or false
                            
                            -- Vérifier aussi les étapes multi-actions
                            if not isCompleted then
                                local step = GLV.CurrentDisplaySteps[di]
                                if step and step.questTags and table.getn(step.questTags) > 0 and stepQuestState[origIdx] then
                                    local allDone = true
                                    for _, questTag in ipairs(step.questTags) do
                                        local actionKey = questTag.questId .. "_" .. questTag.tag
                                        if not stepQuestState[origIdx][actionKey] then
                                            allDone = false
                                            break
                                        end
                                    end
                                    isCompleted = allDone
                                end
                            end
                            
                            check:SetChecked(isCompleted)
                        end
                    end
                end
            end
            
            applyHighlighting(scrollChild, newActiveStep)
            
            if newActiveStep > 0 and GLV_MainScrollFrame then
                -- CORRECTION : Déterminer si on scroll ou pas selon le contexte
                local shouldScroll = false
                
                -- Scroll seulement si on avance vers une nouvelle étape (pas si on recule)
                if newActiveStep > currentActiveStep then
                    shouldScroll = true
                elseif stepMarked then
                    -- Si une étape a été marquée automatiquement, on peut scroller
                    shouldScroll = true
                end
                
                if shouldScroll then
                    local targetScroll = 0
                    for i = 1, newActiveStep - 1 do
                        local stepFrameName = scrollChild:GetName().."Step"..i
                        local stepFrame = getglobal(stepFrameName)
                        if stepFrame and stepFrame.GetHeight then
                            targetScroll = targetScroll + stepFrame:GetHeight()
                        end
                    end
                    if newActiveStep > 1 then
                        local spacing = -4
                        targetScroll = targetScroll + (math.abs(spacing) * (newActiveStep - 1))
                    end
                    targetScroll = math.max(0, targetScroll)
                    local maxScroll = GLV_MainScrollFrame:GetVerticalScrollRange()
                    if maxScroll and maxScroll > 0 then
                        targetScroll = math.min(targetScroll, maxScroll)
                    end
                    GLV_MainScrollFrame:SetVerticalScroll(targetScroll)
                end
            end
            
            if GLV.GuideNavigation and GLV.CurrentDisplaySteps and GLV.CurrentDisplaySteps[newActiveStep] then
                local stepData = GLV.CurrentDisplaySteps[newActiveStep]
                GLV.GuideNavigation:OnStepChanged(stepData)
            end
        end
    end
end

-- Public function to refresh highlighting (can be called from GuideWriter)
function QuestTracker:RefreshHighlighting()
    local scrollChild = getglobal("GLV_MainScrollFrameScrollChild")
    if scrollChild then
        local currentGuideId = GLV.Settings:GetOption({"Guide", "CurrentGuide"}) or "Unknown"
        local activeStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
        
        if activeStep > 0 then
            -- Check if the active step is still valid (not completed)
            local stepState = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "StepState"}) or {}
            local diToOrig = GLV.CurrentDisplayToOriginal or {}
            
            if diToOrig[activeStep] then
                local origIdx = diToOrig[activeStep]
                local stepCompleted = stepState[origIdx]
                
                if stepCompleted then
                    -- Active step is completed, find the next valid step
                    local diCount = GLV.CurrentDisplayStepsCount or 0
                    local hasCb = GLV.CurrentDisplayHasCheckbox or {}
                    
                    for di = 1, diCount do
                        if hasCb[di] then
                            local orig = diToOrig[di]
                            if orig and not stepState[orig] then
                                -- Found next valid step, update it
                                GLV.Settings:SetOption(di, {"Guide", "Guides", currentGuideId, "CurrentStep"})
                                activeStep = di
                                break
                            end
                        end
                    end
                end
            end
            
            -- Apply highlighting to the valid active step
            if activeStep > 0 then
                applyHighlighting(scrollChild, activeStep)
            end
        end
    end
end

function QuestTracker:GetExpectedQuestIdFromCurrentStep(questTitle)
    if not GLV.CurrentDisplaySteps then
        return nil
    end
    
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local currentStepIndex = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
    
    -- Chercher dans l'étape courante et les quelques étapes suivantes
    for offset = 0, 2 do
        local stepIndex = currentStepIndex + offset
        if stepIndex > 0 and stepIndex <= table.getn(GLV.CurrentDisplaySteps) then
            local step = GLV.CurrentDisplaySteps[stepIndex]
            
            if step and step.questTags and table.getn(step.questTags) > 0 then
                for _, questTag in ipairs(step.questTags) do
                    if questTag.tag == "ACCEPT" then
                        -- Vérifier si le nom correspond (comparaison flexible)
                        local questName = GLV:GetQuestNameByID(questTag.questId)
                        if questName and self:QuestNamesMatch(questTitle, questName) then
                            return questTag.questId
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

function QuestTracker:QuestNamesMatch(title1, title2)
    if not title1 or not title2 then return false end
    
    -- Comparaison directe
    if title1 == title2 then return true end
    
    -- Comparaison insensible à la casse
    if string.lower(title1) == string.lower(title2) then return true end
    
    -- Comparaison en enlevant la ponctuation et espaces extras
    local clean1 = string.gsub(string.lower(title1), "[%p%s]+", "")
    local clean2 = string.gsub(string.lower(title2), "[%p%s]+", "")
    if clean1 == clean2 then return true end
    
    return false
end

function QuestTracker:VerifyQuestAfterAccept(expectedTitle, expectedId)
    -- Vérifier que la quête est bien dans le journal avec le bon ID
    GLV.Ace:ScheduleEvent("VerifyQuest", function()
        local numEntries, numQuests = GetNumQuestLogEntries()
        
        for i = 1, numEntries do
            local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
            
            if questLogTitleText and not isHeader and questLogTitleText == expectedTitle then
                -- La quête est dans le journal
                -- Vous pouvez ajouter d'autres vérifications ici si nécessaire
                return true
            end
        end
        
        return false
    end, 0.5)
end


--[[ HOOKS ]]--

-- Hook function for quest accept button
function HookQuestAccept()
    local title = GetTitleText()
    
    -- Trouver l'ID de quête basé sur l'étape courante du guide
    local correctQuestId = GLV.QuestTracker:GetExpectedQuestIdFromCurrentStep(title)
    
    if correctQuestId then
        GLV.QuestTracker:TrackAccepted(correctQuestId, title)
    else
        -- Fallback sur l'ancienne méthode
        local id = GLV:GetQuestIDByName(title)
        local numId = tonumber(id)
        if numId then
            GLV.QuestTracker:TrackAccepted(numId, title)
        end
    end
    
    GLV.Ace.hooks["QuestDetailAcceptButton_OnClick"]()
end

-- Hook function for quest complete button
function HookQuestComplete()
    local title = GetTitleText()
    local id = nil
    
    -- Trouver l'ID de quête basé sur l'étape courante du guide
    local id = GLV.QuestTracker:GetExpectedQuestIdFromCurrentStep(title)

    if not id then
        id = GLV:GetQuestIDByName(title)
    end

    local numId = tonumber(correctQuestId)
    
    local store = GLV.QuestTracker and GLV.QuestTracker.store or GLV.Settings:GetOption({"QuestTracker"}) or GLV.Settings:GetDefaults().char.QuestTracker
    if store and store.Completed and numId then
        store.Completed[numId] = { title = title, timestamp = time() }
        GLV.Settings:SetOption(store, {"QuestTracker"})
    end
    
    if numId then
        GLV.QuestTracker:HandleQuestAction(numId, title, "TURNIN")
    end
    
    GLV.Ace.hooks["QuestRewardCompleteButton_OnClick"]()
end

-- Hook function for quest abandon
function HookQuestAbandon()
    local title = GetAbandonQuestName()
    if title then
        local id = GLV:GetQuestIDByName(title)
        local numId = tonumber(id)
        if numId and GLV.QuestTracker then
            local store = GLV.QuestTracker.store or GLV.Settings:GetOption({"QuestTracker"}) or {}
            if store.Accepted and store.Accepted[numId] then
                store.Accepted[numId] = nil
                GLV.Settings:SetOption(store, {"QuestTracker"})
            end
        end
    end
    GLV.Ace.hooks["AbandonQuest"]()
end

SLASH_GLVTESTQUEST1 = "/glvtestquest"
SlashCmdList["GLVTESTQUEST"] = function(msg)
    if msg and msg ~= "" then
        local questId = GLV.QuestTracker:GetExpectedQuestIdFromCurrentStep(msg)
        if questId then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GuideLime]|r Expected quest ID for '" .. msg .. "': " .. questId)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime]|r No expected quest ID found for: " .. msg)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /glvtestquest <quest name>")
    end
end