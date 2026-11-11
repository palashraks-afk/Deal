-- Paste into Studio's command bar (or run through the Studio MCP) to pull src/ from
-- `python tools/make_manifest.py` + `python -m http.server 34999 --directory build`.
local HttpService = game:GetService("HttpService")
local manifest = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:34999/manifest.json"))

local function resolve(path)
	local inst = game
	for name in string.gmatch(path, "[^%.]+") do
		inst = inst:FindFirstChild(name) or game:GetService(name)
	end
	return inst
end

local function build(node, parent)
	local inst = Instance.new(node.class)
	inst.Name = node.name
	if node.source then
		inst.Source = node.source
	end
	for _, child in node.children do
		build(child, inst)
	end
	inst.Parent = parent
	return inst
end

for _, entry in manifest do
	local parent = resolve(entry.parent)
	local old = parent:FindFirstChild(entry.node.name)
	if old then
		old:Destroy()
	end
	build(entry.node, parent)
end
return "synced " .. #manifest .. " roots"
