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
        GLV.Ace:RegisterEvent("ADDON_LOADED", function() self:OnAddonLoaded() end)
        GLV.Ace:RegisterEvent("CHAT_MSG_SYSTEM", function() self:OnChatMsg() end)
        GLV.Ace:RegisterEvent("TAXIMAP_OPENED", function() self:OnTaxiMapOpened() end)

        GLV.Ace:Hook("TaxiFrame_OnShow", function() self:OnTaxiMapOpened() end)
    end
end

function TaxiTracker:OnAddonLoaded()
    if event == "ADDON_LOADED" and arg1 == GLV.addonName then
        local knownTaxiNodes = GLV.Settings:GetOption({"TaxiTracker", "KnownTaxiNodes"}) or {}
        self.knownTaxiNodes = knownTaxiNodes
        
        -- Debug: afficher les points de vol connus au chargement
        GLV:Debug("TaxiTracker", "Loaded " .. self:CountKnownNodes() .. " known taxi nodes")
    end
end

function TaxiTracker:OnChatMsg()
    if not arg1 then return end
    
    -- Utiliser la constante localisée ERR_NEWTAXIPATH
    if arg1 == ERR_NEWTAXIPATH then
        GLV:Debug("TaxiTracker", "New flight path message detected: " .. arg1)
        self:OnNewFlightPathLearned()
        return
    end
end

-- Plus besoin de cette fonction, on utilise ERR_NEWTAXIPATH directement
-- function TaxiTracker:IsFlightPathMessage(message)

function TaxiTracker:OnNewFlightPathLearned()
    GLV:Debug("TaxiTracker", "New flight path learned!")
    
    -- Marquer qu'une vérification est nécessaire
    self.pendingCheck = true
    
    -- Programmer une vérification après un délai
    self:ScheduleFlightPathCheck()
    
    -- Déclencher un événement immédiat pour les autres modules
    self:TriggerEvent("GLV_FLIGHT_PATH_LEARNED")
end

function TaxiTracker:ScheduleFlightPathCheck()
    -- Créer un timer pour vérifier les nouveaux points après 2 secondes
    local checkTimer = 2.0
    
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
        checkTimer = checkTimer - arg1
        if checkTimer <= 0 then
            frame:SetScript("OnUpdate", nil)
            TaxiTracker:CheckForNewFlightPaths()
        end
    end)
end

function TaxiTracker:OnTaxiMapOpened()
    GLV:Debug("TaxiTracker", "Taxi map opened")
    
    -- Si on a une vérification en attente, la faire maintenant
    if self.pendingCheck then
        self:ScheduleFlightPathCheck()
    end
end

function TaxiTracker:HookTaxiFrame()
    -- Hook la fonction d'ouverture du TaxiFrame
    if TaxiFrame_OnShow then
        local originalOnShow = TaxiFrame_OnShow
        TaxiFrame_OnShow = function()
            originalOnShow()
            TaxiTracker:OnTaxiMapOpened()
        end
    end
     GLV.Ace.hooks["TaxiFrame_OnShow"]()
end

function TaxiTracker:CheckForNewFlightPaths()
    if not TaxiFrame:IsVisible() then
        GLV:Debug("TaxiTracker", "Cannot check flight paths - taxi frame not open")
        return
    end
    
    local newNodes = {}
    local discoveredNew = false
    
    -- Scanner tous les nœuds disponibles
    local numNodes = NumTaxiNodes()
    GLV:Debug("TaxiTracker", "Scanning " .. numNodes .. " taxi nodes")
    
    for i = 1, numNodes do
        local name = TaxiNodeName(i)
        local nodeType = TaxiNodeGetType(i)
        
        if name and (nodeType == "CURRENT" or nodeType == "REACHABLE") then
            newNodes[name] = true
            
            -- Vérifier si c'est un nouveau nœud
            if not self.knownTaxiNodes[name] then
                GLV:Debug("TaxiTracker", "New flight path discovered: " .. name)
                self:OnFlightPathDiscovered(name, i)
                discoveredNew = true
            end
        end
    end
    
    -- Mettre à jour la liste des nœuds connus
    for nodeName, _ in pairs(newNodes) do
        self.knownTaxiNodes[nodeName] = true
    end
    
    -- Sauvegarder les modifications
    if discoveredNew then
        self:SaveKnownTaxiNodes()
    end
    
    -- Réinitialiser le flag de vérification en attente
    self.pendingCheck = false
end

function TaxiTracker:OnFlightPathDiscovered(flightPathName, nodeIndex)
    GLV:Debug("TaxiTracker", "Flight path discovered: " .. flightPathName .. " (index: " .. nodeIndex .. ")")
    
    -- Déclencher l'événement avec les détails
    self:TriggerEvent("GLV_FLIGHT_PATH_DISCOVERED", flightPathName, nodeIndex)
    
    -- Notification visuelle (optionnel)
    if GLV.ShowNotification then
        GLV:ShowNotification("Nouveau point de vol: " .. flightPathName)
    end
end

-- Fonctions utilitaires
function TaxiTracker:SaveKnownTaxiNodes()
    GLV.Settings:SetOption(self.knownTaxiNodes, {"TaxiTracker", "KnownTaxiNodes"})
    GLV:Debug("TaxiTracker", "Saved " .. self:CountKnownNodes() .. " known taxi nodes")
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

function TaxiTracker:ForceRescan()
    GLV:Debug("TaxiTracker", "Forcing flight path rescan...")
    
    if TaxiFrame:IsVisible() then
        self:CheckForNewFlightPaths()
    else
        GLV:Debug("TaxiTracker", "Cannot rescan - taxi frame not open")
    end
end

-- Système d'événements simple
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

-- Fonctions de debug et de test
function TaxiTracker:PrintKnownFlightPaths()
    local paths = self:GetKnownFlightPaths()
    table.sort(paths)
    
    print("=== Known Flight Paths (" .. table.getn(paths) .. ") ===")
    for _, path in pairs(paths) do
        print("- " .. path)
    end
end

function TaxiTracker:ResetKnownFlightPaths()
    self.knownTaxiNodes = {}
    self:SaveKnownTaxiNodes()
    print("Flight paths reset!")
end
