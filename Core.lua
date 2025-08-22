--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
Trying to port Guidelime Guides to Vanilla (1.12).
This is the main file.
]]--
local _ADDON_NAME = "GuidelimeVanilla"
local _VERSION = GetAddOnMetadata(_ADDON_NAME, "Version")

local GLV = LibStub:NewLibrary(_ADDON_NAME, 1)
if not GLV then return end

local addon = AceLibrary("AceAddon-2.0"):new(
    "AceConsole-2.0",
    "AceEvent-2.0",
    "AceDB-2.0",
    "AceHook-2.1"
)

local Settings = nil

function addon:OnInitialize()
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s v%s", _ADDON_NAME, _VERSION))
    
    -- Set GLV.Ace first so other modules can access it
    GLV.Ace = self
    
    -- Initialize settings
    Settings = GLV.Settings
    self:RegisterDB(_ADDON_NAME .. "DB")
    self:RegisterDefaults("char", Settings:GetDefaults())
    
    -- Initialize settings after a short delay to ensure everything is ready
    self:ScheduleEvent(function()
        if Settings and Settings.InitializeDB then
            Settings:InitializeDB()
        end
    end, 0.1)
    
    -- Set title after settings are initialized
    self:ScheduleEvent(function()
        if GLV_MainTitle then
            GLV_MainTitle:SetText(string.format("|cFF5B5FA4GuideLime|r |cFFA83E25Vanilla|r    |cFFFFFFFFv%s|r", _VERSION))
        end
    end, 0.2)
end

function addon:OnEnable()
    local name = UnitName("player")
    local realm = GetRealmName()
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local faction = UnitFactionGroup("player")
    
    local charInfo = {
        Realm = realm or "Unknown",
        Name = name or "Unknown",
        Faction = faction or "Unknown",
        Race = race or "Unknown",
        Class = class or "Unknown",
    }

    for key, val in pairs(charInfo) do
        Settings:SetOption(val, {"CharInfo", key})
    end

    Settings:SetOption(GetLocale(), "Locale")

    -- Register events for proper timing
    self:RegisterEvent("VARIABLES_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
    
    if GLV.QuestTracker then
        GLV.QuestTracker:Init()
    end
    
    if GLV.GossipHandler then
        GLV.GossipHandler:Init()
    end

    -- Set debug mode for testing
    GLV.Debug = true
    
    -- Initialize TomTom integration AFTER the guide is loaded
    if GLV.TomTomIntegration then
        -- Wait a bit for TomTom to load, then initialize
        self:ScheduleEvent(function()
            if GLV.TomTomIntegration then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Initializing TomTom integration...")
                GLV.TomTomIntegration:Init()
                
                -- Force update the waypoint for the current step after a delay
                self:ScheduleEvent(function()
                    if GLV.TomTomIntegration and GLV.CurrentGuide then
                        local currentGuideId = GLV.Settings:GetOption({"Guide", "CurrentGuide"}) or "Unknown"
                        local currentStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
                        
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime]|r Force-updating TomTom waypoint for step " .. currentStep)
                        
                        if currentStep > 0 and GLV.CurrentDisplaySteps and GLV.CurrentDisplaySteps[currentStep] then
                            local stepData = GLV.CurrentDisplaySteps[currentStep]
                            GLV.TomTomIntegration:OnStepChanged(stepData)
                        end
                    end
                end, 1.0)
            end
        end, 2.0) -- 2 seconds delay to ensure everything is loaded properly
    end
end

-- Event handler for VARIABLES_LOADED
function addon:VARIABLES_LOADED()
    -- Check if guides are loaded
    if GLV and GLV.loadedGuides then
        local totalGuides = 0
        for group, guides in pairs(GLV.loadedGuides) do
            if guides then
                for _ in pairs(guides) do totalGuides = totalGuides + 1 end
            end
        end
    end
end

-- Event handler for PLAYER_LOGIN
function addon:PLAYER_LOGIN()
    local defaultGroup = Settings:GetOption({"Guide", "CurrentGroup"}) or "Sage Guide"
    
    -- Check if ScrollChild is available and guides are loaded
    local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
    if scrollChild and GLV and GLV.loadedGuides then
        -- Find the first group with guides and populate dropdown
        for group, guides in pairs(GLV.loadedGuides) do
            if guides and next(guides) then
                GLV:PopulateDropdown(group)
                
                -- Auto-load the appropriate guide based on race
                local _, race = UnitRace("player")
                self:LoadDefaultGuideForRace(race)
                break
            end
        end
    else
        -- Register a one-time event to check when everything is ready
        self:RegisterEvent("ADDON_LOADED")
    end
end

-- Event handler for ADDON_LOADED (one-time use)
function addon:ADDON_LOADED(addonName)
    if addonName == _ADDON_NAME then
        -- Unregister this event since we only need it once
        self:UnregisterEvent("ADDON_LOADED")
        
        -- Final check for ScrollChild and guides
        local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
        if scrollChild and GLV and GLV.loadedGuides then
            for group, guides in pairs(GLV.loadedGuides) do
                if guides and next(guides) then
                    GLV:PopulateDropdown(group)
                    
                    local _, race = UnitRace("player")
                    self:LoadDefaultGuideForRace(race)
                    break
                end
            end
        end
    end
end

-- Function to automatically load the appropriate guide based on player race
function addon:LoadDefaultGuideForRace(race)
    if not race then return end
    
    -- First, check if there's a saved guide to load
    local savedGuideId = Settings:GetOption({"Guide", "CurrentGuide"})
    if savedGuideId and savedGuideId ~= "Unknown" then
        -- Try to load the saved guide
        if GLV.loadedGuides and GLV.loadedGuides["Sage Guide"] then
            for guideId, guideData in pairs(GLV.loadedGuides["Sage Guide"]) do
                if guideId == savedGuideId then
                    GLV:LoadGuide("Sage Guide", guideId)
                    return
                end
            end
        end
    end
    
    -- If no saved guide or saved guide not found, load default guide based on race
    local raceGuides = {
        ["Human"] = "Elwynn Forest",
        ["Dwarf"] = "Dun Morogh", 
        ["Gnome"] = "Dun Morogh",
        ["Night Elf"] = "Teldrassil"
    }
    
    local defaultGuideName = raceGuides[race]
    if not defaultGuideName then
        return
    end
    
    -- Find and load the appropriate guide
    if GLV.loadedGuides and GLV.loadedGuides["Sage Guide"] then
        for guideId, guideData in pairs(GLV.loadedGuides["Sage Guide"]) do
            if guideData.name == defaultGuideName then
                GLV:LoadGuide("Sage Guide", guideId)
                break
            end
        end
    end
end