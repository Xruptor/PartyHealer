--[[
	PartyHealer.lua
		A party healing mod that support configurable click-casting.

	Author: Derkyle

	NOTE: There are several actions that are not permitted to be performed while a unit is in combat.
	This includes showing/hiding secured action buttons.  For more details please refer to InCombatLockdown on WOWWiki.
	http://www.wowwiki.com/API_InCombatLockdown
--]]

local UnitName = _G.UnitName
local UnitClass = _G.UnitClass
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitIsConnected = _G.UnitIsConnected
local UnitIsGhost = _G.UnitIsGhost
local UnitIsDead = _G.UnitIsDead
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitPower = _G.UnitPower
local UnitPowerMax = _G.UnitPowerMax
local UnitPowerType = _G.UnitPowerType
local UnitDebuff = _G.UnitDebuff
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local GetNumPartyMembers = _G.GetNumPartyMembers
local GetRealmName = _G.GetRealmName
local GetSpellInfo = _G.GetSpellInfo
local InCombatLockdown = _G.InCombatLockdown
local GetNumBattlefieldScores = _G.GetNumBattlefieldScores
local IsActiveBattlefieldArena = _G.IsActiveBattlefieldArena
local GetBattlefieldStatus = _G.GetBattlefieldStatus
local UnitHasVehicleUI = _G.UnitHasVehicleUI

local currentPlayer = UnitName('player')
local currentRealm = GetRealmName()
local currentPlayerClass = select(2, UnitClass("player"))

local Keys_List = {"","Shift","Ctrl","Alt","Alt-Shift","Ctrl-Shift"}
local Mouse_List = {"Left","Right","Middle","Button4","Button5","Button6","Button7","Button8","Button9","Button10"}

local f = CreateFrame("Frame","PartyHealer",UIParent)
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

f:SetScript("OnUpdate", function(self, elap)
	if self.doupdateparty then
		if self.TimeSinceLastUpdate == nil then self.TimeSinceLastUpdate = 0 end
		self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elap;
			
		if (self.TimeSinceLastUpdate > 1) then
			if not InCombatLockdown() then
				self:UpdateFrames()
				self.doupdateparty = nil
			end
			self.TimeSinceLastUpdate = 0
		end
		
	end
end)

----------------------
--      Enable      --
----------------------

f.partyF = {}
f.partyRez = {}

f.resSpells = { -- get spell names
	PRIEST = GetSpellInfo(2006), -- Resurrection
	SHAMAN = GetSpellInfo(2008), -- Ancestral Spirit
	DRUID = GetSpellInfo(50769), -- Revive
	PALADIN = GetSpellInfo(7328) -- Redemption
}    

f.resSpellIcons = { -- returns icons
	PRIEST = select (3, GetSpellInfo(2006)),
	SHAMAN = select (3, GetSpellInfo(2008)),
	DRUID = select (3, GetSpellInfo(50769)),
	PALADIN = select (3, GetSpellInfo(7328))
} 

f.decurseSpells = { -- get spell names
	PRIEST = {
		["Magic"] = true,
		["Disease"] = true --Abolish Disease, Cure Disease
	},
	SHAMAN = {
		["Poison"] = true,
		["Disease"] = true,
		["Curse"] = true --Cleanse Spirit
	},
	DRUID = {
		["Curse"] = true,
		["Poison"] = true --Abolish Poison, Cure Poison
	},
	PALADIN = {
		["Magic"] = true,
		["Poison"] = true,
		["Disease"] = true
	},
	MAGE = {
		["Curse"] = true,
	}
}

------------------------------
--      Event Handlers      --
------------------------------

function f:PLAYER_LOGIN()

	local ver = tonumber(GetAddOnMetadata("PartyHealer","Version")) or 'Unknown'
	local configStr
	
	f:StartupDB()

	f:RegisterEvent("PARTY_MEMBERS_CHANGED")
	f:RegisterEvent("UNIT_AURA")
	
	f:HideBlizzardPartyFrames()
	f:CreateAnchor()
	f:CreatePartyFrames()
	
	--create the casting bar (must do after party bar creation)
	if PH_CB then
		f.showcastbar = false
		f.castbar = PH_CB:New(f)
		f.castbar:SetPoint("BOTTOMLEFT",PH_PlayerButton,"BOTTOMLEFT",0,-40)
	end
	
	--must do after casting bar creation
	f:UpdateFrames()
	
	DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer|r [v|cFFDF2B2B"..ver.."|r] loaded: /partyhealer or /ph")
	if PH_DB then
		if PH_DB.PH_Toggle then
			configStr = "PartyHealer [|cFF00CC00ON|r]"
		else
			configStr = "PartyHealer [|cFFFF0000OFF|r]"
		end
		if (not PH_DB.PH_HideParty_Toggle) then
			configStr = configStr.." : Blizzard Party Frames [|cFF00CC00ON|r]"
		else
			configStr = configStr.." : Blizzard Party Frames [|cFFFF0000OFF|r]"
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer Status|r: "..(configStr or "Unknown"))
	end
	
	SLASH_PARTYHEALER1 = "/partyhealer"
	SLASH_PARTYHEALER2 = "/ph"
	SlashCmdList["PARTYHEALER"] = function(msg)
		f:SlashCommand(msg)
	end
	
	f:UnregisterEvent("PLAYER_LOGIN")
	f.PLAYER_LOGIN = nil
