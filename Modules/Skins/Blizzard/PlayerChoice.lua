local W, F, E, L = unpack(select(2, ...))
local S = W:GetModule("Skins")

local _G = _G

function S:Blizzard_PlayerChoiceUI()
    if not self:CheckDB("playerChoice") then
        return
    end

    local frame = _G.PlayerChoiceFrame
    if not frame then
        return
    end
    self:CreateShadow(_G.PlayerChoiceFrame)

    for i = 1, 4 do
        local option = frame["Option" .. i]
        if option then
            F.SetFontOutline(option.OptionText.textObject)
            F.SetFontOutline(option.Header.Text)
        end
    end
end

S:AddCallbackForAddon("Blizzard_PlayerChoiceUI")
