--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
This is where Guides are registered.
A Guide is another Addon, and every lua (guides) file must begins with :
local GLV = LibStub("GuidelimeVanilla")
GLV:RegisterGuide(TEXT GUIDE, "Group Name")
]]--
local GLV = LibStub("GuidelimeVanilla")

GLV.loadedGuides = GLV.loadedGuides or {}

function GLV:RegisterGuide(guideText, group)
    local guide = self.Parser:parseGuide(guideText, group)
    if not guide then
        return
    end
    
    local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
    if not scrollChild then
        -- Don't return, continue to register the guide
    end

    if not self.loadedGuides[group] then
        self.loadedGuides[group] = {}
    end

    if guide.name ~= nil and guide.id ~= nil then
        if not self.loadedGuides[group][guide.id] then
            self.loadedGuides[group][guide.id] = {
                text = guideText,
                name = guide.name,
                minLevel = guide.minLevel,
                maxLevel = guide.maxLevel,
                description = guide.description
            }
            
            self.Settings:SetOption(group, {"Guide", "CurrentGroup"})
            
            -- Only populate dropdown if ScrollChild is available
            if scrollChild then
                self:PopulateDropdown(group)
            end
        end
    end
end

-- Function factory to create the dropdown callback function
local function createDropdownCallback(group, guideId, guideData, displayName, dropdown)
    return function()
        GLV:LoadGuide(group, guideId)
        UIDropDownMenu_SetSelectedValue(dropdown, guideId)
        UIDropDownMenu_SetText(displayName, dropdown)
    end
end

function GLV:PopulateDropdown(group)
    local dropdown = _G["GLV_MainDropdown"]
    if not dropdown then
        return
    end

    UIDropDownMenu_Initialize(dropdown, function()
        -- Check if we have any guides at all
        local totalGuides = 0
        for g, guides in pairs(self.loadedGuides) do
            if guides then
                for _ in pairs(guides) do totalGuides = totalGuides + 1 end
            end
        end
        
        if totalGuides == 0 then
            local info = {}
            info.text = "Aucun guide disponible"
            info.disabled = 1
            UIDropDownMenu_AddButton(info)
            return
        end
        
        -- Show all guides from all groups
        for g, guides in pairs(self.loadedGuides) do
            if guides and next(guides) then
                -- Add group header
                local groupInfo = {}
                groupInfo.text = "--- " .. g .. " ---"
                groupInfo.disabled = 1
                UIDropDownMenu_AddButton(groupInfo)
                
                -- Add guides from this group
                for guideId, guideData in pairs(guides) do
                    local info = {}
                    -- Add level range to guide name
                    local displayName = guideData.name
                    if guideData.minLevel and guideData.maxLevel then
                        displayName = guideData.name .. " (" .. guideData.minLevel .. "-" .. guideData.maxLevel .. ")"
                    end
                    info.text = displayName
                    info.value = guideId
                    -- Use the factory function to create the callback
                    info.func = createDropdownCallback(g, guideId, guideData, displayName, dropdown)
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end)
    
            -- Select the first available guide by default
    local selected = false
    for g, guides in pairs(self.loadedGuides) do
        if guides and next(guides) then
            for guideId, guideData in pairs(guides) do
                -- Add level range to guide name for display
                local displayName = guideData.name
                if guideData.minLevel and guideData.maxLevel then
                    displayName = guideData.name .. " (" .. guideData.minLevel .. "-" .. guideData.maxLevel .. ")"
                end
                
                UIDropDownMenu_SetSelectedValue(dropdown, guideId)
                UIDropDownMenu_SetText(displayName, dropdown)
                selected = true
                break
            end
            if selected then break end
        end
    end
    
    if not selected then
        UIDropDownMenu_SetText("Choisir un guide", dropdown)
    end
end

