local _, ns = ...

local eventFrame
local recipientButton
local enteredRecipient
local pendingRecipient
local sendHooked = false
local recipientTextHooked = false
local sendFrameShowHooked = false

local function Trim(value)
    if (type(issecretvalue) == "function" and issecretvalue(value)) or type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$") or ""
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.mail = type(ns.db.mail) == "table" and ns.db.mail or {}
    local db = ns.db.mail
    if db.recipientRolodex == nil then
        db.recipientRolodex = true
    end
    if db.rememberLastRecipient == nil then
        db.rememberLastRecipient = false
    end
    if type(db.lastRecipient) ~= "string" or Trim(db.lastRecipient) == "" then
        db.lastRecipient = nil
    end
    return db
end

local function NormalizeRealm(realm)
    realm = Trim(realm)
    if realm == "" then
        return ""
    end
    return realm:gsub("[%s%-']", ""):lower()
end

local function GetPlayerIdentity()
    local name
    local realm

    if type(UnitFullName) == "function" then
        name, realm = UnitFullName("player")
    end
    name = Trim(name)
    realm = Trim(realm)

    if name == "" then
        name = Trim(type(UnitName) == "function" and UnitName("player") or "")
    end
    if realm == "" then
        if type(GetNormalizedRealmName) == "function" then
            realm = Trim(GetNormalizedRealmName())
        elseif type(GetRealmName) == "function" then
            realm = Trim(GetRealmName())
        end
    end

    return Trim(name), Trim(realm)
end

local function FormatRecipient(name, realm, playerRealm)
    name = Trim(name)
    realm = Trim(realm)
    if name == "" then
        return nil
    end

    if realm == "" or NormalizeRealm(realm) == NormalizeRealm(playerRealm) then
        return name
    end

    local mailRealm = realm:gsub("[%s%-']", "")
    return mailRealm ~= "" and (name .. "-" .. mailRealm) or name
end

local function GetCharacterColorCode(classFile)
    local color = type(classFile) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color then
        return "|cffffffff"
    end

    local red = math.floor(math.max(0, math.min(1, color.r or 1)) * 255 + 0.5)
    local green = math.floor(math.max(0, math.min(1, color.g or 1)) * 255 + 0.5)
    local blue = math.floor(math.max(0, math.min(1, color.b or 1)) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x", red, green, blue)
end

local function GetKnownCharacters()
    local result = {}
    local characters = ns.db and ns.db.warbandWeekly and ns.db.warbandWeekly.characters
    if type(characters) ~= "table" then
        return result
    end

    local playerName, playerRealm = GetPlayerIdentity()
    local currentKey = (playerName .. "-" .. NormalizeRealm(playerRealm)):lower()
    local seen = {}

    for _, snapshot in pairs(characters) do
        if type(snapshot) == "table" then
            local name = Trim(snapshot.name)
            local realm = Trim(snapshot.realm)
            local identityKey = (name .. "-" .. NormalizeRealm(realm)):lower()
            local address = FormatRecipient(name, realm, playerRealm)

            if address and identityKey ~= currentKey then
                local addressKey = address:lower()
                if not seen[addressKey] then
                    seen[addressKey] = true
                    result[#result + 1] = {
                        name = name,
                        realm = realm,
                        address = address,
                        classFile = snapshot.classFile,
                        sameRealm = NormalizeRealm(realm) == NormalizeRealm(playerRealm),
                    }
                end
            end
        end
    end

    table.sort(result, function(left, right)
        if left.sameRealm ~= right.sameRealm then
            return left.sameRealm
        end

        local leftName = left.name:lower()
        local rightName = right.name:lower()
        if leftName ~= rightName then
            return leftName < rightName
        end
        return left.realm:lower() < right.realm:lower()
    end)

    return result
end

local function SetRecipient(address)
    address = Trim(address)
    if address == "" or not SendMailNameEditBox then
        return
    end

    SendMailNameEditBox:SetText(address)
    SendMailNameEditBox:SetFocus()
end

local function PrefillLastRecipient()
    local db = EnsureDB()
    if not db or db.rememberLastRecipient ~= true or not db.lastRecipient then
        return
    end
    if not SendMailFrame or not SendMailFrame:IsShown() or not SendMailNameEditBox then
        return
    end
    if Trim(SendMailNameEditBox:GetText()) == "" then
        SetRecipient(db.lastRecipient)
    end
end

local function OpenRecipientMenu(owner)
    if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then
        if ns.Print then
            ns:Print("The character recipient menu is not available yet. Reopen the mailbox and try again.")
        end
        return
    end

    local db = EnsureDB()
    local characters = GetKnownCharacters()

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:SetTag("MENU_ZOIDSTOOLS_MAIL_RECIPIENTS")
        if #characters > 10 then
            rootDescription:SetScrollMode(240)
        end

        if db and db.rememberLastRecipient == true and db.lastRecipient then
            rootDescription:CreateTitle("Last Recipient")
            rootDescription:CreateButton("|cffffd100" .. db.lastRecipient .. "|r", function()
                SetRecipient(db.lastRecipient)
            end)
            rootDescription:CreateDivider()
        end

        rootDescription:CreateTitle("Your Characters")
        if #characters == 0 then
            rootDescription:CreateTitle("Log into another character to add it here")
            return
        end

        for _, character in ipairs(characters) do
            local address = character.address
            local realmText = character.realm ~= "" and character.realm or "Unknown Realm"
            local label = string.format(
                "%s%s|r  |cff888888%s|r",
                GetCharacterColorCode(character.classFile),
                character.name,
                realmText
            )
            rootDescription:CreateButton(label, function()
                SetRecipient(address)
            end)
        end
    end)