end

function f:PARTY_MEMBERS_CHANGED()
	f:UpdateFrames()
end

function f:UNIT_AURA(event, unit)
	if not unit then return end
	if PH_DB and not PH_DB.PH_Toggle then return end
	if not f:DisplayCheck(true) then return end
	
	local frmUH

	if f.partyF[unit] then
		frmUH = f.partyF[unit]
	elseif unit == "player" then
		frmUH = PH_PlayerButton
	else
		return
	end
	
	if not frmUH then return end
	
	f:UpdateDebuffs(frmUH, unit)
	f:UpdateBuffs(frmUH, unit)
end

------------------------------
--    Database Function     --
------------------------------

function f:StartupDB()
	local ver = tonumber(GetAddOnMetadata("PartyHealer","Version")) or 'Unknown'
	
	PH_DB = PH_DB or {}
	PH_DB.spells = PH_DB.spells or {}
	
	if PH_DB.PH_Toggle == nil then PH_DB.PH_Toggle = true end
	if PH_DB.Scale == nil then PH_DB.Scale = 1 end
	if PH_DB.Alpha == nil then PH_DB.Alpha = 1 end
	if PH_DB.BarWidth == nil then PH_DB.BarWidth = 180 end
	if PH_DB.BarHeight == nil then PH_DB.BarHeight = 19 end
	if PH_DB.showBG == nil then PH_DB.showBG = true end
	if PH_DB.showArena == nil then PH_DB.showArena = true end
	if PH_DB.showRaid == nil then PH_DB.showRaid = true end
	if PH_DB.BlizzardRaidClickCasting == nil then PH_DB.BlizzardRaidClickCasting = true end
	if PH_DB.BlizzardRaidDebuffHighlight == nil then PH_DB.BlizzardRaidDebuffHighlight = true end
	if PH_DB.PH_HideParty_Toggle == nil then PH_DB.PH_HideParty_Toggle = false end
	if PH_DB.PH_HideCastBar == nil then PH_DB.PH_HideCastBar = false end
	if PH_DB.dbver == nil then PH_DB.dbver = ver end
	
end

function f:SlashCommand(msg)
	if msg and msg ~= "" then
		if msg:lower() == "config" then
			if PartyHealer_Config then
				PartyHealer_Config:Show()
			end
			return nil
		elseif msg:lower() == "on" then
			if PH_DB then
				PH_DB.PH_Toggle = true
			end
			f:UpdateFrames()
			DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer|r is now [|cFF00CC00ON|r] for player: "..(currentPlayer or 'Unknown'))
			return nil
		elseif msg:lower() == "off" then
			if PH_DB then
				PH_DB.PH_Toggle = false
			end
			f:UpdateFrames()
			DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer|r is now [|cFFFF0000OFF|r] for player: "..(currentPlayer or 'Unknown'))
			return nil
		elseif msg:lower() == "anchor" then
			if PartyHealerAnchor and PartyHealerAnchor:IsVisible() then
				PartyHealerAnchor:Hide()
			elseif PartyHealerAnchor then
				PartyHealerAnchor:Show()
			end
			f:UpdateFrames()
			return nil
		elseif msg:lower() == "party" then
			if PH_DB then
				if PH_DB.PH_HideParty_Toggle then
					PH_DB.PH_HideParty_Toggle = false
					ReloadUI() --reload the UI to initiate the changes
					DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer|r: Default blizzard frames are now [|cFF00CC00ON|r].")
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer|r: Default blizzard frames are now [|cFFFF0000OFF|r].")
					PH_DB.PH_HideParty_Toggle = true
					f:HideBlizzardPartyFrames()
				end
			end
			return nil
		elseif msg:lower() == "castbar" then
			if PH_DB then
				if PH_DB.PH_HideCastBar then
					PH_DB.PH_HideCastBar = false
					DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer|r: Casting Bar [|cFF00CC00ON|r].")
				else
					DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200PartyHealer|r: Casting Bar [|cFFFF0000OFF|r].")
					PH_DB.PH_HideCastBar = true
				end
			end
			return nil
		elseif msg:lower() == "report" then
			if PartyHealer_ReportFrame and PartyHealer_ReportFrame:IsVisible() then
				PartyHealer_ReportFrame:Hide()
			elseif PartyHealer_ReportFrame then
				PartyHealer_ReportFrame:Show()
			end
			return nil
		end
	end
	
	local ver = tonumber(GetAddOnMetadata("PartyHealer","Version")) or 'Unknown'
	local configStr
	
	if PH_DB then
		if PH_DB.PH_Toggle then
			configStr = "PartyHealer [|cFF00CC00ON|r]"
		else
			configStr = "PartyHealer [|cFFFF0000OFF|r]"
		end
		if (not PH_DB.PH_HideParty_Toggle) then
			configStr = configStr.." : Blizzard Party Frames [|cFF00CC00ON|r]"
		else
			configStr = configStr.." : Blizzard Party Frames [|cFFFF0000OFF|r]"
		end
	end
	
	DEFAULT_CHAT_FRAME:AddMessage("<<-- |cFF6BB200PartyHealer|r [v|cFFDF2B2B"..ver.."|r] -->>")
	DEFAULT_CHAT_FRAME:AddMessage("|cFF6BB200Status|r: "..(configStr or "Unknown"))
	DEFAULT_CHAT_FRAME:AddMessage("-------------------------")
	DEFAULT_CHAT_FRAME:AddMessage("/ph config - displays the configuation window")
	DEFAULT_CHAT_FRAME:AddMessage("/ph anchor - displays the party frame anchor")
	DEFAULT_CHAT_FRAME:AddMessage("/ph on - turns on |cFF6BB200PartyHealer|r for current player.")
	DEFAULT_CHAT_FRAME:AddMessage("/ph off - turns off |cFF6BB200PartyHealer|r for current player.")
	DEFAULT_CHAT_FRAME:AddMessage("/ph party - toggles on/off the default blizzard party frames.")
	DEFAULT_CHAT_FRAME:AddMessage("/ph castbar - toggles on/off the |cFF6BB200PartyHealer|r casting bar.")
	DEFAULT_CHAT_FRAME:AddMessage("/ph report - toggles the report window that will display your mouse bindings.")
