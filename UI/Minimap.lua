local _, ns = ...

local LDB_NAME = "ZoidsTools"

local function GetMinimapDB()
    ZoidsToolsDB = ZoidsToolsDB or {}
    ZoidsToolsDB.ui = ZoidsToolsDB.ui or {}
    ZoidsToolsDB.ui.minimap = ZoidsToolsDB.ui.minimap or {}

    local minimap = ZoidsToolsDB.ui.minimap

    if minimap.minimapPos == nil then
        minimap.minimapPos = minimap.angle or 225
    end

    if minimap.show == nil then
        minimap.show = minimap.hide ~= true
    end

    minimap.hide = minimap.show == false

    return minimap
end

local function SkinMinimapButton(DBIcon)
    if not DBIcon or not DBIcon.GetMinimapButton then
        return
    end

    local button = DBIcon:GetMinimapButton(LDB_NAME)

    if not button then
        return
    end

    local regions = { button:GetRegions() }

    for _, region in ipairs(regions) do
        if region and region ~= button.icon and region.GetObjectType and region:GetObjectType() == "Texture" then
            local texture = region.GetTexture and region:GetTexture()
            local textureName = texture and tostring(texture) or ""
            local width = region.GetWidth and region:GetWidth() or 0
            local height = region.GetHeight and region:GetHeight() or 0

            if texture == 136430 or textureName:find("MiniMap%-TrackingBorder") or (width > 40 and height > 40) then
                region:Hide()
            end
        end
    end

    if button.icon then
        if not button.ZTCircleMask and button.icon.AddMaskTexture then
            button.ZTCircleMask = button:CreateMaskTexture(nil, "ARTWORK")
            button.ZTCircleMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            button.ZTCircleMask:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.ZTCircleMask:SetSize(25, 25)
            button.icon:AddMaskTexture(button.ZTCircleMask)
        elseif button.ZTCircleMask then
            button.ZTCircleMask:ClearAllPoints()
            button.ZTCircleMask:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.ZTCircleMask:SetSize(25, 25)
        end

        button.icon:ClearAllPoints()
        button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.icon:SetSize(25, 25)
        button.icon:SetTexture(ns.UI.Theme.icon)

        if button.icon.UpdateCoord then
            button.icon:UpdateCoord()
        else
            button.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        end
    end
end

function ns:InitializeMinimapButton()
    if self.minimapRegistered then
        return
    end

    if not LibStub then
        self:Print("LibStub not found. Minimap button unavailable.")
        return
    end

    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)

    if not LDB or not DBIcon then
        self:Print("LibDataBroker or LibDBIcon not found. Minimap button unavailable.")
        return
    end

    local launcher = LDB:NewDataObject(LDB_NAME, {
        type = "launcher",
        text = "ZoidsTools",
        icon = ns.UI.Theme.icon,
        iconCoords = { 0, 1, 0, 1 },

        OnClick = function(_, button)
            if button == "RightButton" and ns.UI and ns.UI.Show then
                ns.UI.Show("windows")
            elseif ns.UI and ns.UI.Toggle then
                ns.UI.Toggle()
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine("ZoidsTools")
            tooltip:AddLine("Left-click: Open tools", 1, 1, 1)
            tooltip:AddLine("Right-click: Window tools", 1, 1, 1)
            tooltip:AddLine("Drag: Move minimap button", 0.8, 0.8, 0.8)
        end,
    })

    DBIcon:Register(LDB_NAME, launcher, GetMinimapDB())
    SkinMinimapButton(DBIcon)
    self.minimapRegistered = true
    self:UpdateMinimapButton()
end

function ns:UpdateMinimapButton()
    if not LibStub then
        return
    end

    local DBIcon = LibStub("LibDBIcon-1.0", true)

    if not DBIcon then
        return
    end

    local minimapDB = GetMinimapDB()
    local isRegistered = DBIcon.IsRegistered and DBIcon:IsRegistered(LDB_NAME)

    if not isRegistered then
        return
    end

    if DBIcon.Refresh then
        DBIcon:Refresh(LDB_NAME, minimapDB)
    end

    SkinMinimapButton(DBIcon)

    if minimapDB.show then
        DBIcon:Show(LDB_NAME)
    else
        DBIcon:Hide(LDB_NAME)
    end
end
