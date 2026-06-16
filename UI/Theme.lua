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
    blue = { 0.2, 0.75, 1 },
    panel = { 0.03, 0.035, 0.045, 0.88 },
    sidebar = { 0.02, 0.025, 0.035, 0.62 },
    border = { 0.85, 0.7, 0.38, 0.5 },
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
