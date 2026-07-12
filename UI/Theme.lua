local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Theme = ns.UI.Theme or {}

local Theme = ns.UI.Theme

Theme.icon = "Interface\\AddOns\\ZoidsTools\\Media\\ZoidToolsIcon.png"
Theme.logo = "Interface\\AddOns\\ZoidsTools\\Media\\ZoidsTools.png"
Theme.panelBg = "Interface\\DialogFrame\\UI-DialogBox-Background"
Theme.panelBorder = "Interface\\Tooltips\\UI-Tooltip-Border"
Theme.sidebarBg = "Interface\\Buttons\\WHITE8x8"

Theme.colors = {
    gold = { 0.96, 0.72, 0.20 },
    softGold = { 0.82, 0.62, 0.28 },
    blue = { 0.2, 0.75, 1 },
    green = { 0.36, 0.9, 0.48 },
    red = { 0.95, 0.28, 0.22 },
    panel = { 0.030, 0.034, 0.042, 0.96 },
    panelDeep = { 0.016, 0.019, 0.025, 0.98 },
    sidebar = { 0.022, 0.026, 0.033, 0.96 },
    border = { 0.30, 0.33, 0.38, 0.68 },
    mutedText = { 0.65, 0.67, 0.70 },
}

function Theme.ApplyPanelBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = Theme.panelBg,
        edgeFile = Theme.panelBorder,
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.022, 0.026, 0.033, alpha or 0.96)
    frame:SetBackdropBorderColor(0.28, 0.31, 0.36, 0.78)
end

function Theme.ApplySurfaceBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme.panelBorder,
        tile = false,
        edgeSize = 7,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.015, 0.018, 0.024, alpha or 0.97)
    frame:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.72)
end

function Theme.ApplySoftBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme.panelBorder,
        tile = false,
        edgeSize = 6,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.035, 0.040, 0.050, alpha or 0.78)
    frame:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.58)
end