end

------------------------------
--      Create Frames       --
------------------------------

function f:CreateAnchor()

	--create the anchor
	local frameAnchor = CreateFrame("Frame", "PartyHealerAnchor", UIParent)
	
	frameAnchor:SetWidth(25)
	frameAnchor:SetHeight(25)
	frameAnchor:SetMovable(true)
	frameAnchor:SetClampedToScreen(true)
	frameAnchor:EnableMouse(true)

	frameAnchor:ClearAllPoints()
	frameAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frameAnchor:SetFrameStrata("DIALOG")
	
	frameAnchor:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	frameAnchor:SetBackdropColor(0.75,0,0,1)
	frameAnchor:SetBackdropBorderColor(0.75,0,0,1)

	frameAnchor:SetScript("OnLeave",function(self)
		GameTooltip:Hide()
	end)

	frameAnchor:SetScript("OnEnter",function(self)
	
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(self:SetTip(self))
		GameTooltip:ClearLines()
		
		GameTooltip:AddLine("PartyHealer Anchor")
		GameTooltip:Show()
	end)

	frameAnchor:SetScript("OnMouseDown", function(frame, button)
		if frame:IsMovable() then
			frame.isMoving = true
			frame:StartMoving()
		end
	end)

	frameAnchor:SetScript("OnMouseUp", function(frame, button) 
		if( frame.isMoving ) then
			frame.isMoving = nil
			frame:StopMovingOrSizing()
			f:SaveLayout(frame:GetName())
		end
	end)
	
	function frameAnchor:SetTip(frame)
		local x,y = frame:GetCenter()
		if not x or not y then return "TOPLEFT", "BOTTOMLEFT" end
		local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
		local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
		return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
	end

	frameAnchor:Hide() -- hide it by default
	
	f:RestoreLayout("PartyHealerAnchor")
end

local function doHealthPowerUpdate(self, elap)
	if PH_DB and not PH_DB.PH_Toggle then return end

	if self.min and self.unit then
	
		if (self.disconnected) then
			self.disconnected = not UnitIsConnected(self.unit)
			return
		end

		local power = UnitPower(self.unit)
		local health = UnitHealth(self.unit)
		
		--check for vehicle
		if UnitHasVehicleUI(self.unit) then
			health = UnitHealth(self.unitVehicle)
		end
		
		--do health check
		if ( health ~= self.min ) then
			PartyHealer:UpdateHealth(self, self.unit)
		end
		
		--do power check
		if ( self.unit == "player" and power ~= self.powermin ) then
			PartyHealer:UpdatePower(self, self.unit)
		end
		
		--show rez button if we have it and are not in combat
		if PartyHealer and PartyHealer.partyRez and PartyHealer.partyRez[self.unit] then
			--don't show in combat, only out of combat, causes a taint if you do it during combat
			if not InCombatLockdown() then
				if UnitIsDeadOrGhost(self.unit) and not PartyHealer.partyRez[self.unit]:IsVisible() then
					PartyHealer.partyRez[self.unit]:Show()
				elseif not UnitIsDeadOrGhost(self.unit) and PartyHealer.partyRez[self.unit]:IsVisible() then
					PartyHealer.partyRez[self.unit]:Hide()
				end
			end
		end
	end
end

