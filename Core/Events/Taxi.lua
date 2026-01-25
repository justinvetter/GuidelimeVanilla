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
    
    -- Debug: afficher les points de vol connus au chargement
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
            
            -- Vérifier si c'est un nouveau nœud
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
    GLV.Ace:Print("TaxiTracker", "Flight path discovered: " .. flightPathName .. " (index: " .. nodeIndex .. ")")
    
    -- Déclencher l'événement avec les détails
    self:TriggerEvent("GLV_FLIGHT_PATH_DISCOVERED", flightPathName, nodeIndex)
    
    -- NOUVELLE FONCTIONNALITÉ: Auto-complétion des étapes de guide
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
    
    GLV.Ace:Print("TaxiTracker", "Checking guide steps for flight path: " .. flightPathName)
    
    -- Parcourir toutes les étapes du guide actuel
    for displayIndex, stepData in ipairs(GLV.CurrentDisplaySteps) do
        if stepData.hasCheckbox and stepData.lines then
            for _, line in ipairs(stepData.lines) do
                -- Chercher les étapes qui mentionnent ce point de vol
                if line.text and line.stepType == "GET_FP" then
                    -- Extraire le nom du point de vol de l'étape
                    local stepFlightPath = line.destination
                    
                    if stepFlightPath and self:IsFlightPathMatch(stepFlightPath, flightPathName) then
                        GLV.Ace:Print("TaxiTracker", "Found matching step for flight path: " .. stepFlightPath .. " -> " .. flightPathName)
                        
                        -- Obtenir l'index original de cette étape
                        local originalIndex = GLV.CurrentDisplayToOriginal[displayIndex]
                        
                        if originalIndex and not stepState[originalIndex] then
                            -- Marquer l'étape comme complétée
                            stepState[originalIndex] = true
                            GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
                            
                            -- Mettre à jour visuellement la checkbox
                            local stepFrameName = scrollChild:GetName().."Step"..currentGuideId.."_"..i
                            local stepFrame = getglobal(stepFrameName)
                            if stepFrame then
                                local checkbox = getglobal(stepFrameName .. "Check")
                                if checkbox then
                                    checkbox:SetChecked(true)
                                    GLV.Ace:Print("TaxiTracker", "Auto-checked step " .. displayIndex .. " for flight path: " .. flightPathName)
                                end
                            end
                            
                            hasCompletedStep = true
                            
                            -- Message dans le chat
                            GLV.Ace:Print("|cFF00FF00[GuideLime]|r Étape auto-complétée : Point de vol " .. flightPathName)
                        end
                    end
                end
            end
        end
    end
    
    -- Si une étape a été complétée, mettre à jour l'étape active
    if hasCompletedStep then
        self:UpdateActiveStep()
    end
end

function TaxiTracker:IsFlightPathMatch(stepName, discoveredName)
    if not stepName or not discoveredName then return false end
    
    local stepLower = string.lower(stepName)
    local discoveredLower = string.lower(discoveredName)
    
    -- Correspondance exacte
    if stepLower == discoveredLower then
        return true
    end
    
    -- Correspondance partielle (l'un contient l'autre)
    if string.find(stepLower, discoveredLower) or string.find(discoveredLower, stepLower) then
        return true
    end
    
    -- Correspondances spécifiques pour gérer les variations de noms
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
    
    -- Trouver la prochaine étape non complétée
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
    
    -- Si une nouvelle étape active a été trouvée, la mettre à jour
    if newActiveStep ~= currentActiveStep then
        GLV.Settings:SetOption(newActiveStep, {"Guide", "Guides", currentGuideId, "CurrentStep"})
        GLV_MainLoadedGuideCounter:SetText("("..tostring(newActiveStep).."/"..tostring(totalSteps)..")")
        
        -- Mettre à jour les couleurs visuelles
        for i = 1, totalSteps do
            local stepFrameName = GLV_MainScrollFrameScrollChild:GetName() .. "Step" .. currentGuideId .. "_" .. i
            local stepFrame = getglobal(stepFrameName)
            if stepFrame and stepFrame.SetBackdropColor then
                local color = (i == newActiveStep) and {0.8,0.8,0.2,0.9} or (isEven(i) and {0.2,0.2,0.2,0.8} or {0.1,0.1,0.1,0.8})
                stepFrame:SetBackdropColor(unpack(color))
            end
        end
        
        -- Scroll vers la nouvelle étape active
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
        
        GLV.Ace:Print("TaxiTracker", "Updated active step to: " .. newActiveStep)
    end
end

-- Fonctions utilitaires
function TaxiTracker:SaveKnownTaxiNodes()
    GLV.Settings:SetOption(self.knownTaxiNodes, {"TaxiTracker", "KnownTaxiNodes"})
    GLV.Ace:Print("TaxiTracker", "Saved " .. self:CountKnownNodes() .. " known taxi nodes")
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
