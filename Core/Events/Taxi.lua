--[[
Guidelime Vanilla

Author: Grommey

Description:
Everything Taxi related. Get flypath, Take flypath, ..
]]--

local GLV = LibStub("GuidelimeVanilla")

local TaxiTracker = {}
GLV.TaxiTracker = TaxiTracker


-- Initialize character tracking and register event handlers
function TaxiTracker:Init()
    self.knownTaxiNodes = {}
    self.pendingCheck = false
    
    if GLV.Ace then
        GLV.Ace:RegisterEvent("TAXIMAP_OPENED", function() self:OnTaxiMapOpened() end)
    end

    local knownTaxiNodes = GLV.Settings:GetOption({"TaxiTracker", "KnownTaxiNodes"}) or {}
    self.knownTaxiNodes = knownTaxiNodes
    
    -- Debug: display known flight paths on load
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[TaxiTracker]|r Loaded " .. self:CountKnownNodes() .. " known taxi nodes")
    end
end

function TaxiTracker:OnTaxiMapOpened()
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[TaxiTracker]|r Taxi map opened")
    end
    self:CheckForNewFlightPaths()
end

function TaxiTracker:CheckForNewFlightPaths()   
    local newNodes = {}
    local discoveredNew = false
    
    local numNodes = NumTaxiNodes()
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[TaxiTracker]|r Scanning " .. numNodes .. " taxi nodes")
    end
    
    for i = 1, numNodes do
        local name = TaxiNodeName(i)
        local nodeType = TaxiNodeGetType(i)
        
        if name and (nodeType == "CURRENT" or nodeType == "REACHABLE") then
            newNodes[name] = true
            
            -- Check if this is a new node
            if not self.knownTaxiNodes[name] then
                if GLV.Debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[TaxiTracker]|r New flight path discovered: " .. name)
                end
                self:OnFlightPathDiscovered(name, i)
                discoveredNew = true
            end
        end
    end
    
    for nodeName, _ in pairs(newNodes) do
        self.knownTaxiNodes[nodeName] = true
    end
    
    if discoveredNew then
        self:SaveKnownTaxiNodes()
    end

end

function TaxiTracker:OnFlightPathDiscovered(flightPathName, nodeIndex)
    if GLV.Debug then
        GLV.Ace:Print("TaxiTracker", "Flight path discovered: " .. flightPathName .. " (index: " .. nodeIndex .. ")")
    end

    -- Trigger event with details
    self:TriggerEvent("GLV_FLIGHT_PATH_DISCOVERED", flightPathName, nodeIndex)

    -- Auto-complete guide steps for this flight path
    self:CheckAndCompleteGuideSteps(flightPathName)
end

function TaxiTracker:CheckAndCompleteGuideSteps(flightPathName)
    if not GLV.CurrentGuide or not GLV.CurrentDisplaySteps then
        GLV.Ace:Print("TaxiTracker", "No current guide or display steps available")
        return
    end
    
    local guide = GLV.CurrentGuide
    local currentGuideId = guide.id or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local hasCompletedStep = false
    
    if GLV.Debug then
        GLV.Ace:Print("TaxiTracker", "Checking guide steps for flight path: " .. flightPathName)
    end

    -- Iterate through all steps in the current guide
    for displayIndex, stepData in ipairs(GLV.CurrentDisplaySteps) do
        if stepData.hasCheckbox and stepData.lines then
            for _, line in ipairs(stepData.lines) do
                -- Look for steps that mention this flight path
                if line.text and line.stepType == "GET_FP" then
                    -- Extract the flight path name from the step
                    local stepFlightPath = line.destination
                    
                    if stepFlightPath and self:IsFlightPathMatch(stepFlightPath, flightPathName) then
                        if GLV.Debug then
                            GLV.Ace:Print("TaxiTracker", "Found matching step for flight path: " .. stepFlightPath .. " -> " .. flightPathName)
                        end

                        -- Get the original index for this step
                        local originalIndex = GLV.CurrentDisplayToOriginal[displayIndex]
                        
                        if originalIndex and not stepState[originalIndex] then
                            -- Mark step as completed
                            stepState[originalIndex] = true
                            GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})

                            -- Update checkbox visually
                            local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
                            if scrollChild then
                                local stepFrameName = scrollChild:GetName().."Step"..currentGuideId.."_"..displayIndex
                                local stepFrame = getglobal(stepFrameName)
                                if stepFrame then
                                    local checkbox = getglobal(stepFrameName .. "Check")
                                    if checkbox then
                                        checkbox:SetChecked(true)
                                        if GLV.Debug then
                                            GLV.Ace:Print("TaxiTracker", "Auto-checked step " .. displayIndex .. " for flight path: " .. flightPathName)
                                        end
                                    end
                                end
                            end

                            hasCompletedStep = true

                            -- Chat message
                            GLV.Ace:Print("|cFF00FF00[GuideLime]|r Auto-completed step: Flight path " .. flightPathName)
                        end
                    end
                end
            end
        end
    end
    
    -- If a step was completed, update the active step
    if hasCompletedStep then
        self:UpdateActiveStep()
    end
end

