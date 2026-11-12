--!strict
-- Kleine UI-Bibliothek: Alle Oberflächen werden im Code gebaut, damit sie
-- im Git-Repository versioniert sind. Funktioniert mit Maus, Touch und Gamepad.

local Kit = {}

Kit.Theme = {
	Bg = Color3.fromRGB(24, 20, 32),
	Panel = Color3.fromRGB(34, 28, 46),
	Panel2 = Color3.fromRGB(48, 40, 62),
	Border = Color3.fromRGB(122, 98, 54),
	Gold = Color3.fromRGB(230, 192, 106),
	Text = Color3.fromRGB(244, 234, 210),
	Muted = Color3.fromRGB(184, 169, 140),
	Hp = Color3.fromRGB(216, 58, 58),
	Xp = Color3.fromRGB(154, 106, 255),
	Bond = Color3.fromRGB(255, 120, 170),
	Good = Color3.fromRGB(95, 211, 106),
	Bad = Color3.fromRGB(255, 106, 90),
	Button = Color3.fromRGB(70, 56, 92),
	ButtonHi = Color3.fromRGB(110, 84, 150),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	Title = Enum.Font.Cartoon,
}

local T = Kit.Theme

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Kit.stroke(color: Color3?, thickness: number?): UIStroke
	return Kit.new("UIStroke", { Color = color or T.Border, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function Kit.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Kit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Kit.list(dir: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Kit.label(text: string, size: number?, props: { [string]: any }?): TextLabel
	local l = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = T.Text,
		Font = T.Font,
		TextSize = size or 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		RichText = true,
	})
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	return l
end

function Kit.button(text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local b = Kit.new("TextButton", {
		Text = text,
		TextColor3 = T.Text,
		Font = T.FontBold,
		TextSize = 16,
		BackgroundColor3 = T.Button,
		AutoButtonColor = true,
		Size = UDim2.new(0, 120, 0, 36),
	}, { Kit.corner(8), Kit.stroke(T.Border, 1) })
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	b.Activated:Connect(onClick)
	return b
end

-- Fortschrittsbalken; gibt Rahmen und Setter zurück
function Kit.bar(color: Color3, height: number?): (Frame, (number, string?) -> ())
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 16, 26),
		Size = UDim2.new(1, 0, 0, height or 14),
	}, { Kit.corner(6) })
	local fill = Kit.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), Parent = frame }, { Kit.corner(6) })
	local text = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = T.Text,
		Font = T.FontBold,
		TextSize = math.max(10, (height or 14) - 3),
		ZIndex = 3,
		Parent = frame,
	})
	local function set(ratio: number, label: string?)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		text.Text = label or ""
	end
	return frame, set
end

-- Fenster mit Titel, Schließen-Knopf und scrollbarem Inhalt
function Kit.window(parent: Instance, title: string, onClose: () -> ()): (Frame, ScrollingFrame, Frame)
	local win = Kit.new("Frame", {
		Name = "Window_" .. title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = T.Panel,
		Visible = false,
		Parent = parent,
	}, { Kit.corner(14), Kit.stroke(T.Border, 2), Kit.new("UISizeConstraint", { MaxSize = Vector2.new(820, 640) }) })
	local header = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = win })
	Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = title,
		TextColor3 = T.Gold,
		Font = T.Title,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	Kit.button("✕", onClose, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(120, 50, 50),
		Parent = header,
	})
	-- Leiste für Reiter (Tabs)
	local tabs = Kit.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = win,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local content = Kit.new("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 92),
		Size = UDim2.new(1, -24, 1, -104),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = win,
	}, { Kit.list(Enum.FillDirection.Vertical, 8) })
	return win, content, tabs
end

-- Karte (Zeile) in Listen
function Kit.card(height: number?): Frame
	return Kit.new("Frame", {
		BackgroundColor3 = T.Panel2,
		Size = UDim2.new(1, -8, 0, height or 0),
		AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
	}, { Kit.corner(10), Kit.padding(10) })
end

function Kit.clear(container: Instance)
	for _, c in container:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

return Kit