function f:CreatePartyFrames()
	for i=0,4 do
		local pf
		local rezbutton
		
		if i == 0 then
			--player
			pf = CreateFrame("Button", "PH_PlayerButton", UIParent, "SecureUnitButtonTemplate")
			pf:SetAttribute("unit", "player")
			pf.unit = "player"
			pf.unitVehicle = "pet"
			pf:SetPoint("TOPLEFT", "PartyHealerAnchor", "BOTTOMRIGHT", 0, 0)
		else
			--party members
			pf = CreateFrame("Button", "PH_Party"..i.."Button", UIParent, "SecureUnitButtonTemplate")
			pf:SetAttribute("unit", "party"..i)
			pf.unit = "party"..i
			pf.unitVehicle = "partypet"..i
			if i == 1 then
				pf:SetPoint("BOTTOMLEFT", "PH_PlayerButton", "BOTTOMLEFT", 0, -31)
			else
				pf:SetPoint("BOTTOMLEFT", "PH_Party"..(i-1).."Button", "BOTTOMLEFT", 0, -30)
			end
			f.partyF["party"..i] = pf
		end
		
		--this does frequent updates for the health and power, so that way it's always accurate
		pf.disconnected = true --turn off auto-updating until online check is done
		pf:SetScript("OnUpdate", doHealthPowerUpdate)
		
		if i == 0 then
			--for powerbar
			pf:SetHeight(PH_DB.BarHeight + 4)
		else
			pf:SetHeight(PH_DB.BarHeight)
		end
		
		pf:SetWidth(PH_DB.BarWidth)
		pf:RegisterForClicks('AnyUp')
		pf:SetBackdrop( {
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground";
			insets = { left = -1; right = -1; top = -1; bottom = -1; };
		} );
		pf:SetBackdropColor(0, 0, 0)

		pf.Health = CreateFrame('StatusBar', nil, pf)
		pf.Health:SetPoint('TOPRIGHT')
		pf.Health:SetPoint('TOPLEFT')
		pf.Health:SetStatusBarTexture("Interface\\AddOns\\PartyHealer\\textures\\minimalist.tga")
		pf.Health:SetStatusBarColor(0.25, 0.25, 0.35)
		pf.Health:SetHeight(PH_DB.BarHeight)
		pf.Health:SetWidth(PH_DB.BarWidth)

		pf.Health.bg = pf.Health:CreateTexture(nil, 'BORDER')
		pf.Health.bg:SetAllPoints(pf.Health)
		pf.Health.bg:SetTexture(0.3, 0.3, 0.3)

		--do player mana bar
		if i == 0 then
			pf.Power = CreateFrame('StatusBar', nil, pf)
			pf.Power:SetPoint('BOTTOMRIGHT')
			pf.Power:SetPoint('BOTTOMLEFT')
			pf.Power:SetPoint('TOP', pf.Health, 'BOTTOM', 0, 0)
			pf.Power:SetStatusBarTexture("Interface\\AddOns\\PartyHealer\\textures\\minimalist.tga")
			pf.Power:SetHeight(4)
			
			local _, ptype = UnitPowerType("player")
			local pColor = PowerBarColor[ptype]
			pf.Power:SetStatusBarColor(pColor.r, pColor.g, pColor.b);
			
			pf.Power.bg = pf.Power:CreateTexture(nil, 'BORDER')
			pf.Power.bg:SetAllPoints(pf.Power)
			pf.Power.bg:SetTexture(0.3, 0.3, 0.3)
			pf.Power:Show()
		end
		
		pf.HealthText = pf.Health:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmallRight')
		pf.HealthText:SetPoint('RIGHT', pf.Health, -2, -1)
		pf.HealthText:SetText("0 / 0")

		pf.InfoText = pf.Health:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmallLeft')
		pf.InfoText:SetPoint('LEFT', pf.Health, 2, -1)
		pf.InfoText:SetPoint('RIGHT', pf.HealthText, 'LEFT')

		if i == 0 then
			pf.InfoText:SetText("Player")
		else
			pf.InfoText:SetText("Party"..i)
		end
		
		pf.CurrStatus = pf.Health:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		pf.CurrStatus:SetPoint('TOPRIGHT', pf.Health, 'TOPRIGHT', 0, 5)
		pf.CurrStatus:SetJustifyH('LEFT')
		pf.CurrStatus:SetFont("Interface\\AddOns\\PartyHealer\\fonts\\squares.ttf", 6, "THINOUTLINE")
		
		pf.BuffStatus = pf.Health:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		pf.BuffStatus:SetPoint('TOPLEFT', pf.Health, 'TOPLEFT', 0, 5)
		pf.BuffStatus:SetJustifyH('LEFT')
		pf.BuffStatus:SetFont("Interface\\AddOns\\PartyHealer\\fonts\\squares.ttf", 6, "THINOUTLINE")

		pf.Class = CreateFrame("Frame", nil, pf)
		pf.Class:SetFrameStrata("MEDIUM")
		pf.Class:SetWidth(PH_DB.BarHeight + 4)
		pf.Class:SetHeight(PH_DB.BarHeight + 4)
		pf.Class.icon = pf.Class:CreateTexture(nil, "BACKGROUND")
		pf.Class.icon:SetTexture("Interface\\AddOns\\PartyHealer\\textures\\Unknown")
		pf.Class.icon:SetAllPoints(pf.Class)
		pf.Class:SetPoint("TOPLEFT", pf, "TOPLEFT", -25, 2)
		pf.Class:Show()
		
		pf.Role = pf.Health:CreateTexture(nil, 'BORDER')
		pf.Role:SetWidth(PH_DB.BarHeight + 4)
		pf.Role:SetHeight(PH_DB.BarHeight + 4)
		pf.Role:SetDrawLayer('OVERLAY')
		pf.Role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
		pf.Role:SetPoint("TOPLEFT", pf, "TOPLEFT", -50, 2)
		pf.Role:Hide()
			
		--create the rez buttons
		-----------------------------------
		if i == 0 then
			rezbutton = CreateFrame("Button", "PH_PlayerButtonRez", UIParent, "SecureUnitButtonTemplate")
			rezbutton:SetAttribute("unit", "player")
			rezbutton.unit = "player"
			f.partyRez["player"] = rezbutton
		else
			--party members
			rezbutton = CreateFrame("Button", "PH_Party"..i.."ButtonRez", UIParent, "SecureUnitButtonTemplate")
			rezbutton:SetAttribute("unit", "party"..i)
			rezbutton.unit = "party"..i
			f.partyRez["party"..i] = rezbutton
		end
		
		rezbutton.parentUnit = pf
		
		rezbutton:SetScript("OnUpdate", function(self, elap)
			--this is to hide the rez button if the healthbar isn't visible
			if not InCombatLockdown() and not self.parentUnit:IsVisible() and self:IsVisible() then
				self:Hide()
			end
		end)

		rezbutton:SetPoint("TOPRIGHT",  pf, "TOPRIGHT", 27, 0)
		rezbutton:SetHeight(PH_DB.BarHeight + 1)
		rezbutton:SetWidth(PH_DB.BarHeight + 1)	
		
		rezbutton.icon = rezbutton:CreateTexture(nil, 'BORDER')
		rezbutton.icon:SetWidth(PH_DB.BarHeight + 1)
		rezbutton.icon:SetHeight(PH_DB.BarHeight + 1)
		rezbutton.icon:SetDrawLayer('OVERLAY')
		rezbutton.icon:SetTexture("Interface\\Icons\\Spell_Holy_Resurrection")
		rezbutton.icon:SetAllPoints(rezbutton)
		rezbutton.icon:Show()
		rezbutton:Hide()
		-----------------------------------
		
		--set the button clicking spells
		f:SetButtonSpells(pf, rezbutton)

	end
	
	--set the button scales
	f:SetButtonScale()
	
	--set button alpha
	f:SetButtonAlpha()
	
