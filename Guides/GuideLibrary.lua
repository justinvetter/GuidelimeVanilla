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
    local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
    if not scrollChild then
        self.Ace:Print("Erreur : ScrollChild non trouvé")
        return
    end
    self:CreateGuideSteps(scrollChild, guide)

    if not self.loadedGuides[group] then
        self.loadedGuides[group] = {}
    end

    if guide.name ~= nil then
        if not self.loadedGuides[group][guide.name] then
            self.loadedGuides[group][guide.name] = guideText
            self.Settings:SetOption(group, {"Guide", "CurrentGroup"})
            self:PopulateDropdown(group)
        else
            self.Ace:Print("Guide déjà chargé : " .. guide.name)
        end
    else
        self.Ace:Print("Erreur : Nom du guide non défini")
    end
end

function GLV:PopulateDropdown(group)
    local dropdown = _G["GLV_MainDropdown"]
    if not dropdown then
        self.Ace:Print("Erreur : GLV_MainDropdown non trouvé")
        return
    end

    UIDropDownMenu_Initialize(dropdown, function()
        if not self.loadedGuides[group] or not next(self.loadedGuides[group]) then
            local info = {}
            info.text = "Aucun guide disponible"
            info.disabled = 1
            UIDropDownMenu_AddButton(info)
            self.Ace:Print("Debug : Aucun guide dans le groupe " .. group)
            return
        end

        for guideName, _ in pairs(self.loadedGuides[group]) do
            local info = {}
            info.text = guideName
            info.value = guideName
            info.func = function()
                self:LoadGuide(group, guideName)
                UIDropDownMenu_SetSelectedValue(dropdown, guideName)
                UIDropDownMenu_SetText(guideName, dropdown)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    -- Sélectionner le premier guide du groupe par défaut
    local selected = false
    for guideName, _ in pairs(self.loadedGuides[group] or {}) do
        UIDropDownMenu_SetSelectedValue(dropdown, guideName)
        UIDropDownMenu_SetText(guideName, dropdown)
        selected = true
        break
    end
    if not selected then
        UIDropDownMenu_SetText("Choisir un guide", dropdown)
    end
end

function GLV:LoadGuide(group, guideName)
    -- Clear TomTom waypoints when changing guide
    if GLV.TomTomIntegration then
        GLV.TomTomIntegration:ClearAllWaypoints()
    end
    
    local guideText = self.loadedGuides[group] and self.loadedGuides[group][guideName]
    if not guideText then
        self.Ace:Print("Erreur : Guide " .. guideName .. " non trouvé dans le groupe " .. group)
        return
    end
    local guide = self.Parser:parseGuide(guideText, group)
    local scrollChild = _G["GLV_MainScrollFrameScrollChild"]
    if not scrollChild then
        self.Ace:Print("Erreur : ScrollChild non trouvé")
        return
    end
    self:CreateGuideSteps(scrollChild, guide)
    self.Settings:SetOption(guideName, {"Guide", "CurrentGuide"})
    
    -- Set current guide and trigger TomTom waypoint update
    self.CurrentGuide = guide
    
    -- Update TomTom waypoint for the current active step
    if GLV.TomTomIntegration then
        local currentStep = self.Settings:GetOption({"Guide", "CurrentStep"}) or 0
        if currentStep > 0 and guide.steps and guide.steps[currentStep] then
            local stepData = guide.steps[currentStep]
            -- Try to update waypoint, but only if TomTom is ready
            if TomTom and TomTom.AddMFWaypoint then
                GLV.TomTomIntegration:OnStepChanged(stepData)
            end
        end
    end
end

-- Commande de debug pour afficher loadedGuides
function GLV:DebugGuides()
    self.Ace:Print("Debug : Contenu de loadedGuides")
    if not self.loadedGuides then
        self.Ace:Print(" - loadedGuides est nil")
        return
    end
    for group, guides in pairs(self.loadedGuides) do
        self.Ace:Print("Groupe : " .. group)
        for name, _ in pairs(guides) do
            self.Ace:Print(" - " .. name)
        end
    end
end