function TaxiTracker:IsFlightPathMatch(stepName, discoveredName)
    if not stepName or not discoveredName then return false end

    local stepLower = string.lower(stepName)
    local discoveredLower = string.lower(discoveredName)

    -- Exact match
    if stepLower == discoveredLower then
        return true
    end

    -- Partial match (one contains the other)
    if string.find(stepLower, discoveredLower) or string.find(discoveredLower, stepLower) then
        return true
    end

    -- Specific aliases to handle name variations
    local aliases = {
        ["stormwind"] = {"stormwind city", "stormwind keep"},
        ["ironforge"] = {"ironforge city"},
        ["orgrimmar"] = {"orgrimmar city"},
        ["undercity"] = {"undercity", "tirisfal"},
    }
    
    for canonical, variants in pairs(aliases) do
        if stepLower == canonical or discoveredLower == canonical then
            for _, variant in ipairs(variants) do
                if stepLower == variant or discoveredLower == variant then
                    return true
                end
            end
        end
    end
    
    return false
end

function TaxiTracker:UpdateActiveStep()
    if not GLV.CurrentGuide or not GLV.CurrentDisplaySteps then return end
    
    local guide = GLV.CurrentGuide
    local currentGuideId = guide.id or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    local currentActiveStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0

    -- Find the next uncompleted step
    local newActiveStep = currentActiveStep
    local totalSteps = table.getn(GLV.CurrentDisplaySteps)
    
    for i = currentActiveStep, totalSteps do
        if GLV.CurrentDisplaySteps[i] and GLV.CurrentDisplaySteps[i].hasCheckbox then
            local originalIndex = GLV.CurrentDisplayToOriginal[i]
            if originalIndex and not stepState[originalIndex] then
                newActiveStep = i
                break
            end
        end
    end
    
    -- If a new active step was found, update it
    if newActiveStep ~= currentActiveStep then
        GLV.Settings:SetOption(newActiveStep, {"Guide", "Guides", currentGuideId, "CurrentStep"})
        GLV_MainLoadedGuideCounter:SetText("("..tostring(newActiveStep).."/"..tostring(totalSteps)..")")

        -- Update visual colors using unified highlighting system
        local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
        if scrollChild and GLV.updateStepColors and GLV.CurrentDisplaySteps then
            GLV.updateStepColors(scrollChild, currentGuideId, GLV.CurrentDisplaySteps, newActiveStep)
        end

        -- Scroll to the new active step
        if GLV_MainScrollFrame and newActiveStep > 0 then
            GLV.Ace:ScheduleEvent(function()
                if GLV_MainScrollFrame then
                    local targetScroll = 0
                    local scrollChild = GLV_MainScrollFrameScrollChild
                    
                    for i = 1, newActiveStep - 1 do
                        local stepFrame = getglobal(scrollChild:GetName().."Step"..currentGuideId.."_"..i)
                        if stepFrame and stepFrame.GetHeight then
                            targetScroll = targetScroll + stepFrame:GetHeight()
                        end
                    end
                    
                    if newActiveStep > 1 then
                        targetScroll = targetScroll + (4 * (newActiveStep - 1)) -- spacing
                    end
                    
                    targetScroll = math.max(0, targetScroll)
                    local maxScroll = GLV_MainScrollFrame:GetVerticalScrollRange()
                    if maxScroll and maxScroll > 0 then
                        targetScroll = math.min(targetScroll, maxScroll)
                    end
                    GLV_MainScrollFrame:SetVerticalScroll(targetScroll)
                end
            end, 0.5)
        end
        
        if GLV.Debug then
            GLV.Ace:Print("TaxiTracker", "Updated active step to: " .. newActiveStep)
        end
    end
end

-- Utility functions
function TaxiTracker:SaveKnownTaxiNodes()
    GLV.Settings:SetOption(self.knownTaxiNodes, {"TaxiTracker", "KnownTaxiNodes"})
    if GLV.Debug then
        GLV.Ace:Print("TaxiTracker", "Saved " .. self:CountKnownNodes() .. " known taxi nodes")
    end
end

function TaxiTracker:CountKnownNodes()
    local count = 0
    for _ in pairs(self.knownTaxiNodes) do
        count = count + 1
    end
    return count
end

function TaxiTracker:IsFlightPathKnown(nodeName)
    return self.knownTaxiNodes[nodeName] == true
end

function TaxiTracker:GetKnownFlightPaths()
    local paths = {}
    for nodeName, _ in pairs(self.knownTaxiNodes) do
        table.insert(paths, nodeName)
    end
    return paths
end

function TaxiTracker:TriggerEvent(eventName, ...)
    if not self.eventCallbacks then
        self.eventCallbacks = {}
    end
    
    if self.eventCallbacks[eventName] then
        for _, callback in pairs(self.eventCallbacks[eventName]) do
            callback(unpack(arg))
        end
    end
end

function TaxiTracker:RegisterCallback(eventName, callback)
    if not self.eventCallbacks then
        self.eventCallbacks = {}
    end
    if not self.eventCallbacks[eventName] then
        self.eventCallbacks[eventName] = {}
    end
    table.insert(self.eventCallbacks[eventName], callback)
end
