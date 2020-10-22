local W, F, E, L = unpack(select(2, ...))
local CT = W:NewModule("Contacts", "AceHook-3.0")
local S = W:GetModule("Skins")
local ES = E:GetModule("Skins")

local _G = _G

local BNGetNumFriends = BNGetNumFriends

local C_BattleNet_GetFriendAccountInfo = C_BattleNet.GetFriendAccountInfo
local C_BattleNet_GetFriendNumGameAccounts = C_BattleNet.GetFriendNumGameAccounts
local C_BattleNet_GetFriendGameAccountInfo = C_BattleNet.GetFriendGameAccountInfo
local C_Club_GetGuildClubId = C_Club.GetGuildClubId
local C_Club_GetClubMembers = C_Club.GetClubMembers
local C_Club_GetMemberInfo = C_Club.GetMemberInfo
local C_CreatureInfo_GetClassInfo = C_CreatureInfo.GetClassInfo

local guildClubID
local currentPageIndex
local data

local function GetNonLocalizedClass(className)
    for class, localizedName in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if className == localizedName then
            return class
        end
    end

    -- For deDE and frFR
    if W.Locale == "deDE" or W.Locale == "frFR" then
        for class, localizedName in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            if className == localizedName then
                return class
            end
        end
    end
end

local function SetButtonTexture(button, texture, r, g, b)
    local normalTex = button:CreateTexture(nil, "ARTWORK")
    normalTex:Point("CENTER")
    normalTex:Size(button:GetSize())
    normalTex:SetTexture(texture)
    normalTex:SetVertexColor(1, 1, 1)
    button.normalTex = normalTex

    local hoverTex = button:CreateTexture(nil, "ARTWORK")
    hoverTex:Point("CENTER")
    hoverTex:Size(button:GetSize())
    hoverTex:SetTexture(texture)
    if not r or not g or not b then
        r, g, b = unpack(E.media.rgbvaluecolor)
    end
    hoverTex:SetVertexColor(r, g, b)
    hoverTex:SetAlpha(0)
    button.hoverTex = hoverTex

    button:SetScript(
        "OnEnter",
        function()
            E:UIFrameFadeIn(button.hoverTex, (1 - button.hoverTex:GetAlpha()) * 0.382, button.hoverTex:GetAlpha(), 1)
        end
    )

    button:SetScript(
        "OnLeave",
        function()
            E:UIFrameFadeOut(button.hoverTex, button.hoverTex:GetAlpha() * 0.382, button.hoverTex:GetAlpha(), 0)
        end
    )
end

function CT:ConstructFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WTContacts", _G.SendMailFrame)
    frame:Point("TOPLEFT", _G.MailFrame, "TOPRIGHT", 3, -1)
    frame:Point("BOTTOMRIGHT", _G.MailFrame, "BOTTOMRIGHT", 153, 1)
    frame:CreateBackdrop("Transparent")
    frame:EnableMouse(true)

    if E.private.WT.skins.enable and E.private.WT.skins.windtools and E.private.WT.skins.shadow then
        S:CreateShadow(frame.backdrop)
    end

    -- Register move frames
    if E.private.WT.misc.moveBlizzardFrames then
        local MF = W:GetModule("MoveFrames")
        MF:HandleFrame("WTContacts", "MailFrame")
    end

    self.frame = frame
end

