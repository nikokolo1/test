-- StarterPack: the one-time STARTER PACK offer (dev product, see Config.Products.StarterPack)
-- * a shiny tile next to ADD FRIENDS (bottom left) that opens the offer window
-- * the offer window: big pack art + 6 item bricks (painted icons) + a glowing BUY button
-- * pops up once per session for players who don't have it yet; everything hides after buying
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(RS.Shared.Config)
local UIKit = require(RS.Shared.UIKit)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local okMS, MS = pcall(require, script.Parent.MapStyle)
local okSnd, Sound = pcall(require, script.Parent.Sound)
local okArt, ItemArt = pcall(require, RS.Shared.ItemArt)

local M = {}
local KEY = "StarterPack"
local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local DARK = C(30, 34, 60)
local NAVY2 = C(18, 24, 66)
local FONT = Enum.Font.FredokaOne

-- what's inside (Art = ItemArt picture id, Emoji = fallback)
local ITEMS = {
	{Art = "MutationDice", Emoji = "🧬", Count = 3, Name = "MUTATION DICE", Sub = "x5 mutations • 1 roll", Color = C(235, 70, 200)},
	{Art = "SpeedDice", Emoji = "⚡", Count = 5, Name = "SPEED DICE", Sub = "50% faster rolls • 10 min", Color = C(240, 70, 70)},
	{Art = "LuckyDice", Emoji = "🍀", Count = 10, Name = "100x LUCK DICE", Sub = "x100 luck • 1 roll", Color = C(255, 185, 40)},
	{Art = "SuperLuckyDice", Emoji = "🌟", Count = 3, Name = "1000x LUCK DICE", Sub = "x1000 luck • 1 roll", Color = C(160, 80, 240)},
	{Art = "Luck2", Emoji = "✨", Count = 3, Name = "SUPER LUCK POTION", Sub = "x5 luck • 3 min", Color = C(70, 150, 255)},
	{Art = "Luck1", Emoji = "🍀", Count = 10, Name = "LUCK POTION", Sub = "x2 luck • 5 min", Color = C(60, 200, 90)},
}

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
local function grad(o, a, b, rot)
	return new("UIGradient", {Color = typeof(a) == "ColorSequence" and a or ColorSequence.new(a, b or a), Rotation = rot or 90}, o)
end
local function label(parent, props)
	local l = new("TextLabel", {BackgroundTransparency = 1, Font = FONT, TextColor3 = WHITE, TextScaled = true, Text = ""}, parent)
	for k, v in pairs(props) do if k ~= "Stroke" then l[k] = v end end
	if props.Stroke ~= 0 then stroke(l, props.Stroke or 2.5, NAVY2, true) end
	return l
end
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C(255, 90, 90)), ColorSequenceKeypoint.new(0.2, C(255, 200, 60)), ColorSequenceKeypoint.new(0.4, C(110, 240, 120)),
	ColorSequenceKeypoint.new(0.6, C(80, 200, 255)), ColorSequenceKeypoint.new(0.8, C(190, 110, 255)), ColorSequenceKeypoint.new(1, C(255, 110, 200)),
})

local function owned()
	local d = State.Data
	return d and type(d.Bought) == "table" and d.Bought[KEY] == true
end