end

------------------------------
--     Frame Functions      --
------------------------------

function f:SetButtonScale()
	for i=0,4 do
		local button
		local buttonRez
		if i == 0 then
			button = PH_PlayerButton
			buttonRez = PH_PlayerButtonRez
		else
			button = getglobal("PH_Party"..i.."Button")
			buttonRez = getglobal("PH_Party"..i.."ButtonRez")
		end
		button:SetScale(PH_DB.Scale)
		buttonRez:SetScale(PH_DB.Scale)
	end
end

function f:SetButtonAlpha()
	for i=0,4 do
		local button
		local buttonRez
		if i == 0 then
			button = PH_PlayerButton
			buttonRez = PH_PlayerButtonRez
		else
			button = getglobal("PH_Party"..i.."Button")
			buttonRez = getglobal("PH_Party"..i.."ButtonRez")
		end
		button:SetAlpha(PH_DB.Alpha)
		buttonRez:SetAlpha(PH_DB.Alpha)
	end
end

function f:SetBarSize()
	for i=0,4 do
		local button
		local buttonRez
		if i == 0 then
			button = PH_PlayerButton
			buttonRez = PH_PlayerButtonRez
		else
			button = getglobal("PH_Party"..i.."Button")
			buttonRez = getglobal("PH_Party"..i.."ButtonRez")
		end
		button:SetWidth(PH_DB.BarWidth)
		button:SetHeight(PH_DB.BarHeight)
	end
end

function f:SetBlizzardRaidFrames()
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("PartyHealer: You cannot edit these settings while in combat!")
		return
	end
end

function f:SetButtonSpells(button, buttonrez)
	if not button then return end
	
	if not PH_DB.spells then
		PH_DB.spells = {}
	end
	
	--do loop through possible mouse buttons
	for x=1, getn(Mouse_List), 1 do
		--do loop through possible mouse click combinations
        for y=1, getn(Keys_List), 1 do
		
			local acbPrefix = nil
			
			--only put a hyphen for keypressed + mouseclicks
            if strlen(Keys_List[y]) > 1 then
                acbPrefix = strlower(Keys_List[y]).."-"
            else
                acbPrefix = "";
            end
			
            if acbPrefix then
				if PH_DB.spells[x] and PH_DB.spells[x][y] then
					if PH_DB.spells[x][y] == "target" then
						button:SetAttribute(acbPrefix.."helpbutton"..x, "heal"..x)
						button:SetAttribute(acbPrefix.."type-heal"..x, "target")
					else
						button:SetAttribute(acbPrefix.."helpbutton"..x, "heal"..x)
						button:SetAttribute(acbPrefix.."type-heal"..x, "spell")
						button:SetAttribute(acbPrefix.."spell-heal"..x, PH_DB.spells[x][y])
					end
				else
					--remove any action currently on the button
					button:SetAttribute(acbPrefix.."helpbutton"..x, nil)
					button:SetAttribute(acbPrefix.."type-heal"..x, nil)
					button:SetAttribute(acbPrefix.."spell-heal"..x, nil)
				end
            end
			
        end
	end

	if buttonrez then
		buttonrez.icon:SetTexture(f.resSpellIcons[currentPlayerClass] or "Interface\\Icons\\Spell_Holy_Resurrection")
		buttonrez:SetAttribute( "*helpbutton1", "heal" )
		buttonrez:SetAttribute( "*type-heal", "spell" )
		buttonrez:SetAttribute( "spell-heal", f.resSpells[currentPlayerClass] or nil )
	end