function CT:ConstructButtons()
    -- Toggle frame
    local toggleButton = CreateFrame("Button", "WTContactsToggleButton", _G.SendMailFrame, "SecureActionButtonTemplate")
    toggleButton:Size(24)
    SetButtonTexture(toggleButton, W.Media.Icons.list)
    toggleButton:Point("BOTTOMRIGHT", _G.MailFrame, "BOTTOMRIGHT", -24, 38)
    toggleButton:RegisterForClicks("AnyUp")

    toggleButton:SetScript(
        "OnClick",
        function()
            if self.frame:IsShown() then
                self.db.forceHide = true
                self.frame:Hide()
            else
                self.db.forceHide = nil
                self.frame:Show()
            end
        end
    )

    -- 150 = 10 + 25 + 10 + 25 + 10 + 25 + 10 + 25 + 10
    -- Alts
    local altsButton = CreateFrame("Button", "WTContactsAltsButton", self.frame, "SecureActionButtonTemplate")
    altsButton:Size(25)
    SetButtonTexture(altsButton, W.Media.Icons.barCharacter, 0.945, 0.769, 0.059)
    altsButton:Point("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    altsButton:RegisterForClicks("AnyUp")

    altsButton:SetScript(
        "OnClick",
        function()
            self:ChangeCategory("ALTS")
        end
    )

    local friendsButton = CreateFrame("Button", "WTContactsFriendsButton", self.frame, "SecureActionButtonTemplate")
    friendsButton:Size(25)
    SetButtonTexture(friendsButton, W.Media.Icons.barFriends, 0.345, 0.667, 0.867)
    friendsButton:Point("LEFT", altsButton, "RIGHT", 10, 0)
    friendsButton:RegisterForClicks("AnyUp")

    friendsButton:SetScript(
        "OnClick",
        function()
            self:ChangeCategory("FRIENDS")
        end
    )

    local guildButton = CreateFrame("Button", "WTContactsGuildButton", self.frame, "SecureActionButtonTemplate")
    guildButton:Size(25)
    SetButtonTexture(guildButton, W.Media.Icons.barGuild, 0.180, 0.800, 0.443)
    guildButton:Point("LEFT", friendsButton, "RIGHT", 10, 0)
    guildButton:RegisterForClicks("AnyUp")

    guildButton:SetScript(
        "OnClick",
        function()
            self:ChangeCategory("GUILD")
        end
    )

    local favoriteButton = CreateFrame("Button", "WTContactsFavoriteButton", self.frame, "SecureActionButtonTemplate")
    favoriteButton:Size(25)
    SetButtonTexture(favoriteButton, W.Media.Icons.favorite, 0.769, 0.118, 0.227)
    favoriteButton:Point("LEFT", guildButton, "RIGHT", 10, 0)
    favoriteButton:RegisterForClicks("AnyUp")

    favoriteButton:SetScript(
        "OnClick",
        function()
            self:ChangeCategory("FAVORITE")
        end
    )

    self.toggleButton = toggleButton
    self.altsButton = altsButton
    self.friendsButton = friendsButton
    self.guildButton = guildButton
    self.favoriteButton = favoriteButton
end

function CT:ConstructNameButtons()
    self.frame.nameButtons = {}
    for i = 1, 14 do
        local button = CreateFrame("Button", "WTContactsNameButton" .. i, self.frame, "UIPanelButtonTemplate")
        button:Size(140, 20)

        if i == 1 then
            button:Point("TOP", self.frame, "TOP", 0, -45)
        else
            button:Point("TOP", self.frame.nameButtons[i - 1], "BOTTOM", 0, -4)
        end

        button:SetText("")
        button:RegisterForClicks("LeftButtonDown", "RightButtonDown")
        F.SetFontOutline(button.Text)
        ES:HandleButton(button)
        S:CreateShadow(button.backdrop, 2, 1, 1, 1, true)
        if button.backdrop.shadow then
            button.backdrop.shadow:Hide()
        end

        button:SetScript(
            "OnClick",
            function(self, mouseButton)
                if mouseButton == "LeftButton" then
                    if _G.SendMailNameEditBox then
                        local playerName = self.name
                        if playerName then
                            if self.realm and self.realm ~= E.myrealm then
                                playerName = playerName .. "-" .. self.realm
                            end
                            _G.SendMailNameEditBox:SetText(playerName)
                        end
                    end
                end
            end
        )

        button:SetScript(
            "OnEnter",
            function(self)
                CT:SetButtonTooltip(self)
                if self.backdrop.shadow then
                    self.backdrop.shadow:Show()
                end
            end
        )

        button:SetScript(
            "OnLeave",
            function(self)
                GameTooltip:Hide()
                if self.backdrop.shadow then
                    self.backdrop.shadow:Hide()
                end
            end
        )

        button:Hide()
        self.frame.nameButtons[i] = button
    end
end

function CT:ConstructPageController()
    local pagePrevButton = CreateFrame("Button", "WTContactsPagePrevButton", self.frame, "SecureActionButtonTemplate")
    pagePrevButton:Size(14)
    SetButtonTexture(pagePrevButton, E.Media.Textures.ArrowUp)
    pagePrevButton.normalTex:SetRotation(ES.ArrowRotation.left)
    pagePrevButton.hoverTex:SetRotation(ES.ArrowRotation.left)
    pagePrevButton:Point("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 8, 8)
    pagePrevButton:RegisterForClicks("AnyUp")

    pagePrevButton:SetScript(
        "OnClick",
        function(_, mouseButton)
            if mouseButton == "LeftButton" then
                currentPageIndex = currentPageIndex - 1
                self:UpdatePage(currentPageIndex)
            end
        end
    )

    local pageNextButton = CreateFrame("Button", "WTContactsPageNextButton", self.frame, "SecureActionButtonTemplate")
    pageNextButton:Size(14)
    SetButtonTexture(pageNextButton, E.Media.Textures.ArrowUp)
    pageNextButton.normalTex:SetRotation(ES.ArrowRotation.right)
    pageNextButton.hoverTex:SetRotation(ES.ArrowRotation.right)
    pageNextButton:Point("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -8, 8)
    pageNextButton:RegisterForClicks("AnyUp")

    pageNextButton:SetScript(
        "OnClick",
        function(_, mouseButton)
            if mouseButton == "LeftButton" then
                currentPageIndex = currentPageIndex + 1
                self:UpdatePage(currentPageIndex)
            end
        end
    )

    local slider = CreateFrame("Slider", "WTContactsSlider", self.frame, "BackdropTemplate")
    slider:Size(80, 20)
    slider:Point("BOTTOM", self.frame, "BOTTOM", 0, 8)
    slider:SetOrientation("HORIZONTAL")
    slider:SetValueStep(1)
    slider:SetValue(1)
    slider:SetMinMaxValues(1, 10)

    slider:SetScript(
        "OnValueChanged",
        function(_, newValue)
            if newValue then
                currentPageIndex = newValue
                self:UpdatePage(currentPageIndex)
            end
        end
    )

    ES:HandleSliderFrame(slider)

    local pageIndicater = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pageIndicater:Point("BOTTOM", slider, "TOP", 0, 6)
    F.SetFontOutline(pageIndicater, "Montserrat" .. (W.CompatibleFont and " (en)" or ""))
    slider.pageIndicater = pageIndicater

    -- Mouse wheel control
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript(
        "OnMouseWheel",
        function(_, delta)
            if delta > 0 then
                if pagePrevButton:IsShown() then
                    currentPageIndex = currentPageIndex - 1
                    self:UpdatePage(currentPageIndex)
                end
            else
                if pageNextButton:IsShown() then
                    currentPageIndex = currentPageIndex + 1
                    self:UpdatePage(currentPageIndex)
                end
            end
        end
    )

    self.pagePrevButton = pagePrevButton
    self.pageNextButton = pageNextButton
    self.slider = slider
end

function CT:SetButtonTooltip(button)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT", 8, 20)
    GameTooltip:SetText(button.name or "")
    GameTooltip:AddDoubleLine(L["Name"], button.name or "", 1, 1, 1, GetClassColor(button.class))
    GameTooltip:AddDoubleLine(L["Realm"], button.realm or "", 1, 1, 1, unpack(E.media.rgbvaluecolor))

    if button.BNName then
        GameTooltip:AddDoubleLine(L["Battle.net Tag"], button.BNName, 1, 1, 1, 1, 1, 1)
    end

    if button.faction then
        local text, r, g, b
        if button.faction == "Horde" then
            text = L["Horde"]
            r = 0.906
            g = 0.298
            b = 0.235
        else
            text = L["Alliance"]
            r = 0.204
            g = 0.596
            b = 0.859
        end

        GameTooltip:AddDoubleLine(L["Faction"], text or "", 1, 1, 1, r, g, b)
    end

    GameTooltip:Show()
end

function CT:UpdatePage(pageIndex)
    local numData = data and #data or 0

    -- Name buttons
    if numData ~= 0 then
        for i = 1, 14 do
            local temp = data[(pageIndex - 1) * 14 + i]
            local button = self.frame.nameButtons[i]
            if temp then
                if temp.memberID then -- Only get guild member info if needed
                    local info = C_Club_GetMemberInfo(guildClubID, temp.memberID)
                    local name, realm = F.SplitCJKString("-", info.name)
                    local classInfo = C_CreatureInfo_GetClassInfo(info.classID)
                    realm = realm or E.myrealm
                    button.name = name
                    button.realm = realm
                    button.class = classInfo.classFile
                    button.BNName = nil
                    button.faction = E.myfaction
                else
                    button.name = temp.name
                    button.realm = temp.realm
                    button.class = temp.class
                    button.faction = temp.faction
                    button.BNName = temp.BNName
                end
                button:SetText(button.class and F.CreateClassColorString(button.name, button.class) or button.name)
                button:Show()
            else
                button:Hide()
            end
        end
    else
        for i = 1, 14 do
            self.frame.nameButtons[i]:Hide()
        end
    end

    -- Previous page button
    if pageIndex == 1 then
        self.pagePrevButton:Hide()
    else
        self.pagePrevButton:Show()
    end

    -- Next page button
    if pageIndex * 14 - numData >= 0 then
        self.pageNextButton:Hide()
    else
        self.pageNextButton:Show()
    end

    -- Slider
    self.slider:SetValue(pageIndex)
    self.slider:SetMinMaxValues(1, floor(numData / 14) + 1)
    self.slider.pageIndicater:SetText(format("%d / %d", pageIndex, floor(numData / 14) + 1))
end

function CT:UpdateAltsTable()
    if not self.altsTable then
        self.altsTable = E.global.WT.item.contacts.alts
    end
    if not self.altsTable[E.myrealm] then
        self.altsTable[E.myrealm] = {}
    end

    if not self.altsTable[E.myrealm][E.myfaction] then
        self.altsTable[E.myrealm][E.myfaction] = {}
    end

    if not self.altsTable[E.myrealm][E.myfaction][E.myname] then
        self.altsTable[E.myrealm][E.myfaction][E.myname] = E.myclass
    end
end

function CT:BuildAltsData()
    data = {}
    for realm, factions in pairs(self.altsTable) do
        for faction, characters in pairs(factions) do
            for name, class in pairs(characters) do
                if not (name == E.myname and realm == E.myrealm) then
                    tinsert(
                        data,
                        {
                            name = name,
                            realm = realm,
                            class = class,
                            faction = faction
                        }
                    )
                end
            end
        end
    end
end

function CT:BuildFriendsData()
    data = {}

    local tempKey = {}
    local numWoWFriend = C_FriendList.GetNumOnlineFriends()
    for i = 1, numWoWFriend do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info.connected then
            local name, realm = F.SplitCJKString("-", info.name)
            realm = realm or E.myrealm
            tinsert(
                data,
                {
                    name = name,
                    realm = realm,
                    class = GetNonLocalizedClass(info.className)
                }
            )
            tempKey[name .. "-" .. realm] = true
        end
    end

    local numBNOnlineFriend = select(2, BNGetNumFriends())

    for i = 1, numBNOnlineFriend do
        local accountInfo = C_BattleNet_GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
            local numGameAccounts = C_BattleNet_GetFriendNumGameAccounts(i)
            if numGameAccounts and numGameAccounts > 0 then
                for j = 1, numGameAccounts do
                    local gameAccountInfo = C_BattleNet_GetFriendGameAccountInfo(i, j)
                    if
                        gameAccountInfo.clientProgram and gameAccountInfo.clientProgram == "WoW" and
                            gameAccountInfo.wowProjectID == 1 and
                            gameAccountInfo.factionName and
                            gameAccountInfo.factionName == E.myfaction
                     then
                        if not tempKey[gameAccountInfo.characterName .. "-" .. gameAccountInfo.realmName] then
                            tinsert(
                                data,
                                {
                                    name = gameAccountInfo.characterName,
                                    realm = gameAccountInfo.realmName,
                                    class = GetNonLocalizedClass(gameAccountInfo.className),
                                    BNName = accountInfo.accountName
                                }
                            )
                        end
                    end
                end
            elseif
                accountInfo.gameAccountInfo.clientProgram == "WoW" and accountInfo.gameAccountInfo.wowProjectID == 1 and
                    accountInfo.gameAccountInfo.factionName and
                    accountInfo.gameAccountInfo.factionName == E.myfaction
             then
                if not tempKey[gameAccountInfo.characterName .. "-" .. gameAccountInfo.realmName] then
                    tinsert(
                        data,
                        {
                            name = accountInfo.gameAccountInfo.characterName,
                            realm = accountInfo.gameAccountInfo.realmName,
                            class = GetNonLocalizedClass(accountInfo.gameAccountInfo.className),
                            BNName = accountInfo.accountName
                        }
                    )
                end
            end
        end
    end
end

function CT:BuildGuildData()
    data = {}
    if not IsInGuild() then
        return
    end

    guildClubID = C_Club_GetGuildClubId()
    local members = C_Club_GetClubMembers(guildClubID)
    for _, member in pairs(members) do
        tinsert(
            data,
            {
                memberID = member
            }
        )
    end
end

function CT:BuildFavoriteData()
    data = {}
    for fullName in pairs(E.global.WT.item.contacts.favorites) do
        local name, realm = F.SplitCJKString("-", fullName)
        realm = realm or E.myrealm
        tinsert(
            data,
            {
                name = name,
                realm = realm
            }
        )
    end
end

function CT:ChangeCategory(type)
    type = type or "ALTS"

    if type == "ALTS" then
        self:BuildAltsData()
    elseif type == "FRIENDS" then
        self:BuildFriendsData()
    elseif type == "GUILD" then
        self:BuildGuildData()
    elseif type == "FAVORITE" then
        self:BuildFavoriteData()
    else
        self:BuildAltsData()
    end

    currentPageIndex = 1
    self:UpdatePage(1)
end

function CT:SendMailFrame_OnShow()
    if self.db.forceHide then
        self.frame:Hide()
    else
        self.frame:Show()
        self:ChangeCategory()
    end
end

function CT:Initialize()
    self:UpdateAltsTable()
    self.db = E.db.WT.item.contacts

    if not self.db.enable or self.Initialized then
        return
    end

    self:ConstructFrame()
    self:ConstructButtons()
    self:ConstructNameButtons()
    self:ConstructPageController()

    self:SecureHookScript(_G.SendMailFrame, "OnShow", "SendMailFrame_OnShow")
    self.Initialized = true
end

function CT:ProfileUpdate()
    self.db = E.db.WT.item.contacts

    if self.db.enable then
        self:Initialize()
        self.frame:Show()
        self.toggleButton:Show()
    else
        if self.Initialized then
            self.frame:Hide()
            self.toggleButton:Hide()
        end
    end
end

W:RegisterModule(CT:GetName())
