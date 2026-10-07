-- Bases: the BASE COLLECTION window (buy / equip the 8 bases) in the game's map style
-- (LEGO-brick cards, navy window with a checker header, spinning 3D preview with light rays,
-- stat bricks with "vs. your base" arrows, requirement checks and a big glowing buy button)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Catalog = require(RS.Shared.BaseCatalog)
local Visuals = require(RS.Shared.BaseVisuals)
local Util = require(RS.Shared.Util)
local UIKit = require(RS.Shared.UIKit)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local okMS, MS = pcall(require, script.Parent.MapStyle)
local okSnd, Sound = pcall(require, script.Parent.Sound)
local M = {}

local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local DARK = C(30, 34, 60)
local NAVY2 = C(18, 24, 66)
local GOLD = C(255, 215, 60)
local FONT = Enum.Font.FredokaOne
local LEFT_ALIGN = Enum.TextXAlignment.Left
local W, H = 960, 620
local EMOJI = {Starter = "🛖", Cottage = "🏡", Brick = "🧱", Modern = "🏢", Estate = "🏛️", Royal = "👑", Crystal = "💎", Celestial = "🌌"}
local LOCKED_COLOR = C(78, 86, 122)
local MAX_REBIRTH = Catalog.List[#Catalog.List].Rebirth

local function snd(n, v, p) if okSnd then pcall(Sound.Play, n, v, p) end end
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", {CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r)}, o) end
local function stroke(o, t, c, ctx)
	return new("UIStroke", {Thickness = t, Color = c or DARK, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = ctx and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border}, o)
end
local function seq(cols) return ColorSequence.new(cols[1], cols[2]) end
local function grad(o, a, b, rot)
	return new("UIGradient", {Color = typeof(a) == "ColorSequence" and a or ColorSequence.new(a, b or a), Rotation = rot or 90}, o)
end
local function label(parent, props)
	local l = new("TextLabel", {BackgroundTransparency = 1, Font = FONT, TextColor3 = WHITE, TextScaled = true, Text = ""}, parent)
	for k, v in pairs(props) do if k ~= "Stroke" then l[k] = v end end
	if props.Stroke ~= 0 then stroke(l, props.Stroke or 2.5, NAVY2, true) end
	return l
end
local function tint(c, k) return c:Lerp(WHITE, k) end
local function shade(c, k) return c:Lerp(Color3.new(0, 0, 0), k) end
local function pct(x) return math.floor(x * 100 + 0.5) end

-- gradient pill with outlined text (auto width)
local function chip(parent, o)
	local f = new("Frame", {Name = o.Name or "Chip", Position = o.Pos or UDim2.new(), AnchorPoint = o.Anchor or Vector2.zero, LayoutOrder = o.Order or 0,
		Size = UDim2.fromOffset(0, o.H or 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = o.Z or 5}, parent)
	corner(f, UDim.new(1, 0))
	stroke(f, 2.5, DARK)
	local g = grad(f, seq(o.Colors or UIKit.C.Gray))
	new("UIPadding", {PaddingLeft = UDim.new(0, o.Pad or 12), PaddingRight = UDim.new(0, o.Pad or 12)}, f)
	local shine = new("Frame", {Name = "Shine", BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, BorderSizePixel = 0,
		Position = UDim2.new(0, -(o.Pad or 12) + 4, 0, 3), Size = UDim2.new(1, 2 * (o.Pad or 12) - 8, 0.42, 0), ZIndex = (o.Z or 5)}, f)
	corner(shine, UDim.new(1, 0))
	local l = new("TextLabel", {Name = "Label", BackgroundTransparency = 1, Font = FONT, TextSize = o.TextSize or 17, TextColor3 = WHITE,
		Text = o.Text or "", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = (o.Z or 5) + 1}, f)
	stroke(l, 2, NAVY2, true)
	return f, l, g
end

function M.Init()
	local me = Players.LocalPlayer
	local selected = Catalog.List[1]
	local busy = false
	local refresh

	-- ===== window =====
	local win = new("Frame", {Name = "Bases", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = C(240, 243, 252), Visible = false, BorderSizePixel = 0}, UI.Windows)
	corner(win, 24)
	stroke(win, 5, DARK)
	new("UIScale", {Name = "AutoScale", Scale = 1}, win)

	-- header: green "home" gradient + checker (MapStyle), title, wallet / rebirth chips, red X
	local HC1, HC2 = C(120, 240, 170), C(22, 165, 120)
	local header = new("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1}, win)
	corner(header, 24)
	grad(header, HC1, HC2)
	new("Frame", {Name = "Fill", Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = HC2, BorderSizePixel = 0, ZIndex = 1}, header)
	new("Frame", {Name = "Line", Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = DARK, BorderSizePixel = 0, ZIndex = 3}, header)
	label(header, {Name = "Title", Text = "🏠 BASE COLLECTION", Position = UDim2.fromOffset(22, 11), Size = UDim2.fromOffset(430, 48),
		TextXAlignment = LEFT_ALIGN, ZIndex = 4, Stroke = 4})
	local chips = new("Frame", {Name = "Chips", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.fromOffset(440, 40),
		BackgroundTransparency = 1, ZIndex = 4}, header)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, chips)
	local _, walletL = chip(chips, {Order = 1, H = 36, Colors = UIKit.C.Green, TextSize = 20, Z = 4})
	local _, rebL = chip(chips, {Order = 2, H = 36, Colors = UIKit.C.Purple, TextSize = 20, Z = 4})
	local close = UIKit.button({Name = "Close", Colors = UIKit.C.Red, Text = "X", Size = UDim2.fromOffset(56, 56), Position = UDim2.new(1, -66, 0, 8),
		Radius = 16, ZIndex = 4, Parent = win, TextHeight = 0.7})
	UI.Button(close, function() UI.Close("Bases") end)
	if okMS then pcall(MS.Window, win) end

	-- ===== left: the collection (one LEGO brick per base) =====
	local left = new("Frame", {Name = "Left", Position = UDim2.fromOffset(16, 90), Size = UDim2.fromOffset(372, 514), BackgroundColor3 = NAVY2,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2}, win)
	corner(left, 16)
	stroke(left, 3, C(10, 14, 40))
	local list = new("ScrollingFrame", {Name = "Collection", Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 1, -78), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = GOLD, ScrollingDirection = Enum.ScrollingDirection.Y,
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, left)
	new("UIListLayout", {Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, list)
	new("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12)}, list)

	-- collection progress
	local prog = new("Frame", {Name = "Progress", Position = UDim2.new(0, 14, 1, -66), Size = UDim2.new(1, -28, 0, 54), BackgroundTransparency = 1, ZIndex = 3}, left)
	local progT = label(prog, {Text = "🏠 BASES COLLECTED", Size = UDim2.new(1, 0, 0, 20), ZIndex = 4, Stroke = 2})
	local bar = new("Frame", {Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C(10, 14, 40), BorderSizePixel = 0, ZIndex = 3}, prog)
	corner(bar, UDim.new(1, 0))
	stroke(bar, 2.5, DARK)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4}, bar)
	corner(fill, UDim.new(1, 0))
	grad(fill, seq(UIKit.C.Gold))
	local barT = label(bar, {Size = UDim2.new(1, 0, 0.78, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Stroke = 2})

	-- ===== right: details =====
	local detail = new("Frame", {Name = "Detail", Position = UDim2.fromOffset(400, 90), Size = UDim2.fromOffset(544, 514), BackgroundColor3 = NAVY2,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2}, win)
	corner(detail, 16)
	stroke(detail, 3, C(10, 14, 40))

	-- stage: coloured backdrop + spinning light rays + glow + rotating 3D base
	local stage = new("Frame", {Name = "Stage", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(520, 232), BackgroundColor3 = WHITE,
		BorderSizePixel = 0, ZIndex = 3}, detail)
	corner(stage, 14)
	stroke(stage, 3, DARK)
	local stageGrad = grad(stage, C(60, 80, 140), C(20, 26, 60))
	local rayClip = new("CanvasGroup", {Name = "Rays", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3}, stage)
	corner(rayClip, 14)
	local rays = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 3}, rayClip)
	local strips = {}
	for k = 1, 12 do
		local s = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(k % 2 == 0 and 76 or 34, 1100), Rotation = k * 15,
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 3}, rays)
		new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1)})}, s)
		strips[k] = s
	end
	local glow = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromOffset(330, 90), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 4}, rayClip)
	corner(glow, UDim.new(1, 0))
	new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})}, glow).Rotation = 0
	local vp = new("ViewportFrame", {Name = "Preview", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Ambient = C(180, 190, 220),
		LightColor = C(255, 240, 219), LightDirection = Vector3.new(-1, -1, -1)}, stage)
	local flashF = new("Frame", {Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9}, stage)
	corner(flashF, 14)
	local _, tierL, tierG = chip(stage, {Name = "Tier", Pos = UDim2.fromOffset(12, 12), H = 30, TextSize = 17, Z = 7})
	local _, stateL, stateG = chip(stage, {Name = "State", Pos = UDim2.new(1, -12, 0, 12), Anchor = Vector2.new(1, 0), H = 30, TextSize = 17, Z = 7})
	local lockBig = label(stage, {Text = "🔒", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(84, 84), ZIndex = 7, Stroke = 0})
	local lockTxt = label(stage, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(420, 26), ZIndex = 7, Stroke = 2.5})

	-- name + note
	local nameL = label(detail, {Position = UDim2.fromOffset(12, 250), Size = UDim2.fromOffset(520, 42), ZIndex = 4, Stroke = 3.5})
	local nameGrad = grad(nameL, WHITE, WHITE)
	label(detail, {Text = "✨ Bought bases are yours forever (even after rebirth) • equip owned ones for FREE", Position = UDim2.fromOffset(12, 292),
		Size = UDim2.fromOffset(520, 17), TextColor3 = C(195, 205, 240), ZIndex = 4, Stroke = 1.5})

	-- stat bricks: income bonus + base lock time, with "vs your base" arrows
	local function statTile(x, icon, title, color)
		local t = new("Frame", {Position = UDim2.fromOffset(x, 322), Size = UDim2.fromOffset(254, 72), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3}, detail)
		corner(t, 14)
		stroke(t, 3, DARK)
		label(t, {Text = icon, Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(48, 48), ZIndex = 4, Stroke = 0})
		label(t, {Text = title, Position = UDim2.fromOffset(66, 8), Size = UDim2.fromOffset(180, 20), TextXAlignment = LEFT_ALIGN, ZIndex = 4, Stroke = 2})
		local v = label(t, {Position = UDim2.fromOffset(66, 28), Size = UDim2.fromOffset(104, 36), TextXAlignment = LEFT_ALIGN, ZIndex = 4, Stroke = 3})
		local d = label(t, {Position = UDim2.fromOffset(170, 36), Size = UDim2.fromOffset(76, 22), ZIndex = 4, Stroke = 2})
		if okMS then pcall(MS.Brick, t, color, {w = 254, h = 72, studs = false, lip = 7, cell = 13, radius = 14}) end
		return v, d
	end
	local incomeV, incomeD = statTile(12, "💰", "INCOME BONUS", C(255, 185, 45))
	local lockV, lockD = statTile(278, "🛡️", "BASE LOCK TIME", C(70, 150, 255))

	-- requirements
	local reqRow = new("Frame", {Name = "Requirements", Position = UDim2.fromOffset(12, 402), Size = UDim2.fromOffset(520, 32), BackgroundTransparency = 1, ZIndex = 4}, detail)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, reqRow)
	local reqA, reqAL, reqAG = chip(reqRow, {Order = 1, H = 32, TextSize = 18, Z = 4})
	local reqB, reqBL, reqBG = chip(reqRow, {Order = 2, H = 32, TextSize = 18, Z = 4})

	-- big action button (+ a pulsing glow when you can buy / equip)
	local btnGlow = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(272, 474), Size = UDim2.fromOffset(536, 74), BackgroundColor3 = C(120, 255, 140),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3}, detail)
	corner(btnGlow, 20)
	local action = UIKit.button({Name = "Action", Colors = UIKit.C.Green, Text = "", Size = UDim2.fromOffset(520, 62), Position = UDim2.fromOffset(12, 443),
		Radius = 16, ZIndex = 4, Parent = detail, TextHeight = 0.55})
	local actionColors = UIKit.C.Green
	local canAct = false

	-- ===== the 3D preview (rotates slowly) =====
	local cam, angle = nil, math.deg(math.atan2(-91, 78))
	local R = math.sqrt(78 * 78 + 91 * 91)
	local function preview(t)
		vp:ClearAllChildren()
		cam = nil
		local src = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("BasePreview")
		if not src then return end
		local model = src:Clone()
		pcall(Visuals.Apply, model, t.Id)
		for _, a in ipairs(model:GetDescendants()) do
			if a:IsA("SurfaceGui") or a:IsA("BillboardGui") or a:IsA("ProximityPrompt") or a:IsA("Script") or a:IsA("LocalScript") then a:Destroy() end
		end
		model:PivotTo(CFrame.new())
		model.Parent = vp
		cam = new("Camera", {FieldOfView = 38}, vp)
		vp.CurrentCamera = cam
	end

	-- ===== cards =====
	local cards = {}
	local function choose(t, quiet)
		selected = t
		preview(t)
		if not quiet then snd("UITap", 0.35, 1.3) end
		-- little pop on the stage
		flashF.BackgroundTransparency = 0.6
		TweenService:Create(flashF, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
		refresh()
	end
	for i, t in ipairs(Catalog.List) do
		local card = new("TextButton", {Name = t.Id, LayoutOrder = i, Size = UDim2.new(1, -20, 0, 84), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false,
			BorderSizePixel = 0, ZIndex = 3}, list)
		corner(card, 14)
		local cs = stroke(card, 3, DARK)
		local icoBg = new("Frame", {Position = UDim2.fromOffset(10, 13), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = NAVY2, BackgroundTransparency = 0.3,
			BorderSizePixel = 0, ZIndex = 4}, card)
		corner(icoBg, UDim.new(1, 0))
		stroke(icoBg, 2.5, DARK)
		local ico = label(icoBg, {Text = EMOJI[t.Id] or "🏠", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Stroke = 0})
		local lock = label(icoBg, {Text = "🔒", Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, 6, 1, 6), AnchorPoint = Vector2.new(1, 1), ZIndex = 6, Stroke = 0, Visible = false})
		label(card, {Text = "#" .. i, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(40, 20),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Stroke = 2})
		local nm = label(card, {Text = t.Name, Position = UDim2.fromOffset(78, 11), Size = UDim2.fromOffset(210, 28), TextXAlignment = LEFT_ALIGN, ZIndex = 5, Stroke = 2.5})
		local _, stL, stG = chip(card, {Pos = UDim2.fromOffset(78, 45), H = 26, TextSize = 15, Z = 5, Pad = 10})
		if okMS then pcall(MS.Brick, card, t.Color, {w = 330, h = 84, studSize = Vector2.new(24, 12), lip = 8, cell = 14, radius = 14}) end
		cards[t.Id] = {card = card, stroke = cs, ico = ico, lock = lock, name = nm, stL = stL, stG = stG}
		UI.Button(card, function() choose(t) end, true)
	end

	-- ===== refresh everything =====
	refresh = function()
		local data = State.Data or {}
		local owned = data.OwnedBases or {Starter = true}
		local equipped = data.EquippedBase or "Starter"
		local rebirths = data.Rebirths or 0
		local cash = State.Cash()
		local eq = Catalog.ById[equipped] or Catalog.List[1]
		walletL.Text = "💵 " .. Util.Money(cash)
		rebL.Text = "🔄 REBIRTH " .. rebirths .. "/" .. MAX_REBIRTH

		local count, idx = 0, 1
		for i, t in ipairs(Catalog.List) do
			local row = cards[t.Id]
			local isOwned = owned[t.Id] == true or t.Id == "Starter"
			local locked = not isOwned and rebirths < t.Rebirth
			if isOwned then count += 1 end
			if t.Id == selected.Id then idx = i end
			local sel = t.Id == selected.Id
			row.stroke.Color = sel and GOLD or DARK
			row.stroke.Thickness = sel and 5 or 3
			if okMS then pcall(MS.Recolor, row.card, locked and LOCKED_COLOR or t.Color) end
			row.lock.Visible = locked
			row.ico.TextTransparency = locked and 0.5 or 0
			row.name.TextColor3 = locked and C(200, 205, 225) or WHITE
			if t.Id == equipped then
				row.stL.Text = "✅ EQUIPPED" row.stG.Color = seq(UIKit.C.Green)
			elseif isOwned then
				row.stL.Text = "🏠 OWNED • EQUIP FREE" row.stG.Color = seq(UIKit.C.Blue)
			elseif locked then
				row.stL.Text = "🔒 REBIRTH " .. t.Rebirth row.stG.Color = seq(UIKit.C.Gray)
			else
				row.stL.Text = "💵 " .. Util.Money(t.Price) row.stG.Color = seq(cash >= t.Price and UIKit.C.Gold or UIKit.C.Orange)
			end
		end
		barT.Text = count .. " / " .. #Catalog.List
		TweenService:Create(fill, TweenInfo.new(0.3), {Size = UDim2.fromScale(math.max(count / #Catalog.List, 0.06), 1)}):Play()
		progT.Text = count >= #Catalog.List and "👑 ALL BASES COLLECTED!" or "🏠 BASES COLLECTED"

		-- details
		local t = selected
		local isOwned = owned[t.Id] == true or t.Id == "Starter"
		local locked = not isOwned and rebirths < t.Rebirth
		local col = t.Color
		nameL.Text = (EMOJI[t.Id] or "🏠") .. " " .. string.upper(t.Name)
		nameGrad.Color = ColorSequence.new(WHITE, tint(col, 0.15))
		tierL.Text = "TIER " .. idx .. "/" .. #Catalog.List
		tierG.Color = ColorSequence.new(tint(col, 0.35), shade(col, 0.25))
		stageGrad.Color = ColorSequence.new(shade(col, locked and 0.65 or 0.25), shade(col, 0.82))
		for _, s in ipairs(strips) do s.BackgroundColor3 = tint(col, 0.55) end
		glow.BackgroundColor3 = tint(col, 0.3)
		vp.ImageColor3 = locked and C(85, 90, 120) or WHITE
		lockBig.Visible = locked
		lockTxt.Visible = locked
		lockTxt.Text = "REACH REBIRTH " .. t.Rebirth .. " TO UNLOCK"
		if t.Id == equipped then stateL.Text = "✅ EQUIPPED" stateG.Color = seq(UIKit.C.Green)
		elseif isOwned then stateL.Text = "🏠 OWNED" stateG.Color = seq(UIKit.C.Blue)
		elseif locked then stateL.Text = "🔒 LOCKED" stateG.Color = seq(UIKit.C.Gray)
		else stateL.Text = "🛒 FOR SALE" stateG.Color = seq(UIKit.C.Gold) end

		incomeV.Text = "+" .. pct(t.Income - 1) .. "%"
		lockV.Text = "+" .. t.Lock .. "s"
		local function delta(lbl, d, unit)
			if t.Id == equipped then lbl.Text = "NOW" lbl.TextColor3 = C(210, 220, 255)
			elseif d > 0 then lbl.Text = "▲ " .. d .. unit lbl.TextColor3 = C(130, 255, 150)
			elseif d < 0 then lbl.Text = "▼ " .. -d .. unit lbl.TextColor3 = C(255, 130, 130)
			else lbl.Text = "= SAME" lbl.TextColor3 = C(210, 220, 255) end
		end
		delta(incomeD, pct(t.Income - 1) - pct(eq.Income - 1), "%")
		delta(lockD, t.Lock - eq.Lock, "s")

		-- requirement checks
		local rebOk = rebirths >= t.Rebirth
		reqAL.Text = (rebOk and "✅ " or "❌ ") .. (t.Rebirth == 0 and "NO REBIRTH NEEDED" or ("REBIRTH " .. t.Rebirth))
		reqAG.Color = seq(rebOk and UIKit.C.Green or UIKit.C.Red)
		if isOwned or t.Price == 0 then
			reqBL.Text = t.Price == 0 and "🎁 FREE" or "✅ PAID"
			reqBG.Color = seq(UIKit.C.Green)
		else
			local cashOk = cash >= t.Price
			reqBL.Text = (cashOk and "✅ " or "❌ ") .. "💵 " .. Util.Money(t.Price)
			reqBG.Color = seq(cashOk and UIKit.C.Green or UIKit.C.Red)
		end

		-- button
		local text
		canAct = false
		if busy then text, actionColors = "⏳ PLEASE WAIT...", UIKit.C.Gray
		elseif equipped == t.Id then text, actionColors = "✅ EQUIPPED", UIKit.C.Gray
		elseif isOwned then text, actionColors, canAct = "🏠 EQUIP - FREE", UIKit.C.Blue, true
		elseif locked then text, actionColors = "🔒 LOCKED - REBIRTH " .. t.Rebirth, UIKit.C.Red
		elseif cash < t.Price then text, actionColors = "💵 NEED " .. Util.Money(t.Price - cash) .. " MORE", UIKit.C.Orange
		else text, actionColors, canAct = "🛒 BUY & EQUIP  " .. Util.Money(t.Price), UIKit.C.Green, true end
		UI.SetButtonText(action, text)
		UI.SetButtonColors(action, actionColors)
		btnGlow.BackgroundColor3 = actionColors[1]
		action.Active = not busy
	end

	-- ===== buying: confetti + flash =====
	local CONF = {"✦", "★", "●", "■", "✿"}
	local function celebrate(color)
		snd("Rare", 0.6, 1.15)
		snd("Coin", 0.6, 1)
		flashF.BackgroundTransparency = 0
		TweenService:Create(flashF, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
		for _ = 1, 40 do
			local sz = math.random(14, 30)
			local p = label(detail, {Text = CONF[math.random(#CONF)], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(272, 140),
				Size = UDim2.fromOffset(sz, sz), ZIndex = 12, Stroke = 0,
				TextColor3 = (math.random() < 0.5) and tint(color, 0.3) or ({C(255, 225, 90), C(120, 240, 255), C(255, 140, 200), WHITE})[math.random(4)]})
			local a = math.random() * math.pi * 2
			local d = math.random(120, 300)
			local tm = 0.7 + math.random() * 0.5
			TweenService:Create(p, TweenInfo.new(tm, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{Position = UDim2.fromOffset(272 + math.cos(a) * d, 140 + math.sin(a) * d * 0.7), Rotation = math.random(-300, 300), TextTransparency = 1}):Play()
			Debris:AddItem(p, tm + 0.1)
		end
	end

	UI.Button(action, function()
		if busy then return end
		local data = State.Data
		if not data then return end
		local t = selected
		if t.Id == (data.EquippedBase or "Starter") then return end
		local owned = (data.OwnedBases or {Starter = true})[t.Id]
		if (data.Rebirths or 0) < t.Rebirth then UI.Toast("🔒 Reach rebirth " .. t.Rebirth .. " to unlock " .. t.Name .. "!", "Error") return end
		if not owned and State.Cash() < t.Price then UI.Toast("💵 You need " .. Util.Money(t.Price - State.Cash()) .. " more!", "Error") return end
		busy = true
		refresh()
		local ok, res = pcall(State.Request, owned and "EquipBase" or "BuyBase", t.Id)
		res = ok and type(res) == "table" and res or {}
		busy = false
		refresh()
		if res.ok then
			if owned then snd("Pop", 0.6, 1.1) else celebrate(t.Color) end
		end
		if res.msg then UI.Toast(res.msg, res.ok and "Success" or "Error") end
	end)

	-- ===== animation: spinning base, rays, button glow =====
	RunService.RenderStepped:Connect(function(dt)
		if not win.Visible then return end
		local now = os.clock()
		rays.Rotation = (rays.Rotation + dt * 9) % 360
		angle = (angle + dt * 16) % 360
		if cam then
			local a = math.rad(angle)
			cam.CFrame = CFrame.lookAt(Vector3.new(math.cos(a) * R, 62, math.sin(a) * R), Vector3.new(0, 8, 0))
		end
		btnGlow.BackgroundTransparency = canAct and (0.55 + math.sin(now * 5) * 0.2) or 1
		btnGlow.Size = UDim2.fromOffset(536 + math.sin(now * 5) * 6, 74 + math.sin(now * 5) * 4)
	end)

	State.Changed:Connect(function() if win.Visible then refresh() end end)
	me:GetAttributeChangedSignal("Cash"):Connect(function() if win.Visible then refresh() end end)
	-- when opened: show the next base you can work towards (or your current one if you have them all)
	UI.OnOpen("Bases", function()
		local data = State.Data or {}
		local owned = data.OwnedBases or {Starter = true}
		local pick = Catalog.ById[data.EquippedBase or "Starter"] or Catalog.List[1]
		for _, t in ipairs(Catalog.List) do
			if not (owned[t.Id] or t.Id == "Starter") then pick = t break end
		end
		choose(pick, true)
		local i = table.find(Catalog.List, pick) or 1
		task.defer(function() list.CanvasPosition = Vector2.new(0, math.max(0, (i - 2) * 100)) end)
	end)
	PPS.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "BaseShopPrompt" then UI.Open("Bases")
		elseif prompt.Name == "BaseUpgradePrompt" then
			local plot = prompt.Parent
			while plot and plot.Parent ~= workspace.Plots do plot = plot.Parent end
			if plot and plot:GetAttribute("Owner") == me.UserId then UI.Open("Bases") else UI.Toast("Use the terminal in your own base.", "Error") end
		end
	end)
	choose(selected, true)
	UI.ApplyScale()
end
return M
