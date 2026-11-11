"""Write tools/collect_cars.luau (and a copy in build/) - a Studio edit-mode script that files
finished AI car generations in Workspace into ServerStorage.Assets.Cars as Car_<id>."""
import csv
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = list(csv.DictReader(open(os.path.join(ROOT, "data", "cars.csv"), encoding="utf-8")))
pairs = ",\n".join('\t["%s"] = %s' % (r["basedOn"].replace('"', '\\"'), r["id"]) for r in rows)

SRC = """-- Run in Studio (edit mode): files every finished AI car generation in Workspace into
-- ServerStorage.Assets.Cars as Car_<id>, matched by the real car name in its prompt.
local IDS = {
%s
}
local SS = game:GetService("ServerStorage")
local assets = SS:FindFirstChild("Assets") or Instance.new("Folder", SS)
assets.Name = "Assets"
local cars = assets:FindFirstChild("Cars") or Instance.new("Folder", assets)
cars.Name = "Cars"
local moved = {}
for _, m in workspace:GetChildren() do
	if m:IsA("Model") and m.Name:find("model of a ", 1, true) then
		local real = m.Name:match("model of a (.-) %%(")
		local id = real and IDS[real]
		if id then
			local old = cars:FindFirstChild("Car_" .. id)
			if old then
				old:Destroy()
			end
			m.Name = "Car_" .. id
			m.Parent = cars
			table.insert(moved, id)
		end
	end
end
for _, m in cars:GetChildren() do
	for _, d in m:GetDescendants() do
		if d:IsA("MeshPart") then
			d.CollisionFidelity = Enum.CollisionFidelity.Box
		end
	end
end
local have = {}
for _, m in cars:GetChildren() do
	table.insert(have, tonumber(m.Name:match("%%d+")))
end
table.sort(have)
return "moved: " .. table.concat(moved, ",") .. " | in storage (" .. #have .. "): " .. table.concat(have, ",")
""" % pairs

out = os.path.join(ROOT, "tools", "collect_cars.luau")
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(SRC)
os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
shutil.copy(out, os.path.join(ROOT, "build", "collect_cars.luau"))
print("ok", len(rows))