function GLV:LoadGuide(group, guideId)
    -- Clear TomTom waypoints when changing guide
    if GLV.TomTomIntegration then
        GLV.TomTomIntegration:ClearAllWaypoints()
    end
    
    local guideData = GLV.loadedGuides[group] and GLV.loadedGuides[group][guideId]
    if not guideData then
        return
    end
    
    local guide = GLV.Parser:parseGuide(guideData.text, group)
    if not guide then
        return
    end
    
    local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
    if not scrollChild then
        return
    end
    
    -- Save the current guide FIRST, before creating steps
    GLV.Settings:SetOption(guideId, {"Guide", "CurrentGuide"})
    
    -- Set current guide
    GLV.CurrentGuide = guide
    
    -- Call GuideWriter to create the guide steps
    GLV:CreateGuideSteps(scrollChild, guide, guideId)
    
    -- Force the scrollframe to update its size
    local scrollFrame = _G["GLV_MainScrollFrame"]
    if scrollFrame then
        -- Force a recalculation of the scroll range
        scrollFrame:UpdateScrollChildRect()
        -- Reset scroll position to top
        scrollFrame:SetVerticalScroll(0)
    end
    
    -- Restore saved state for this guide
    local savedStepState = GLV.Settings:GetOption({"Guide", "Guides", guideId, "StepState"}) or {}
    local savedCurrentStep = GLV.Settings:GetOption({"Guide", "Guides", guideId, "CurrentStep"}) or 0
    
    -- Apply saved step state to the UI
    if savedStepState and next(savedStepState) then
        for stepIndex, isCompleted in pairs(savedStepState) do
            if isCompleted then
                -- Find the step frame that corresponds to this original line index
                local foundStep = false
                for displayIndex, originalIndex in pairs(GLV.CurrentDisplayToOriginal) do
                    if originalIndex == stepIndex then
                        -- This is the step we want to restore
                        local stepFrame = _G[scrollChild:GetName() .. "Step" .. displayIndex]
                        if stepFrame then
                            local checkbox = _G[stepFrame:GetName() .. "Check"]
                            if checkbox then
                                checkbox:SetChecked(true)
                                foundStep = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Set current step and update highlighting
    if savedCurrentStep > 0 then
        GLV.Settings:SetOption(savedCurrentStep, {"Guide", "Guides", guideId, "CurrentStep"})
        -- Force highlighting update
        if GLV.QuestTracker then
            GLV.QuestTracker:RefreshHighlighting()
        end
    else
        -- If no saved step, set to first unchecked step
        local firstUnchecked = 1
        for i = 1, table.getn(guide.steps) do
            local stepFrame = _G[scrollChild:GetName() .. "Step" .. i]
            if stepFrame then
                local checkbox = _G[stepFrame:GetName() .. "Check"]
                if checkbox and not checkbox:GetChecked() then
                    firstUnchecked = i
                    break
                end
            end
        end
        GLV.Settings:SetOption(firstUnchecked, {"Guide", "Guides", guideId, "CurrentStep"})
        if GLV.QuestTracker then
            GLV.QuestTracker:RefreshHighlighting()
        end
    end
    
    -- Update TomTom waypoint for the current active step
    if GLV.TomTomIntegration then
        local currentStep = GLV.Settings:GetOption({"Guide", "Guides", guideId, "CurrentStep"}) or 0
        
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Updating TomTom for step: " .. currentStep)
        end
        
        if currentStep > 0 then
            local stepData = nil
            
            -- First try to get the step from CurrentDisplaySteps (which has all the coordinates)
            if GLV.CurrentDisplaySteps and GLV.CurrentDisplaySteps[currentStep] then
                stepData = GLV.CurrentDisplaySteps[currentStep]
                
                if GLV.Debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Using display step data")
                end
            -- Then fallback to raw guide steps
            elseif guide and guide.steps and guide.steps[currentStep] then
                stepData = guide.steps[currentStep]
                
                if GLV.Debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Using raw guide step data")
                end
            end
            
            -- Try to update waypoint if we have step data and TomTom is ready
            if stepData and TomTom and TomTom.AddMFWaypoint then
                -- Add safety check to prevent errors
                local success, err = pcall(function()
                    GLV.TomTomIntegration:OnStepChanged(stepData)
                end)
                if not success then
                    -- Log error but don't crash
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime]|r TomTom error: " .. tostring(err))
                end
            elseif GLV.Debug then
                if not stepData then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime]|r No step data found for step " .. currentStep)
                elseif not TomTom then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime]|r TomTom not available")
                elseif not TomTom.AddMFWaypoint then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime]|r TomTom.AddMFWaypoint not available")
                end
            end
        end
    end
    
    -- Apply highlighting using the existing function
    if GLV.QuestTracker then
        GLV.QuestTracker:RefreshHighlighting()
    end
    
    -- Update dropdown to reflect the loaded guide
    local dropdown = _G["GLV_MainDropdown"]
    if dropdown then
        local guideData = GLV.loadedGuides[group] and GLV.loadedGuides[group][guideId]
        if guideData then
            local displayName = guideData.name
            if guideData.minLevel and guideData.maxLevel then
                displayName = guideData.name .. " (" .. guideData.minLevel .. "-" .. guideData.maxLevel .. ")"
            end
            UIDropDownMenu_SetSelectedValue(dropdown, guideId)
            UIDropDownMenu_SetText(displayName, dropdown)
        end
    end
end

-- Commande de debug pour afficher loadedGuides
function GLV:DebugGuides()
    if not self.loadedGuides then
        return
    end
    
    local totalGroups = 0
    local totalGuides = 0
    
    for group, guides in pairs(self.loadedGuides) do
        totalGroups = totalGroups + 1
        
        if guides then
            local groupGuideCount = 0
            for guideId, guideData in pairs(guides) do
                groupGuideCount = groupGuideCount + 1
                totalGuides = totalGuides + 1
            end
        end
    end
end