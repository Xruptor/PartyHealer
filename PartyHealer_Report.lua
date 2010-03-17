local reportTable = {}
local repRows, repAnchor = {}
local currentPlayer = UnitName('player')
local currentRealm = GetRealmName()
local Keys_List = {"","Shift","Ctrl","Alt","Alt-Shift","Ctrl-Shift"}
local Mouse_List = {"Left","Right","Middle","Button4","Button5","Button6","Button7","Button8","Button9","Button10"}

local phReport = CreateFrame("Frame","PartyHealer_ReportFrame", UIParent)
phReport:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

phReport:SetFrameStrata("HIGH")
phReport:SetToplevel(true)
phReport:EnableMouse(true)
phReport:SetMovable(true)
phReport:SetClampedToScreen(true)
phReport:SetWidth(380)
phReport:SetHeight(500)

phReport:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 32,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
})

phReport:SetBackdropColor(0,0,0,1)
phReport:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

local addonTitle = phReport:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
addonTitle:SetPoint("CENTER", phReport, "TOP", 0, -20)
addonTitle:SetText("|cFF99CC33PartyHealer|r |cFFFFFFFF(Report Window)|r")

local closeButton = CreateFrame("Button", nil, phReport, "UIPanelCloseButton");
closeButton:SetPoint("TOPRIGHT", phReport, -15, -8);

phReport:SetScript("OnShow", function(self) self:DoReport() self:LoadSlider() end)
phReport:SetScript("OnHide", function(self)
	reportTable = {}
end)

phReport:SetScript("OnMouseDown", function(frame, button)
	if frame:IsMovable() then
		frame.isMoving = true
		frame:StartMoving()
	end
end)

phReport:SetScript("OnMouseUp", function(frame, button) 
	if( frame.isMoving ) then
		frame.isMoving = nil
		frame:StopMovingOrSizing()
	end
end)

function phReport:LoadSlider()
	
	local EDGEGAP, ROWHEIGHT, ROWGAP, GAP = 16, 20, 2, 4
	local FRAME_HEIGHT = phReport:GetHeight() - 50
	local SCROLL_TOP_POSITION = -80
	local totalrepRows = math.floor((FRAME_HEIGHT-22)/(ROWHEIGHT + ROWGAP))
	
	for i=1, totalrepRows do
		if not repRows[i] then
			local row = CreateFrame("Button", nil, phReport)
			if not repAnchor then row:SetPoint("BOTTOMLEFT", phReport, "TOPLEFT", 0, SCROLL_TOP_POSITION)
			else row:SetPoint("TOP", repAnchor, "BOTTOM", 0, -ROWGAP) end
			row:SetPoint("LEFT", EDGEGAP, 0)
			row:SetPoint("RIGHT", -EDGEGAP*1-8, 0)
			row:SetHeight(ROWHEIGHT)
			row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			repAnchor = row
			repRows[i] = row

			local title = row:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
			title:SetPoint("LEFT")
			title:SetJustifyH("LEFT") 
			title:SetWidth(row:GetWidth())
			title:SetHeight(ROWHEIGHT)
			row.title = title
		end
	end

	local offset = 0
	local RefreshReport = function()
		if not PartyHealer_ReportFrame:IsVisible() then return end
		
		for i,row in ipairs(repRows) do
			if (i + offset) <= #reportTable then
				if reportTable[i + offset] then
					if reportTable[i + offset].isHeader then
						row.title:SetText("|cFFFFFFFF"..reportTable[i + offset].name.."|r")
						row:LockHighlight()
						row.title:SetJustifyH("CENTER") 
					else
						row.title:SetText(reportTable[i + offset].name)
						row:UnlockHighlight()
						row.title:SetJustifyH("LEFT")
					end
				end
				row:Show()
			else
				row:Hide()
			end
		end
	end

	RefreshReport()

	if not phReport.scrollbar then
		phReport.scrollbar = LibStub("tekKonfig-Scroll").new(phReport, nil, #repRows/2)
		phReport.scrollbar:ClearAllPoints()
		phReport.scrollbar:SetPoint("TOP", repRows[1], 0, -16)
		phReport.scrollbar:SetPoint("BOTTOM", repRows[#repRows], 0, 16)
		phReport.scrollbar:SetPoint("RIGHT", -16, 0)
	end
	
	if #reportTable > 0 then
		phReport.scrollbar:SetMinMaxValues(0, math.max(0, #reportTable - #repRows))
		phReport.scrollbar:SetValue(0)
		phReport.scrollbar:Show()
	else
		phReport.scrollbar:Hide()
	end

	local f = phReport.scrollbar:GetScript("OnValueChanged")
	phReport.scrollbar:SetScript("OnValueChanged", function(self, value, ...)
		offset = math.floor(value)
		RefreshReport()
		return f(self, value, ...)
	end)

	phReport:EnableMouseWheel()
	phReport:SetScript("OnMouseWheel", function(self, val)
		phReport.scrollbar:SetValue(phReport.scrollbar:GetValue() - val*#repRows/2)
	end)
end

function phReport:DoReport()
	if not PH_DB then return end
	if not PH_DB.spells then return end
	
	reportTable = {} --reset
	local tmp = {}
	
	-----------------------------------
	--do loop through possible mouse buttons
	for x=1, getn(Mouse_List), 1 do
		--do loop through possible mouse click combinations
        for y=1, getn(Keys_List), 1 do
		
			local acbPrefix = nil
			
			--only put a hyphen for keypressed + mouseclicks
            if strlen(Keys_List[y]) > 1 then
                acbPrefix = Keys_List[y]
            else
                acbPrefix = "Click";
            end
			
            if acbPrefix then
				if PH_DB.spells[x] and PH_DB.spells[x][y] then
					acbPrefix = acbPrefix..": |cFFFFFFFF"..PH_DB.spells[x][y].."|r"
					table.insert(reportTable, {name=acbPrefix, mouse=x, key=y})
				end
            end
        end
	end
	-----------------------------------
	
	--sort it
	table.sort(reportTable, function(a,b)
		if a.mouse < b.mouse then
			return true;
		elseif a.mouse == b.mouse then
			return (a.key < b.key);
		end
	end)
	
	--add headers
	local lastHeader = 0
	local lastKey = 0
	for i=1, #reportTable do
		if reportTable[i].mouse ~= lastHeader then
			lastHeader = reportTable[i].mouse
			lastKey = reportTable[i].key
			table.insert(tmp, {name=Mouse_List[lastHeader], mouse=lastHeader, key=lastKey, isHeader=true})
			table.insert(tmp, reportTable[i])
		else
			table.insert(tmp, reportTable[i])
		end
	end
	reportTable = tmp
	
	phReport:LoadSlider()
end

phReport:Hide()