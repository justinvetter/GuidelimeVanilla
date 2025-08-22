--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
Gossip Event Handler. Handle gossip events like innkeeper conversations.
]]--

local GLV = LibStub("GuidelimeVanilla")

local GossipHandler = CreateFrame("Frame")

-- Function to automatically use hearthstone when talking to innkeeper
function GossipHandler:AutoUseHearthstone()
    -- Check if current step has bindHearthstone = true
    local currentGuideId = GLV.Settings:GetOption({"Guide", "CurrentGuide"}) or "Unknown"
    local currentStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
    
    if currentStep > 0 and GLV.CurrentGuide and GLV.CurrentGuide.steps then
        local stepData = GLV.CurrentGuide.steps[currentStep]
        if stepData and stepData.bindHearthstone then
            -- Use hearthstone automatically
            for bag = 0, 4 do
                local numSlots = GetContainerNumSlots(bag)
                if numSlots then
                    for slot = 1, numSlots do
                        local link = GetContainerItemLink(bag, slot)
                        if link and string.find(link, "item:6948:") then -- Hearthstone item ID
                            UseContainerItem(bag, slot)
                            DEFAULT_CHAT_FRAME:AddMessage("GuidelimeVanilla: Hearthstone used automatically!")
                            return
                        end
                    end
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage("GuidelimeVanilla: Hearthstone not found in your bags!")
        end
    end
end

function GossipHandler:Init()
    -- Hook GOSSIP_SHOW event for innkeeper detection
    self:RegisterEvent("GOSSIP_SHOW")
end

-- Event handler for GOSSIP_SHOW
function GossipHandler:GOSSIP_SHOW()
    -- Check if this is an innkeeper (they have the "Make this inn your home" option)
    local gossipOptions = {GetGossipOptions()}
    for i = 1, table.getn(gossipOptions), 2 do
        if gossipOptions[i] and string.find(gossipOptions[i], "Make this inn your home") then
            -- This is an innkeeper, check if we should auto-use hearthstone
            self:AutoUseHearthstone()
            break
        end
    end
end

GLV.GossipHandler = GossipHandler
