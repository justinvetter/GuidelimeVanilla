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
        

        
        -- Mark the corresponding guide step as done using questId
        local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
        local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
        local firstUnchecked = 0
        
        if GLV.CurrentGuide and GLV.CurrentGuide.steps then
            -- Find and mark the step as done
            for origIdx, step in ipairs(GLV.CurrentGuide.steps) do
                if step.questId and tonumber(step.questId) == tonumber(id) then
                    stepState[origIdx] = true
                    break
                end
            end
            
            -- Save stepState
            GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
            
            -- Find the NEXT unchecked step (not the current one)
            local diCount = GLV.CurrentDisplayStepsCount or 0
            local hasCb = GLV.CurrentDisplayHasCheckbox or {}
            local diToOrig = GLV.CurrentDisplayToOriginal or {}
            
            -- First, find which display index corresponds to the step we just completed
            local completedDisplayIndex = 0
            for di = 1, diCount do
                if hasCb[di] and diToOrig[di] then
                    for origIdx, step in ipairs(GLV.CurrentGuide.steps) do
                        if step.questId and tonumber(step.questId) == tonumber(id) and diToOrig[di] == origIdx then
                            completedDisplayIndex = di
                            break
                        end
                    end
                    if completedDisplayIndex > 0 then break end
                end
            end
            
            -- Now find the NEXT unchecked step after the completed one
            for di = completedDisplayIndex + 1, diCount do
                if hasCb[di] then
                    local nextOriginal = diToOrig[di]
                    if nextOriginal and not stepState[nextOriginal] then
                        firstUnchecked = di
                        break
                    end
                end
            end
            
                            -- If no next step found, look from the beginning
                if firstUnchecked == 0 then
                    for di = 1, diCount do
                        if hasCb[di] then
                            local nextOriginal = diToOrig[di]
                            if nextOriginal and not stepState[nextOriginal] then
                                firstUnchecked = di
                                break
                            end
                        end
                    end
                end
            
            GLV.Settings:SetOption(firstUnchecked, {"Guide", "Guides", currentGuideId, "CurrentStep"})
            
            -- Update visual highlighting immediately
            if firstUnchecked > 0 then
                local scrollChild = GLV_MainScrollFrameScrollChild
                if scrollChild then
                    -- Force checkbox update for the completed step
                    if completedDisplayIndex > 0 then
                        local frameName = scrollChild:GetName().."Step"..completedDisplayIndex
                        local check = getglobal(frameName.."Check")
                        if check and check.SetChecked then
                            check:SetChecked(true)
                        end
                    end
                    
                    -- Apply highlighting to the NEXT step
                    applyHighlighting(scrollChild, firstUnchecked)
                end
            end
            
            -- Temporarily disable RefreshGuide to test highlighting
            -- if GLV.RefreshGuide then GLV:RefreshGuide() end
        end
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
    -- Optionally mark completed store and refresh UI/advance
    local store = GLV.QuestTracker and GLV.QuestTracker.store or GLV.Settings:GetOption({"QuestTracker"}) or {}
    if store and store.completed then
        store.completed[id] = { title = title, timestamp = time() }
        GLV.Settings:SetOption(store, {"QuestTracker"})
    end
    -- Recompute active step
    local currentGuideId = GLV.Settings:GetOption({"Guide","CurrentGuide"}) or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local firstUnchecked = 0
    if GLV.CurrentGuide and GLV.CurrentGuide.steps then
        local totalSteps = table.getn(GLV.CurrentGuide.steps)
        for i2 = 1, totalSteps do
            local st = GLV.CurrentGuide.steps[i2]
            if st and st.hasCheckbox and not stepState[i2] then
                firstUnchecked = i2
                break
            end
        end
        GLV.Settings:SetOption(firstUnchecked, {"Guide", "Guides", currentGuideId, "CurrentStep"})
    end
    if GLV.RefreshGuide then GLV:RefreshGuide() end
    originalQuestRewardCompleteButton_OnClick();
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