end

local function RefreshRecipientButton()
    if not recipientButton then
        return
    end

    local db = EnsureDB()
    recipientButton:SetShown(db ~= nil and db.recipientRolodex == true)
end

local function CapturePendingRecipient()
    pendingRecipient = enteredRecipient
end

local function AttachToMailFrame()
    if not SendMailFrame or not SendMailNameEditBox then
        return false
    end

    if not recipientButton then
        recipientButton = CreateFrame(
            "Button",
            "ZoidsToolsMailRecipientButton",
            SendMailNameEditBox,
            "UIPanelButtonTemplate"
        )
        recipientButton:SetSize(20, 20)
        recipientButton:SetPoint("RIGHT", SendMailNameEditBox, "RIGHT", 2, 0)
        recipientButton:SetFrameLevel(SendMailNameEditBox:GetFrameLevel() + 5)
        recipientButton:SetText("v")
        recipientButton:SetScript("OnClick", function(self)
            OpenRecipientMenu(self)
        end)
        recipientButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Character Recipients")
            GameTooltip:AddLine("Choose a character previously recorded by the Warband dashboard.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        recipientButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if not recipientTextHooked then
        SendMailNameEditBox:HookScript("OnTextChanged", function(self)
            local recipient = Trim(self:GetText())
            enteredRecipient = recipient ~= "" and recipient or nil
        end)
        recipientTextHooked = true
    end
    do
        local recipient = Trim(SendMailNameEditBox:GetText())
        enteredRecipient = recipient ~= "" and recipient or nil
    end

    if not sendHooked and type(hooksecurefunc) == "function" and type(SendMailFrame_SendMail) == "function" then
        hooksecurefunc("SendMailFrame_SendMail", CapturePendingRecipient)
        sendHooked = true
    end

    if not sendFrameShowHooked then
        SendMailFrame:HookScript("OnShow", PrefillLastRecipient)
        sendFrameShowHooked = true
    end

    RefreshRecipientButton()
    return true
end

function ns:IsMailRecipientRolodexEnabled()
    local db = EnsureDB()
    return db and db.recipientRolodex == true
end

function ns:SetMailRecipientRolodexEnabled(value)
    local db = EnsureDB()
    if not db then
        return
    end

    db.recipientRolodex = value == true
    RefreshRecipientButton()
end

function ns:IsMailLastRecipientEnabled()
    local db = EnsureDB()
    return db and db.rememberLastRecipient == true
end

function ns:SetMailLastRecipientEnabled(value)
    local db = EnsureDB()
    if not db then
        return
    end

    db.rememberLastRecipient = value == true
    if not db.rememberLastRecipient then
        db.lastRecipient = nil
        pendingRecipient = nil
    else
        PrefillLastRecipient()
    end
end

function ns:InitializeMailRecipients()
    EnsureDB()

    if eventFrame then
        RefreshRecipientButton()
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
    eventFrame:RegisterEvent("MAIL_FAILED")
    eventFrame:RegisterEvent("SECURE_TRANSFER_CANCEL")
    eventFrame:SetScript("OnEvent", function(_, event, addonName)
        if event == "ADDON_LOADED" then
            if addonName == "Blizzard_MailFrame" then
                AttachToMailFrame()
            end
            return
        end

        if event == "MAIL_SHOW" then
            AttachToMailFrame()
            return
        end

        if event == "MAIL_SEND_SUCCESS" then
            local db = EnsureDB()
            if db and db.rememberLastRecipient == true and pendingRecipient then
                db.lastRecipient = pendingRecipient
            end
            pendingRecipient = nil

            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0, PrefillLastRecipient)
            else
                PrefillLastRecipient()
            end
            return
        end

        if event == "MAIL_FAILED" or event == "SECURE_TRANSFER_CANCEL" then
            pendingRecipient = nil
        end
    end)

    local mailLoaded = C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function"
        and C_AddOns.IsAddOnLoaded("Blizzard_MailFrame")
    if mailLoaded then
        AttachToMailFrame()
    end
end