end

function f:UpdateFrames()

	--this is to prevent multiple updates at once
	if f.doingFrameUpdate then return end
	
	--don't update this while in combat causes a taint for some reason (probably because of ActionButton)
	if InCombatLockdown() then
		f.doupdateparty = true
		f.doingFrameUpdate = nil
		return
	end
	
	--set frame update boolean
	f.doingFrameUpdate = true
	
	if PH_DB == nil then f:StartupDB() end
	
	for i=0,4 do
		local frmUH
		local unitID
		local pass = false
		
		if i == 0 then
			frmUH = PH_PlayerButton
			unitID = "player"
		else
			frmUH = f.partyF["party"..i]
			unitID = "party"..i
		end
		
		if not frmUH then
			f.doingFrameUpdate = nil
			return
		end
		
		if (i ~= 0 and i <= GetNumPartyMembers() ) then pass=true end
		if (i == 0 and GetNumPartyMembers() > 0 ) then pass=true end
		if PartyHealerAnchor:IsVisible() then pass=true end --allow if repositioning the anchor
		if not f:DisplayCheck(false) then pass=false end
		
		if PH_DB.PH_Toggle and pass then
			local class = select(2, UnitClass(unitID))
			local isTank, isHealer, isDamage = UnitGroupRolesAssigned(unitID)
			
			frmUH.Class.icon:SetTexture("Interface\\AddOns\\PartyHealer\\textures\\"..(class or "Unknown"))
			
			if(isTank) then
				frmUH.Role:SetTexCoord(0, 19/64, 22/64, 41/64);
				frmUH.Role:Show()
			elseif(isHealer) then
				frmUH.Role:SetTexCoord(20/64, 39/64, 1/64, 20/64);
				frmUH.Role:Show()
			elseif(isDamage) then
				frmUH.Role:SetTexCoord(20/64, 39/64, 22/64, 41/64);
				frmUH.Role:Show()
			else
				frmUH.Role:Hide()
			end

			frmUH.InfoText:SetText(UnitName(unitID) or "Unknown")
			
			if UnitHasVehicleUI(unit) then
				pUH.Health:SetStatusBarColor(204/255, 194/255, 138/255)
			end
			
			if UnitHasVehicleUI(frmUH.unit) then
				frmUH.HealthText:SetText((UnitHealth(frmUH.unitVehicle) or 0).." / "..(UnitHealthMax(frmUH.unitVehicle) or 0))
				frmUH.Health:SetStatusBarColor(204/255, 194/255, 138/255)
			else
				frmUH.HealthText:SetText((UnitHealth(unitID) or 0).." / "..(UnitHealthMax(unitID) or 0))
			end

			frmUH:Show() --show the party bar
			
			--force a status update for this unit
			--must be done after frame is shown
			f:UpdateHealth(frmUH, unitID)
			if unitID == "player" then
				f:UpdatePower(frmUH, unitID)
			end
			
			--update the casting bar position based on shown party members
			if f.castbar then
				f.castbar:SetPoint("BOTTOMLEFT",frmUH, "BOTTOMLEFT",0,-40)
			end
		
		else
			frmUH:Hide() --hide the unused party bar
			
		end
		
	end

	--show castbar depending if there are any party members (boolean for PartyHealer_CastBar)
	--also check to see if PartyHealer is toggled off
	if not PH_DB.PH_Toggle or not f:DisplayCheck(true) then
		f.showcastbar = false
	elseif f.castbar and (GetNumPartyMembers() < 1) and f.showcastbar then
		f.showcastbar = false
	elseif f.castbar and GetNumPartyMembers() > 0 and (not f.showcastbar) then
		if not PH_DB.PH_HideCastBar then
			f.showcastbar = true
		end
	end
			
	f.doingFrameUpdate = nil
	
end

------------------------------
--      Unit Functions      --
------------------------------

