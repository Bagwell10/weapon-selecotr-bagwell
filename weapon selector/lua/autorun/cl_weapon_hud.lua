if SERVER then resource.AddFile( "resource/fonts/Lato-Light.ttf" ) return end

surface.CreateFont( "RPInfo", {
    font = "Lemon Milk",
    size = 20,
    weight = 300,
})

surface.CreateFont( "RPInfo2", {
    font = "Lemon Milk",
    size = 15,
    weight = 300,
})

-- =========================
-- Monolith-style palette
-- =========================
local color_blackbg  = Color(15, 15, 15, 200)   -- fond sombre
local color_selected = Color(179, 1, 1, 230) -- highlight bleu/gris discret
local color_border   = Color(40, 40, 40, 220)   -- contour optionnel
local color_text     = Color(230, 230, 230, 255)
local color_text_dim = Color(180, 180, 180, 220)

local scale = (ScrW() >= 2560 and 2) or (ScrW() / 175 >= 6 and 1) or 0.8
local curTab, curSlot, alpha, lastAction, loadout, slide, newinv = 0, 1, 0, -math.huge, {}, {}, nil

hook.Add("CreateMove", "RPInfo", function(cmd)
	if newinv then
		local wep = LocalPlayer():GetWeapon(newinv)
		if IsValid(wep) and LocalPlayer():GetActiveWeapon() ~= wep then
			cmd:SelectWeapon(wep)
		else
			newinv = nil
		end
	end
end)

local CWeapons = {}
for _, y in pairs(file.Find("scripts/weapon_*.txt", "MOD")) do
	local t = util.KeyValuesToTable(file.Read("scripts/" .. y, "MOD"))
	CWeapons[y:match("(.+)%.txt")] = {
		Slot = t.bucket,
		SlotPos = t.bucket_position,
		TextureData = t.texturedata
	}
end

local function findcurrent()
	if alpha <= 0 then
		table.Empty(slide)
		local class = IsValid(LocalPlayer():GetActiveWeapon()) and LocalPlayer():GetActiveWeapon():GetClass()
		for k1, v1 in pairs(loadout) do
			for k2, v2 in pairs(v1) do
				if v2.classname == class then
					curTab = k1
					curSlot = k2
					return
				end
			end
		end
	end
end

local function update()
	table.Empty(loadout)

	for _, v in pairs(LocalPlayer():GetWeapons()) do
		local classname = v:GetClass()
		local Slot = (CWeapons[classname] and CWeapons[classname].Slot) or v.Slot or 1
		loadout[Slot] = loadout[Slot] or {}
		table.insert(loadout[Slot], {
			classname = classname,
			name = v:GetPrintName(),
			new = (CurTime() - v:GetCreationTime()) < 60,
			slotpos = (CWeapons[classname] and CWeapons[classname].SlotPos) or v.SlotPos or 1
		})
	end
	for _, v in pairs(loadout) do
		table.sort(v, function(a, b) return a.slotpos < b.slotpos end)
	end
end

hook.Add("PlayerBindPress", "overrideGMFunction", function(ply, bind, pressed)
	if not pressed or ply:InVehicle() then return end
	bind = bind:lower()
	if bind:sub(1, 4) == "slot" then
		local n = tonumber(bind:sub(5, 5) or 1) or 1
		if n < 1 or n > 6 then return true end
		n = n - 1
		update()
		if not loadout[n] then return true end
		findcurrent()
		if curTab == n and loadout[curTab] and (alpha > 0 or GetConVarNumber("hud_fastswitch") > 0) then
			curSlot = curSlot + 1
			if curSlot > #loadout[curTab] then
				curSlot = 1
			end
		else
			curTab = n
			curSlot = 1
		end
		if GetConVarNumber("hud_fastswitch") > 0 then
			newinv = loadout[curTab][curSlot].classname
		else
			alpha = 1
			lastAction = RealTime()
		end
		return true
	elseif bind:find("invnext", nil, true) and not (IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK)) then
		update()
		if #loadout < 1 then return true end
		findcurrent()
		curSlot = curSlot + 1
		if curSlot > (loadout[curTab] and #loadout[curTab] or -1) then
			repeat
				curTab = curTab + 1
				if curTab > 5 then
					curTab = 0
				end
			until loadout[curTab]
			curSlot = 1
		end
		if GetConVarNumber("hud_fastswitch") > 0 then
			newinv = loadout[curTab][curSlot].classname
		else
			lastAction = RealTime()
			alpha = 1
		end
		return true
	elseif bind:find("invprev", nil, true) and not (IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK)) then
		update()
		if #loadout < 1 then return true end
		findcurrent()
		curSlot = curSlot - 1
		if curSlot < 1 then
			repeat
				curTab = curTab - 1
				if curTab < 0 then
					curTab = 5
				end
			until loadout[curTab]
			curSlot = #loadout[curTab]
		end
		if GetConVarNumber("hud_fastswitch") > 0 then
			newinv = loadout[curTab][curSlot].classname
		else
			lastAction = RealTime()
			alpha = 1
		end
		return true
	elseif bind:find("+attack", nil, true) and alpha > 0 then
		if loadout[curTab] and loadout[curTab][curSlot] and not bind:find("+attack2", nil, true) then
			newinv = loadout[curTab][curSlot].classname
		end
		alpha = 0
		return true
	end
end)

local intW, itemH = 175 * scale, 22 * scale
local intM = (itemH / 4) * scale

hook.Add("HUDPaint", "wepsel", function()
	if not IsValid(LocalPlayer()) then return end

	if alpha < 1e-02 then 
		if alpha ~= 0 then
			alpha = 0
		end
		return
	end

	update()

	if RealTime() - lastAction > 2 then
		alpha = Lerp(FrameTime() * 4, alpha, 0)
	end

	surface.SetAlphaMultiplier(alpha)

	-- Police par défaut pour le texte
	surface.SetFont("RPInfo")

	local offx = 10

	for i, v in pairs(loadout) do
		local offy = intM + 10

		for j, wep in pairs(v) do
			local selected = curTab == i and curSlot == j

			-- Animation de slide sur l'élément sélectionné
			slide[wep.classname] = Lerp(FrameTime() * 12, slide[wep.classname] or 0, selected and .5 or 0)
			local h = itemH + (itemH + intM) * (slide[wep.classname] or 0)

			-- Fond
			surface.SetDrawColor(selected and color_selected or color_blackbg)
			surface.DrawRect(offx, offy, intW, h)

			-- Contour (donne du relief)
			surface.SetDrawColor(color_border)
			surface.DrawOutlinedRect(offx, offy, intW, h)

			-- Texte (dim si non sélectionné)
			local name = wep.name or wep.classname or "Unknown"
			surface.SetFont("RPInfo")
			local w, th = surface.GetTextSize(name)
			if w > intW - 10 then
				surface.SetFont("RPInfo2")
				w, th = surface.GetTextSize(name)
			end
			surface.SetTextColor(selected and color_text or color_text_dim)
			surface.SetTextPos(offx + (intW - w) / 2, offy + (h - th) / 2)
			surface.DrawText(name)

			offy = offy + h + intM
		end

		offx = offx + intW + intM
	end

	surface.SetAlphaMultiplier(1)
end)
