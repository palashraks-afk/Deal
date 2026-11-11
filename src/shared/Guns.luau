-- The 10 guns sold at the Gun Store. Models live in ServerStorage.Assets.Guns (AI-generated, textured).
-- damage = vs players, carDamage = vs cars. fireRate = seconds between shots.

local Guns = {
	{ id = "Pistol", name = "Viper 9", price = 0, damage = 18, carDamage = 6, fireRate = 0.22, mag = 15, reload = 1.4, spread = 1.2, range = 260, auto = false, color = Color3.fromRGB(176, 182, 190) },
	{ id = "Revolver", name = "Judge .44", price = 4000, damage = 42, carDamage = 14, fireRate = 0.55, mag = 6, reload = 2.2, spread = 0.6, range = 320, auto = false, color = Color3.fromRGB(176, 182, 190) },
	{ id = "MachinePistol", name = "Hornet MP", price = 9000, damage = 11, carDamage = 4, fireRate = 0.07, mag = 24, reload = 1.6, spread = 3.2, range = 200, auto = true, color = Color3.fromRGB(76, 214, 108) },
	{ id = "SMG", name = "Stinger SMG", price = 18000, damage = 14, carDamage = 5, fireRate = 0.08, mag = 32, reload = 1.8, spread = 2.4, range = 260, auto = true, color = Color3.fromRGB(76, 214, 108) },
	{ id = "Shotgun", name = "Breacher 12", price = 30000, damage = 11, carDamage = 5, pellets = 8, fireRate = 0.9, mag = 6, reload = 2.6, spread = 6, range = 120, auto = false, color = Color3.fromRGB(64, 156, 255) },
	{ id = "Rifle", name = "Ranger AR", price = 60000, damage = 22, carDamage = 8, fireRate = 0.1, mag = 30, reload = 2, spread = 1.4, range = 420, auto = true, color = Color3.fromRGB(64, 156, 255) },
	{ id = "Bullpup", name = "Bullhorn BP", price = 110000, damage = 26, carDamage = 10, fireRate = 0.09, mag = 30, reload = 2.1, spread = 1.1, range = 450, auto = true, color = Color3.fromRGB(178, 92, 255) },
	{ id = "Sniper", name = "Longshot", price = 200000, damage = 95, carDamage = 35, fireRate = 1.4, mag = 5, reload = 3, spread = 0.05, range = 900, auto = false, scope = true, color = Color3.fromRGB(178, 92, 255) },
	{ id = "LMG", name = "Thunder LMG", price = 400000, damage = 20, carDamage = 12, fireRate = 0.075, mag = 100, reload = 4, spread = 2.2, range = 420, auto = true, color = Color3.fromRGB(255, 64, 88) },
	{ id = "RPG", name = "Doomtube", price = 900000, damage = 110, carDamage = 120, fireRate = 2.5, mag = 1, reload = 3.2, spread = 0.3, range = 600, auto = false, explosive = 16, color = Color3.fromRGB(255, 196, 40) },
}

local byId = {}
for i, g in ipairs(Guns) do
	g.order = i
	byId[g.id] = g
end
Guns.ById = byId

return Guns
