-- Run in Studio (edit mode): files every finished AI car generation in Workspace into
-- ServerStorage.Assets.Cars as Car_<id>, matched by the real car name in its prompt.
local IDS = {
	["Chevrolet Spark"] = 1,
	["Fiat 500"] = 2,
	["Nissan Sentra"] = 3,
	["Kia Soul"] = 4,
	["Kia Forte"] = 5,
	["Hyundai Elantra"] = 6,
	["Volkswagen Jetta"] = 7,
	["Toyota Corolla"] = 8,
	["Ford Fusion"] = 9,
	["Subaru Impreza"] = 10,
	["Honda Civic"] = 11,
	["Mazda Mazda3"] = 12,
	["Chevrolet Malibu"] = 13,
	["Volkswagen Beetle 1967"] = 14,
	["Ford Model T"] = 15,
	["Nissan Altima"] = 16,
	["Volkswagen Golf"] = 17,
	["Dodge Grand Caravan"] = 18,
	["Toyota Camry"] = 19,
	["Toyota Prius"] = 20,
	["Honda Accord"] = 21,
	["Chevrolet Equinox"] = 22,
	["Jeep Compass"] = 23,
	["Hyundai Tucson"] = 24,
	["Ford Escape"] = 25,
	["Honda CR-V"] = 26,
	["Subaru Outback"] = 27,
	["Mini Cooper S"] = 28,
	["Ford Ranger"] = 29,
	["Tesla Model 3"] = 30,
	["Nissan 240SX (S13)"] = 31,
	["Toyota GR86"] = 32,
	["Mazda MX-5 Miata"] = 33,
	["Nissan 370Z"] = 34,
	["Volkswagen Golf GTI"] = 35,
	["Toyota Tacoma"] = 36,
	["Subaru WRX"] = 37,
	["Jeep Wrangler"] = 38,
	["Dodge Challenger R/T"] = 39,
	["Toyota 4Runner"] = 40,
	["Ram 1500"] = 41,
	["Audi A4"] = 42,
	["Chevrolet Camaro SS"] = 43,
	["Honda Civic Type R"] = 44,
	["Ford Mustang GT"] = 45,
	["Ford F-150"] = 46,
	["Ford Bronco"] = 47,
	["Chevrolet Silverado"] = 48,
	["Tesla Model Y"] = 49,
	["BMW 330i"] = 50,
	["Hyundai Ioniq 5"] = 51,
	["Lexus IS 350"] = 52,
	["Mercedes-Benz C-Class C300"] = 53,
	["Mitsubishi Lancer Evolution IX"] = 54,
	["Chevrolet Tahoe"] = 55,
	["Toyota Supra A90"] = 56,
	["BMW M3 E46"] = 57,
	["Lotus Elise"] = 58,
	["Toyota Land Cruiser"] = 59,
	["Chevrolet Corvette C8 Stingray"] = 60,
	["Mazda RX-7 FD"] = 61,
	["Dodge Charger SRT Hellcat"] = 62,
	["Ford F-150 Raptor"] = 63,
	["Ford Mustang Shelby GT500"] = 64,
	["Alfa Romeo Giulia Quadrifoglio"] = 65,
	["Mercedes-Benz AMG C63 S"] = 66,
	["Tesla Model S Plaid"] = 67,
	["Tesla Cybertruck"] = 68,
	["Nissan GT-R R35"] = 69,
	["Porsche 911 Carrera"] = 70,
	["Toyota Supra Mk4"] = 71,
	["Audi RS6 Avant"] = 72,
	["BMW M4 CSL"] = 73,
	["Honda NSX (2nd gen)"] = 74,
	["Nissan Skyline GT-R R34"] = 75,
	["Audi R8 V10"] = 76,
	["Mercedes-Benz AMG G63"] = 77,
	["Nissan GT-R Nismo"] = 78,
	["Porsche 911 GT3 RS"] = 79,
	["Lamborghini Urus"] = 80,
	["Maserati MC20"] = 81,
	["Aston Martin DB12"] = 82,
	["Dodge Viper ACR"] = 83,
	["Lamborghini Huracan EVO"] = 84,
	["Ferrari F8 Tributo"] = 85,
	["McLaren 720S"] = 86,
	["Bentley Continental GT"] = 87,
	["Rolls-Royce Cullinan"] = 88,
	["Ferrari SF90 Stradale"] = 89,
	["Lamborghini Aventador SVJ"] = 90,
	["Lexus LFA"] = 91,
	["McLaren P1"] = 92,
	["Lamborghini Countach LP400"] = 93,
	["Porsche 918 Spyder"] = 94,
	["Ferrari F40"] = 95,
	["Ferrari LaFerrari"] = 96,
	["Koenigsegg Jesko"] = 97,
	["Pagani Huayra"] = 98,
	["Bugatti Chiron"] = 99,
	["McLaren F1"] = 100
}
local SS = game:GetService("ServerStorage")
local assets = SS:FindFirstChild("Assets") or Instance.new("Folder", SS)
assets.Name = "Assets"
local cars = assets:FindFirstChild("Cars") or Instance.new("Folder", assets)
cars.Name = "Cars"
local moved = {}
for _, m in workspace:GetChildren() do
	if m:IsA("Model") and m.Name:find("model of a ", 1, true) then
		local real = m.Name:match("model of a (.-) %(")
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
	table.insert(have, tonumber(m.Name:match("%d+")))
end
table.sort(have)
return "moved: " .. table.concat(moved, ",") .. " | in storage (" .. #have .. "): " .. table.concat(have, ",")
