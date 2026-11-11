-- Sound effects (free Roblox Creator Store audio). Swap any id here to change a sound.
local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.Ids = {
	Pistol = "rbxassetid://90432171903658",
	Revolver = "rbxassetid://3102797479",
	Rifle = "rbxassetid://113450029049580",
	Sniper = "rbxassetid://6975483207",
	Shotgun = "rbxassetid://132255180302885",
	Explosion = "rbxassetid://138533090376585",
	Reload = "rbxassetid://117963160131194",
	Impact = "rbxassetid://98609496290942",
	Click = "rbxassetid://88442833509532",
	Cash = "rbxassetid://101396758527961",
	Build = "rbxassetid://7381723941",
	Engine = "rbxassetid://80317022777602",
	Skid = "rbxassetid://109487442763183",
	CityAmbience = "rbxassetid://9112867198",
	Traffic = "rbxassetid://9112784190",
}

-- which shot sound each gun uses (+ pitch so they don't all sound the same)
Sounds.Gun = {
	Pistol = { "Pistol", 1.05 },
	Revolver = { "Revolver", 0.95 },
	MachinePistol = { "Pistol", 1.25 },
	SMG = { "Rifle", 1.3 },
	Shotgun = { "Shotgun", 1 },
	Rifle = { "Rifle", 1 },
	Bullpup = { "Rifle", 1.1 },
	Sniper = { "Sniper", 1 },
	LMG = { "Rifle", 0.85 },
	RPG = { "Explosion", 1.4 },
}

local cache = {}
local function template(name: string): Sound
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = Sounds.Ids[name]
		s.Name = name
		cache[name] = s
	end
	return s
end

-- Play a one-shot. If `at` is a BasePart/Attachment/Vector3 the sound is 3D, otherwise it's UI (2D).
function Sounds.play(name: string, at, volume: number?, pitch: number?)
	if not Sounds.Ids[name] then
		return
	end
	local s = template(name):Clone()
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	if typeof(at) == "Vector3" then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = workspace.Terrain
		s.RollOffMaxDistance = 400
		s.RollOffMinDistance = 12
		s.Parent = a
		s.Ended:Connect(function()
			a:Destroy()
		end)
		task.delay(8, function()
			if a.Parent then
				a:Destroy()
			end
		end)
	elseif typeof(at) == "Instance" then
		s.RollOffMaxDistance = 400
		s.RollOffMinDistance = 12
		s.Parent = at
		s.Ended:Connect(function()
			s:Destroy()
		end)
	else
		s.Parent = SoundService
		s.Ended:Connect(function()
			s:Destroy()
		end)
	end
	s:Play()
	return s
end

-- A looping sound attached to something (engine, skid, ambience).
function Sounds.loop(name: string, parent: Instance, volume: number?): Sound
	local s = template(name):Clone()
	s.Looped = true
	s.Volume = volume or 0.5
	s.RollOffMaxDistance = 300
	s.RollOffMinDistance = 10
	s.Parent = parent
	s:Play()
	return s
end

return Sounds
