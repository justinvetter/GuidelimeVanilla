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

local addon =AceLibrary("AceAddon-2.0"):new(
    "AceConsole-2.0",
    "AceEvent-2.0",
    "AceDB-2.0",
    "AceHook-2.1"
)

local Settings = nil

function addon:OnInitialize()
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s v%s", _ADDON_NAME, _VERSION))
    GLV_MainTitle:SetText(string.format("|cFF5B5FA4GuideLime|r |cFFA83E25Vanilla|r    |cFFFFFFFFv%s|r", _VERSION))

    Settings = GLV.Settings
    self:RegisterDB(_ADDON_NAME .. "DB")
    self:RegisterDefaults("char", Settings:GetDefaults())
    Settings:InitializeDB()
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

    -- Initialiser le menu déroulant après que tous les addons sont chargés
    self:RegisterEvent("ADDON_LOADED", function()
        local defaultGroup = Settings:GetOption({"Guide", "CurrentGroup"}) or "Sage Guide"
        GLV:PopulateDropdown(defaultGroup)
    end)

    if GLV.QuestTracker then
        GLV.QuestTracker:Init()
    end

    -- Initialize TomTom integration AFTER the guide is loaded
    if GLV.TomTomIntegration then
        -- Wait a bit for TomTom to load, then initialize
        self:ScheduleEvent(function()
            if GLV.TomTomIntegration then
                GLV.TomTomIntegration:Init()
            end
        end, 1.0) -- 1 second delay
    end
end

GLV.Ace = addon