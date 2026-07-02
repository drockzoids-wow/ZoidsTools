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
    gold = { 1, 0.82, 0 },
    softGold = { 0.95, 0.72, 0.28 },
    blue = { 0.2, 0.75, 1 },
    green = { 0.36, 0.9, 0.48 },
    red = { 0.95, 0.28, 0.22 },
    panel = { 0.025, 0.028, 0.034, 0.92 },
    panelDeep = { 0.012, 0.014, 0.018, 0.96 },
    sidebar = { 0.018, 0.020, 0.026, 0.9 },
    border = { 0.72, 0.58, 0.30, 0.46 },
    mutedText = { 0.78, 0.74, 0.66 },
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
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.03, 0.035, 0.045, alpha or 0.88)
    frame:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.5)
end

function Theme.ApplySurfaceBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme.panelBorder,
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.012, 0.014, 0.018, alpha or 0.94)
    frame:SetBackdropBorderColor(0.72, 0.58, 0.30, 0.38)
end

function Theme.ApplySoftBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme.panelBorder,
        tile = false,
        edgeSize = 9,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.026, 0.028, 0.034, alpha or 0.74)
    frame:SetBackdropBorderColor(0.72, 0.58, 0.30, 0.28)
end