function f:UpdateHealth(pUH, unit)
	if not pUH then return end
	if f.updatingHealth then return end
	f.updatingHealth = true

	if ( pUH:IsVisible() ) then
		
		pUH.disconnected = not UnitIsConnected(unit)
		
		local min, max = UnitHealth(unit), UnitHealthMax(unit)
		--check for vehicle
		if UnitHasVehicleUI(unit) then
			min, max = UnitHealth(pUH.unitVehicle), UnitHealthMax(pUH.unitVehicle)
		end
		
		local percent = (tonumber(min) / tonumber(max))
		
		if ( not UnitIsDeadOrGhost(unit) and not pUH.disconnected ) then
			pUH.HealthText:SetText(min.." / "..max)
			pUH.Health:SetMinMaxValues(0, max)
			pUH.Health:SetValue(min)
			pUH.min = min
			
			--set health bar color
			if UnitHasVehicleUI(unit) then
				pUH.Health:SetStatusBarColor(204/255, 194/255, 138/255)
			elseif (percent > 0.5)  then
				pUH.Health:SetStatusBarColor(2 * (1 - percent), 1, 0)
			else
				pUH.Health:SetStatusBarColor(1, 2 * percent, 0)
			end
		else
			if UnitIsDead(unit) then
				pUH.HealthText:SetText("DEAD")
			elseif UnitIsGhost(unit) then
				pUH.HealthText:SetText("GHOST")
			elseif pUH.disconnected then
				pUH.HealthText:SetText("OFFLINE")
			end
			pUH.Health:SetMinMaxValues(0, 0)
			pUH.Health:SetValue(0)
			pUH.Health:SetStatusBarColor(0, 0, 0)
			pUH.min = 0
		end
		
		--do the debuffs and buffs
		f:UpdateDebuffs(pUH, unit)
		f:UpdateBuffs(pUH, unit)
		
	end
	
	f.updatingHealth = nil
	
end

function f:UpdatePower(pUH, unit)
	if not pUH then return end
	if f.updatingPower then return end
	f.updatingPower = true

	if (pUH:IsVisible()) then
	
		local min, max = UnitPower(unit), UnitPowerMax(unit)

		pUH.Power:SetMinMaxValues(0, max)
		pUH.Power:SetValue(min)
		pUH.powermin = min
		
	end
	
	f.updatingPower = nil
end

