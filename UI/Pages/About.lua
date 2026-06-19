local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateAboutPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local infoSection = UI.PlaceSection(frame, "Information")

    local body = UI.CreateBodyText(
        frame,
        "ZoidsTools\nVersion " .. tostring(ns.version) .. "\nBy Drockzoids\n\nSlash commands: /zt, /zoids, /zoidstools\n\nQuick pages: /zt items, /zt combat, /zt unitframes, /zt macros, /zt mounts, /zt loot, /zt quests\n\nUtility commands: /zt coords on/off, /zt mapcoords on/off, /zt refreshmacros",
        500
    )
    UI.PlaceFirst(body, infoSection)

    return frame
end