function M.Init()
	local def = Config.Products[KEY]
	if not def or not def.Id or def.Id == 0 then return end
	local me = Players.LocalPlayer
	local price = def.Price
	local image = def.Image

	-- ===================== the offer window =====================
	local W, H = 860, 560
	local win = new("Frame", {Name = "StarterPack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = C(240, 243, 252), Visible = false, BorderSizePixel = 0}, UI.Windows)
	corner(win, 24)
	stroke(win, 5, DARK)
	new("UIScale", {Name = "AutoScale", Scale = 1}, win)

	local header = new("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1}, win)
	corner(header, 24)
	local HC1, HC2 = C(255, 225, 90), C(255, 135, 30)
	grad(header, HC1, HC2)
	new("Frame", {Name = "Fill", Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = HC2, BorderSizePixel = 0, ZIndex = 1}, header)
	new("Frame", {Name = "Line", Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = DARK, BorderSizePixel = 0, ZIndex = 3}, header)
	label(header, {Name = "Title", Text = "🎁 STARTER PACK", Position = UDim2.fromOffset(22, 11), Size = UDim2.fromOffset(380, 48),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Stroke = 4})
	-- "ONE-TIME OFFER" ribbon
	local ribbon = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -84, 0.5, 0), Size = UDim2.fromOffset(210, 38), BackgroundColor3 = WHITE,
		BorderSizePixel = 0, ZIndex = 4}, header)
	corner(ribbon, UDim.new(1, 0))
	stroke(ribbon, 3, DARK)
	local ribbonGrad = grad(ribbon, RAINBOW, nil, 0)
	label(ribbon, {Text = "⭐ ONE-TIME OFFER", Size = UDim2.new(1, -16, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Stroke = 2.5})
	local close = UIKit.button({Name = "Close", Colors = UIKit.C.Red, Text = "X", Size = UDim2.fromOffset(56, 56), Position = UDim2.new(1, -66, 0, 8),
		Radius = 16, ZIndex = 4, Parent = win, TextHeight = 0.7})
	UI.Button(close, function() UI.Close("StarterPack") end)
	if okMS then pcall(MS.Window, win) end

	-- left: the pack art on spinning rays
	local artBox = new("Frame", {Name = "Art", Position = UDim2.fromOffset(18, 92), Size = UDim2.fromOffset(350, 446), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2}, win)
	corner(artBox, 18)
	stroke(artBox, 3, DARK)
	grad(artBox, C(120, 70, 220), C(30, 20, 80))
	local rayClip = new("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2}, artBox)
	corner(rayClip, 18)
	local rays = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 2}, rayClip)
	for k = 1, 12 do
		local s = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(k % 2 == 0 and 70 or 30, 1000), Rotation = k * 15,
			BackgroundColor3 = C(255, 230, 140), BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 2}, rays)
		new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1)})}, s)
	end
	local pic = new("ImageLabel", {Name = "Pack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(310, 310),
		BackgroundTransparency = 1, Image = image or "", ScaleType = Enum.ScaleType.Fit, ZIndex = 4}, artBox)
	corner(pic, 16)
	local picScale = new("UIScale", {Scale = 1}, pic)
	if not image then
		label(pic, {Text = "🎁", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Stroke = 0})
	end
	local valueTag = label(artBox, {Text = "🎲 21 DICE + 13 POTIONS", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(320, 30), ZIndex = 5, Stroke = 3})
	grad(valueTag, C(255, 250, 200), C(255, 200, 60))
	label(artBox, {Text = "Everything you need for an INSANE start!", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(320, 22),
		TextColor3 = C(230, 225, 255), ZIndex = 5, Stroke = 2})

	-- right: 6 item bricks
	local grid = new("Frame", {Name = "Items", Position = UDim2.fromOffset(386, 96), Size = UDim2.fromOffset(456, 330), BackgroundTransparency = 1, ZIndex = 2}, win)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(222, 100), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	local tiles = {}
	for i, it in ipairs(ITEMS) do
		local t = new("Frame", {Name = it.Art, LayoutOrder = i, BackgroundColor3 = it.Color, BorderSizePixel = 0, ZIndex = 3}, grid)
		corner(t, 14)
		stroke(t, 3, DARK)
		local holder = new("Frame", {Name = "Icon", Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, ZIndex = 4}, t)
		local fallback = label(holder, {Text = it.Emoji, Size = UDim2.fromScale(0.85, 0.85), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Stroke = 0})
		local cnt = label(t, {Text = "x" .. it.Count, Position = UDim2.fromOffset(86, 8), Size = UDim2.fromOffset(126, 40), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Stroke = 3.5})
		grad(cnt, WHITE, C(255, 240, 170))
		label(t, {Text = it.Name, Position = UDim2.fromOffset(86, 48), Size = UDim2.fromOffset(128, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Stroke = 2.2})
		label(t, {Text = it.Sub, Position = UDim2.fromOffset(86, 71), Size = UDim2.fromOffset(128, 16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(235, 238, 255), ZIndex = 5, Stroke = 1.6})
		if okMS then pcall(MS.Brick, t, it.Color, {w = 222, h = 100, studSize = Vector2.new(26, 12), lip = 8, cell = 14, radius = 14}) end
		tiles[i] = {tile = t, holder = holder, fallback = fallback, art = it.Art}
	end
	local painted = false
	local function paintIcons()
		if painted or not okArt then return end
		painted = true
		for _, tl in ipairs(tiles) do
			if ItemArt.Has(tl.art) then
				local okA, art = pcall(ItemArt.Apply, tl.holder, tl.art, {tl.fallback})
				if okA and art then
					art.ZIndex = math.max(art.ZIndex, 6)
				end
			end
		end
	end

	-- buy button
	local btnGlow = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(614, 488), Size = UDim2.fromOffset(470, 82), BackgroundColor3 = C(120, 255, 140),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, win)
	corner(btnGlow, 22)
	local buy = UIKit.button({Name = "Buy", Colors = UIKit.C.Green, Text = "", Size = UDim2.fromOffset(456, 70), Position = UDim2.fromOffset(386, 453),
		Radius = 18, ZIndex = 3, Parent = win, TextHeight = 0.58})

	local function refresh()
		local have = owned()
		if have then
			UI.SetButtonText(buy, "✅ OWNED - THANK YOU!")
			UI.SetButtonColors(buy, UIKit.C.Gray)
		else
			UI.SetButtonText(buy, "🛒 BUY NOW  •  R$ " .. tostring(price))
			UI.SetButtonColors(buy, UIKit.C.Green)
		end
	end
	UI.Button(buy, function()
		if owned() then UI.Toast("✅ You already have the Starter Pack!", "Info") return end
		MarketplaceService:PromptProductPurchase(me, def.Id)
	end)

	-- ===================== the HUD tile (next to ADD FRIENDS) =====================
	local tile
	local hud = UI.HUD
	local holder = hud and hud:FindFirstChild("AddFriendsHolder")
	if holder then
		tile = new("TextButton", {Name = "StarterPackButton", Position = UDim2.new(1, 12, 0, 0), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
			AutoButtonColor = false, ZIndex = 1}, holder)
		local lip = new("Frame", {Name = "Lip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(150, 70, 10), BorderSizePixel = 0, ZIndex = 1}, tile)
		corner(lip, 14)
		stroke(lip, 3, C(28, 20, 48))
		local face = new("Frame", {Name = "Face", Size = UDim2.new(1, 0, 1, -6), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, ClipsDescendants = false}, tile)
		corner(face, 14)
		grad(face, C(255, 230, 100), C(255, 140, 30))
		local img = new("ImageLabel", {Name = "Pack", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(74, 74),
			BackgroundTransparency = 1, Image = image or "", ScaleType = Enum.ScaleType.Fit, ZIndex = 4}, face)
		corner(img, 10)
		if not image then label(img, {Text = "🎁", Size = UDim2.fromScale(1, 1), ZIndex = 5, Stroke = 0}) end
		local imgScale = new("UIScale", {Scale = 1}, img)
		local gloss = new("Frame", {Name = "Gloss", Position = UDim2.fromOffset(5, 4), Size = UDim2.new(1, -10, 0.42, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.7,
			BorderSizePixel = 0, ZIndex = 3}, face)
		corner(gloss, 10)
		label(face, {Name = "Title", Text = "STARTER PACK", Position = UDim2.new(0, 4, 0, 78), Size = UDim2.new(1, -8, 0, 18), ZIndex = 6, Stroke = 2.5})
		local sub = label(face, {Name = "Sub", Text = "R$ " .. tostring(price), Position = UDim2.new(0, 10, 0, 94), Size = UDim2.new(1, -20, 0, 14), ZIndex = 6, Stroke = 2})
		sub.TextColor3 = C(180, 255, 180)
		-- "!" badge
		local badge = new("Frame", {Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = C(235, 50, 60), BorderSizePixel = 0, ZIndex = 8}, tile)
		corner(badge, UDim.new(1, 0))
		stroke(badge, 2.5, WHITE)
		label(badge, {Text = "!", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9, Stroke = 1.5})
		local tileScale = new("UIScale", {Name = "Pulse", Scale = 1}, tile)
		tile.MouseEnter:Connect(function() TweenService:Create(tileScale, TweenInfo.new(0.12), {Scale = 1.08}):Play() end)
		tile.MouseLeave:Connect(function() TweenService:Create(tileScale, TweenInfo.new(0.12), {Scale = 1}):Play() end)
		tile.Activated:Connect(function()
			snd("UITap", 0.4, 1.2)
			UI.Open("StarterPack")
		end)
		-- the tile wobbles a little every few seconds so it gets noticed
		task.spawn(function()
			while tile.Parent do
				task.wait(4)
				if tile.Visible then
					for _, r in ipairs({8, -8, 5, -5, 0}) do
						TweenService:Create(img, TweenInfo.new(0.08), {Rotation = r}):Play()
						task.wait(0.08)
					end
				end
			end
		end)
		RunService.RenderStepped:Connect(function()
			if tile.Visible then imgScale.Scale = 1 + math.sin(os.clock() * 3) * 0.04 end
		end)
	end

	local function applyOwned()
		local have = owned()
		if tile then tile.Visible = not have end
		refresh()
		return have
	end

	-- window animation
	RunService.RenderStepped:Connect(function(dt)
		if not win.Visible then return end
		local t = os.clock()
		rays.Rotation = (rays.Rotation + dt * 12) % 360
		picScale.Scale = 1 + math.sin(t * 2.2) * 0.03
		pic.Rotation = math.sin(t * 1.4) * 2
		ribbonGrad.Offset = Vector2.new(math.sin(t * 1.5) * 0.4, 0)
		local can = not owned()
		btnGlow.BackgroundTransparency = can and (0.55 + math.sin(t * 5) * 0.2) or 1
		btnGlow.Size = UDim2.fromOffset(470 + math.sin(t * 5) * 8, 82 + math.sin(t * 5) * 5)
	end)

	UI.OnOpen("StarterPack", function()
		paintIcons()
		refresh()
	end)
	State.Changed:Connect(function() applyOwned() end)

	-- real price from Roblox
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(def.Id, Enum.InfoType.Product) end)
		if ok and info then
			if info.PriceInRobux then price = info.PriceInRobux end
			if not image and info.IconImageAssetId and info.IconImageAssetId ~= 0 then
				image = "rbxassetid://" .. info.IconImageAssetId
				pic.Image = image
			end
			if tile then
				local s = tile:FindFirstChild("Sub", true)
				if s then s.Text = "R$ " .. tostring(price) end
			end
			refresh()
		end
	end)

	-- purchase finished -> celebrate (the items arrive through ProcessReceipt on the server)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if userId ~= me.UserId or productId ~= def.Id or not purchased then return end
		snd("Legendary", 0.6, 1.1)
		task.delay(1.5, function()
			if UI.IsOpen("StarterPack") then UI.Close("StarterPack") end
		end)
	end)

	-- show the offer once per session to players who don't have it yet (after they had a moment to look around)
	task.spawn(function()
		local t0 = os.clock()
		while not State.Data and os.clock() - t0 < 30 do task.wait(0.5) end
		if applyOwned() then return end
		task.wait(25)
		for _ = 1, 60 do
			if owned() then return end
			local cut = UI.Overlay and UI.Overlay:FindFirstChild("Cutscene")
			if not UI.Current and not (cut and cut.Visible) then
				UI.Open("StarterPack")
				return
			end
			task.wait(5)
		end
	end)
	applyOwned()
	UI.ApplyScale()
end

return M