function f:UpdateDebuffs(pUH, unit)
	if not pUH or not unit then return end
	if f.updatingDebuffs then return end
	f.updatingDebuffs = true
	
	--check for debuffs (if we don't have any then remove the text)
	if not UnitDebuff(unit, 1, true) then
		if pUH.CurrStatus:GetText() ~= "" then pUH.CurrStatus:SetText("") end
		f.updatingDebuffs = nil
		return
	end
	
	pUH.setDebuffType = {} --reset
	
	for b=1, 40 do
		local dname, _, _, _, debufftype = UnitDebuff(unit, b, true) --true = removable
		if not dname then break end
		
		if debufftype then
			if f.decurseSpells and f.decurseSpells[currentPlayerClass] then
				if f.decurseSpells[currentPlayerClass][debufftype] then
					pUH.setDebuffType[debufftype] = true
				end
			end
		end
	end

	local dbuffStr = ""
	
	--the letter M is used because the square is a perfect size
	if pUH.setDebuffType["Magic"] then
		dbuffStr = dbuffStr.."  "..(f:GetDebuffHexColor("Magic", "M") or "M")
	end
	if pUH.setDebuffType["Curse"] then
		dbuffStr = dbuffStr.."  "..(f:GetDebuffHexColor("Curse", "M") or "M")
	end
	if pUH.setDebuffType["Disease"] then
		dbuffStr = dbuffStr.."  "..(f:GetDebuffHexColor("Disease", "M") or "M")
	end
	if pUH.setDebuffType["Poison"] then
		dbuffStr = dbuffStr.."  "..(f:GetDebuffHexColor("Poison", "M") or "M")
	end
	
	--set the debuff text (empty if nothing found)
	pUH.CurrStatus:SetText(dbuffStr)
	
	f.updatingDebuffs = nil
end

function f:UpdateBuffs(pUH, unit)
	if not pUH or not unit then return end
	if f.updatingBuffs then return end
	f.updatingBuffs = true
	
	--check for debuffs (if we don't have any then remove the text)
	if not UnitBuff(unit, 1, true) then
		if pUH.BuffStatus:GetText() ~= "" then pUH.BuffStatus:SetText("") end
		f.updatingBuffs = nil
		return
	end
	
	local foundBuffs = {}
	
	for b=1, 40 do
		local dname = UnitBuff(unit, b) --true = removable
		if not dname then break end
		dname = string.lower(dname)
		if PH_DB.buffs and PH_DB.buffs[dname] then
			foundBuffs[PH_DB.buffs[dname]] = true
		end
	end

	local buffStr = ""
	
	--the letter M is used because the square is a perfect size
	if foundBuffs[1] then buffStr = buffStr.."  |cFFFF0000M|r" end
	if foundBuffs[2] then buffStr = buffStr.."  |cFF00FF00M|r" end
	if foundBuffs[3] then buffStr = buffStr.."  |cFF0000FFM|r" end
	if foundBuffs[4] then buffStr = buffStr.."  |cFFFF99CCM|r" end
	if foundBuffs[5] then buffStr = buffStr.."  |cFFFF9900M|r" end
	if foundBuffs[6] then buffStr = buffStr.."  |cFF00FFFFM|r" end
	
	--set the buff text (empty if nothing found)
	pUH.BuffStatus:SetText(buffStr)
	
	f.updatingBuffs = nil
end

------------------------------
--      Color Function      --
------------------------------

function f:GetClassHexColor(class, name)
	local color = RAID_CLASS_COLORS[class]

	if not color then
		return name
	else
		return "|cFF"..("%.2x%.2x%.2x"):format(color.r*255,color.g*255,color.b*255)..name.."|r"
	end
end

function f:GetDebuffHexColor(debufftype, name)
	local color = DebuffTypeColor[debufftype]

	if not color then
		return ""
	else
		return "|cFF"..("%.2x%.2x%.2x"):format(color.r*255,color.g*255,color.b*255)..name.."|r"
	end
end

------------------------------
--    Position Function     --
------------------------------

function f:SaveLayout(frame)

	if not PH_DB then PH_DB = {} end

	local opt = PH_DB[frame] or nil;

	if opt == nil then
		PH_DB[frame] = {
			["point"] = "CENTER",
			["relativePoint"] = "CENTER",
			["xOfs"] = 0,
			["yOfs"] = 0,
		}
		opt = PH_DB[frame];
	end

	local f = getglobal(frame);
	local scale = f:GetEffectiveScale();
	opt.PosX = f:GetLeft() * scale;
	opt.PosY = f:GetTop() * scale;
	--opt.Width = f:GetWidth();
	--opt.Height = f:GetHeight();

end

function f:RestoreLayout(frame)

	if not PH_DB then PH_DB = {} end
	
	local f = getglobal(frame);
	local opt = PH_DB[frame] or nil;

	if opt == nil then
		PH_DB[frame] = {
			["point"] = "CENTER",
			["relativePoint"] = "CENTER",
			["xOfs"] = 0,
			["yOfs"] = 0,
		}
		opt = PH_DB[frame];
	end

	local x = opt.PosX;
	local y = opt.PosY;
	local s = f:GetEffectiveScale();

	    if not x or not y then
		f:ClearAllPoints();
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
		return 
	    end

	--calculate the scale
	x,y = x/s,y/s;

	--set the location
	f:ClearAllPoints();
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y);

end

------------------------------
--    Display Functions     --
------------------------------

function f:IsInBG()
	if (GetNumBattlefieldScores() > 0) then
		return true
	end
	local status, mapName, instanceID, minlevel, maxlevel
	for i=1, MAX_BATTLEFIELD_QUEUES do
		status, mapName, instanceID, minlevel, maxlevel, teamSize = GetBattlefieldStatus(i)
		if status == "active" then
			return true
		end
	end
	return false
end

function f:IsInArena()
	local a,b = IsActiveBattlefieldArena()
	if (a == nil) then
		return false
	end
	return true
end

function f:DisplayCheck(switch)
	if f:IsInBG() and not PH_DB.showBG then return false end
	--this one is for those people that want it to show in a BG, but have show in raid deactivated.
	--technically it would disable it even if they want it to show in a BG, only because they selected
	--not to show it in a raid
	if f:IsInBG() and PH_DB.showBG then return true end 
	if f:IsInArena() and not PH_DB.showArena then return false end 
	if GetNumRaidMembers() > 0 and not PH_DB.showRaid then return false end
	if switch and getglobal("PH_PlayerButton") and not getglobal("PH_PlayerButton"):IsVisible() then return end
	return true
end

------------------------------
--   Hide Blizzard Frames   --
------------------------------

function f:HideBlizzardPartyFrames()
	if not PH_DB then return end
	if not PH_DB.PH_HideParty_Toggle then return end
	
	local sPFrm = {}
	
	table.insert(sPFrm, PartyMemberFrame1)
	table.insert(sPFrm, PartyMemberFrame1PetFrame)
	table.insert(sPFrm, PartyMemberFrame2)
	table.insert(sPFrm, PartyMemberFrame2PetFrame)
	table.insert(sPFrm, PartyMemberFrame3)
	table.insert(sPFrm, PartyMemberFrame3PetFrame)
	table.insert(sPFrm, PartyMemberFrame4)
	table.insert(sPFrm, PartyMemberFrame4PetFrame)

	if sPFrm == nil or table.getn(sPFrm) < 1 then return end
	
	--hide and unregister the party frames
	for i = 1, #sPFrm do
		local frameObject = sPFrm[i]
		if frameObject then
			frameObject:UnregisterAllEvents()
			frameObject:SetScript("OnEvent", nil)
			frameObject:SetScript("OnShow", nil)
			frameObject:SetScript("OnUpdate", nil)
			if (not InCombatLockdown()) then
				frameObject:ClearAllPoints()
				frameObject:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 1000, -1000)
				frameObject:Hide()
			end
		end
	end
	
	--special thanks to Perl Classic Frames
	hooksecurefunc("ShowPartyFrame",
		function()
			if (not InCombatLockdown() and PH_DB and PH_DB.PH_HideParty_Toggle) then
				for i = 1,4 do
					getglobal("PartyMemberFrame"..i):Hide()
				end
			end
		end
	)
	
end
	
if IsLoggedIn() then f:PLAYER_LOGIN() else f:RegisterEvent("PLAYER_LOGIN") end
 
