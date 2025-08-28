--[[
Guidelime Vanilla

Author: Grommey

Description:
Everything Taxi related. Get flypath, Take flypath, ..
]]--

local GLV = LibStub("GuidelimeVanilla")

local TaxiTracker = {}
GLV.TaxiTracker = TaxiTracker

-- Initialize character tracking and register event handlers for XP, level, and spell learning events
function TaxiTracker:Init()
    if GLV.Ace then
        GLV.Ace:RegisterEvent("ADDON_LOADED", function() self:OnAddonLoaded() end)
        GLV.Ace:RegisterEvent("CHAT_MSG_SYSTEM", function() self:OnChatMsg() end)
    end
end

function TaxiTracker:OnAddonLoaded()
    local knownTaxiNodes = GLV.Settings:GetOption({"TaxiTracker", "KnownTaxiNodes"}) or {}
    self.knownTaxiNodes = knownTaxiNodes
end

function TaxiTracker:OnChatMsg()
    return
end