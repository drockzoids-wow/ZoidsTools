local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateAboutPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local infoSection = UI.PlaceSection(frame, "Information")

    local body = UI.CreateBodyText(
        frame,
        "ZoidsTools\nBy Drockzoids\n\nSlash commands: \n    /zt \n    /zoids \n    /zoidstools\n\nQuick pages: \n    /zt tooltips \n    /zt items \n    /zt combat \n    /zt unitframes \n    /zt macros \n    /zt mounts \n    /zt loot \n    /zt quests\n\nUtility commands: \n    /zt coords on/off \n    /zt mapcoords on/off \n    /zt refreshmacros",
        500
    )
    UI.PlaceFirst(body, infoSection)

    return frame
end
