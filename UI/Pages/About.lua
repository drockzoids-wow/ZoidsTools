local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateAboutPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local body = UI.CreateBodyText(
        frame,
        "ZoidsTools\nVersion " .. tostring(ns.version) .. "\nBy Drockzoids\n\nSlash commands: /zt, /zoids, /zoidstools\n\nQuick pages: /zt items, /zt combat, /zt loot, /zt quests\n\nUtility commands: /zt coords on/off, /zt mapcoords on/off",
        500
    )
    body:SetPoint("TOPLEFT", 0, 0)

    return frame
end
