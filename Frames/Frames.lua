--[[
Guidelime Vanilla

Author: Grommey

Description:
Frames manipulation.
The left menu is only some FontString. The trick is to have
multiple Frames with the same dimensions but not the same content.
When we click on a menu "button", it will hide all the Frames except
the one linked to this "button".
]]--
local GLV = LibStub("GuidelimeVanilla")


-- Toggle settings frame visibility
function GLV_ToggleSettings()
    if GLV_Settings:IsVisible() then
        GLV_Settings:Hide()
    else
        GLV_Settings:Show()
    end
end

-- Show specific guide page and hide all others
function GLV_ShowGuide(frame)
    local frames = {
        GLV_SettingsGuidesPage,
        GLV_SettingsDisplayPage,
        GLV_SettingsAboutPage,
    }

    -- Hide all other frames first
    for _, f in pairs(frames) do
        if f:IsVisible() then
            f:Hide()
        end
    end

    -- Show the requested frame
    frame:Show()
end

-- Initialize the about page with description text
function GLV_SettingsAboutPage_OnLoad()
    local text = [[
Guidelime Vanilla is a total overhaul of the official Guidelime, which is not compatible with WoW 1.12.
The original project is a rewrite of the VanillaGuide from mrmr. But I wanted to have something more functionnal and with the possibility to use actual Guidelime's guide available on CurseForge.

I've tried to automatize a lot of things like auto-complete steps with Quest Accept or Quest Complete (as much as the WoW 1.12 API let me do it).
It's using it's own navigation system.

Thanks to :
- |cFFFF0000mrmr|r for the original addon
- |cFFFF0000Shagu|r for the PfQuest databases
- |cFFFF0000Laytya|r for the Spells DB


Original source for VanillaGuide :

My rewrite of VanillaGuide to VanillaGuideReloaded :
]]

    local content = GLV_SettingsAboutPageContent
    content:SetWidth(700)                -- Max width before line break
    content:SetNonSpaceWrap(true)        -- Allows cutting even without spaces
    content:SetJustifyH("LEFT")          -- Horizontal alignment
    content:SetJustifyV("TOP")           -- Vertical alignment
    content:SetText(text)
end

-- Function to restore saved position
local function GLV_RestoreFramePosition()
    if GLV and GLV.Settings then
        local posX = GLV.Settings:GetOption({"UI", "PositionX"})
        local posY = GLV.Settings:GetOption({"UI", "PositionY"})
        
        if posX and posY then
            GLV_Main:ClearAllPoints()
            GLV_Main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", posX, posY)
        end
    end
end

-- Function to save current position
local function GLV_SaveFramePosition()
    if GLV and GLV.Settings then
        local left = GLV_Main:GetLeft()
        local top = GLV_Main:GetTop()
        
        if left and top then
            -- Calculate coordinates relative to top-left corner
            local screenHeight = GetScreenHeight()
            local relativeY = top - screenHeight
            
            GLV.Settings:SetOption(left, {"UI", "PositionX"})
            GLV.Settings:SetOption(relativeY, {"UI", "PositionY"})
        end
    end
end

function GLV_MainLock_OnLoad()
    -- Wait for addon to be completely initialized
    this:RegisterEvent("ADDON_LOADED");
    this:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "GuideLimeVanilla" then
            -- Now GLV is available
            local locked = GLV and GLV.Settings and GLV.Settings:GetOption({"UI", "Locked"}) or false;
            
            -- Restore saved position BEFORE applying lock
            GLV_RestoreFramePosition()
            
            if locked then
                -- Locked state
                GLV_MainLock:SetNormalTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\closed_lock")
                GLV_MainLock:SetPushedTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\closed_lock_down")
                GLV_Main:SetMovable(false)
                GLV_Main:RegisterForDrag()
            else
                -- Unlocked state
                GLV_MainLock:SetNormalTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\opened_lock")
                GLV_MainLock:SetPushedTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\opened_lock_down")
                GLV_Main:SetMovable(true)
                GLV_Main:RegisterForDrag("LeftButton")
            end
        end
    end);
end

-- Initialize automation checkbox from settings
function GLV_InitAutomationCheckbox(checkbox, settingKeys)
    local value = GLV.Settings:GetOption(settingKeys) or false
    checkbox:SetChecked(value)
end

-- Handle automation checkbox click
function GLV_OnAutomationCheckboxClick(checkbox, settingKeys)
    local isChecked = checkbox:GetChecked() == 1
    GLV.Settings:SetOption(isChecked, settingKeys)
end

function GLV_MainLock_OnClick()
    local locked = GLV and GLV.Settings and GLV.Settings:GetOption({"UI", "Locked"}) or false

    if locked then
        -- Unlock
        GLV_MainLock:SetNormalTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\opened_lock")
        GLV_MainLock:SetPushedTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\opened_lock_down")
        GLV_Main:SetMovable(true)
        GLV_Main:RegisterForDrag("LeftButton")

        if GLV and GLV.Settings then
            GLV.Settings:SetOption(false, {"UI", "Locked"})
        end
    else
        -- Lock - Save current position BEFORE locking
        GLV_SaveFramePosition()
        
        GLV_MainLock:SetNormalTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\closed_lock")
        GLV_MainLock:SetPushedTexture("Interface\\AddOns\\GuideLimeVanilla\\Textures\\closed_lock_down")
        GLV_Main:SetMovable(false)
        GLV_Main:RegisterForDrag("")

        if GLV and GLV.Settings then
            GLV.Settings:SetOption(true, {"UI", "Locked"})
        end
    end
end