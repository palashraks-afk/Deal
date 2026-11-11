# DrivinDealz — Game Plan

A Roblox car-dealership tycoon. You build up a dealership that sells cars for passive cash. The rare cars and the blueprints aren't sold anywhere: you have to drive into the city and find them. Other players can chase you down, shoot your car until it breaks, and take what you found. They can also raid your dealership.

---

## 1. Research: is anything like this already out there?

Short answer: **yes, every part of this exists in some game, but I haven't found one game with all of it together.** Nobody should call it "a game no one has made."

| Existing game | What it shares with DrivinDealz | What it doesn't have |
|---|---|---|
| **Car Dealership Tycoon** (Foxzie / Fozzie's Productions, one of the biggest car games on Roblox) | Dealership tycoon, real cars under altered names, car parts hidden around the map for a special car | No PvP theft, no rarity drops in the city, no blueprint crafting system |
| **Steal a Car** / **Rob a Car** | Tycoon where you raid other players' bases and steal their cars | No open city to hunt in, no driving chases, no crafting |
| **Build a Car** | Build a car from parts in Common / Uncommon / Rare / Epic tiers | Not a dealership, no city hunt |
| **My Toll Farm**, **Roll a Ride** | Rarity tiers up to Mythic | Cars come from rolls, not exploring |

**Where DrivinDealz stands out:** the loop of *drive into the city → find a rare car glowing in the street → drive it home while other players try to wreck it and take it.* That chase is the part the other games don't have. Lean on it in thumbnails, the description and the trailer.

**Legal note:** the cars are based on real cars with altered names ("Toyoda Supro", "Porsha 9-11"). That's the standard Roblox approach and Car Dealership Tycoon has done it for years, but it doesn't make you fully safe. Never use real logos and never use the real names in the title or ads.

---

## 2. Core loop

```
 Dealership earns cash ──► buy dealership upgrades + common cars for showroom
        ▲                                         │
        │                                         ▼
 sell / display rare cars ◄── drive to city, find rare cars + blueprint pieces
        ▲                                         │
        │                         other players hunt you (shoot car → steal)
        └──── craft custom cars from blueprints ◄─┘
```

1. **Tycoon (safe-ish):** each player gets a plot. Showroom slots hold cars. Each displayed car earns cash per second based on its value. NPC buyers walk in and buy cars, so slots turn over.
2. **City (dangerous):** rare cars and blueprint pieces spawn around the city on timers. They glow in their rarity colour and show on the minimap. Get in and drive it home to bank it.
3. **PvP:** players carry a "Disabler" blaster. Shooting a car lowers its health. At 0 the car is disabled, the driver gets ejected, and anyone can hotwire it (a 3-second hold).
4. **Raids:** you can walk into another player's dealership and hotwire a showroom car. Owners get an alert. Each base has a shield that drops for 2 minutes after the owner raids someone (so raiders can be raided back), plus a lock you can buy.
5. **Crafting:** blueprint pieces drop in the city. Collect a full set (body + engine + chassis + wheels) to craft a custom car in your own colour, with stats that come from the rarity of the pieces.

---

## 3. Rarity

Six tiers, lowest to highest. Spawn rates are tunable in `src/shared/Config.luau`.

| Tier | Colour | Cars in list | City spawn rate | Example |
|---|---|---|---|---|
| Common | Grey | ~300 | 55% | Hondo Civik |
| Uncommon | Green | ~250 | 25% | Fjord Mustank GT |
| Rare | Blue | ~200 | 12% | Porsha 9-11 Carrera |
| Epic | Purple | ~130 | 5.5% | Lamborgini Huracon |
| Mythic | Red | ~80 | 2% | Ferrano SF91 Stradala |
| Legendary | Gold | ~40 | 0.5% | Bugotti Chiron |

- Common and Uncommon cars can be **bought** in the dealership catalogue, unlocked by dealership level.
- Rare and above only come from the **city**, **stealing** or **crafting**.
- Rarity comes from the real car's price and how many were made, so the ladder feels right to car fans.

---

## 4. The 100-car list

- **100 cars** (30 Common, 25 Uncommon, 20 Rare, 13 Epic, 8 Mythic, 4 Legendary), hand-picked in `tools/top100.txt` with **short names** (20 characters max, e.g. "Toyoda Supro", "Bugotti Chyron").
- They're drawn from `tools/base_models.txt`, a library of 470 real cars with real length, width, height, horsepower and price. `python tools/gen_cars.py` writes `src/shared/CarData/` and `data/cars.csv`.
- Every brand name is altered (Toyota → Toyoda, Ferrari → Ferrano, BMW → BMV). The real car goes in a `basedOn` field for reference only and is never shown in game.

---

## 5. 3D models — what "accurate" means here

1. **Fallback (working now):** `CarBuilder.luau` builds any car from blocks at its **real length, width and height**. It's playable, but it looks basic.
2. **Real models (next):** every one of the 100 cars gets a textured 3D mesh from Roblox Studio's AI mesh generator (body + 4 separate wheels so they spin), scaled to the real car's dimensions. The first test supercar came out with proper curves, textures, rims and brake calipers. No real logos or badges.
3. **Blender pass:** cleanup and detail on the hero cars (Epic and up) once the Blender connection is live.

---

## 6. Systems and files

| System | File | Job |
|---|---|---|
| Config | `shared/Config.luau` | All the numbers: rates, prices, timers, damage |
| Car data | `shared/CarData.luau` | 1000 cars (generated) |
| Car builder | `shared/CarBuilder.luau` | Builds the 3D model from data |
| Data saving | `server/DataService.luau` | DataStore save/load, autosave, retry |
| Tycoon | `server/TycoonService.luau` | Plots, dealership levels, showroom slots, income, NPC buyers |
| Vehicles | `server/VehicleService.luau` | Spawn drivable cars, seats, network ownership |
| City spawns | `server/CityService.luau` | Rare car + blueprint spawns using the rarity weights |
| Combat | `server/CombatService.luau` | Disabler blaster, car health, eject, hotwire |
| Raids | `server/RaidService.luau` | Steal from bases, shields, locks, alerts |
| Crafting | `server/BlueprintService.luau` | Blueprint pieces → custom car |
| World | `server/WorldBuilder.luau` | Builds the city, roads, buildings, plots, lighting |
| Driving | `client/DriveController.luau` | Raycast-suspension driving (smooth, stable) |
| HUD | `client/HUD.luau` | Cash, speedometer, car health, alerts |
| Minimap | `client/Minimap.luau` | Top-down map with you, players and rare-car blips |
| Inventory | `client/InventoryUI.luau` | Garage: spawn / display / sell cars |
| Dealership UI | `client/DealershipUI.luau` | Upgrades + catalogue |
| Crafting UI | `client/CraftUI.luau` | Blueprint crafting |

Security: the server decides everything (cash, ownership, hits, steals). The client only sends requests, and the server checks distance, cooldowns and ownership.

---

## 7. Dealership progression

| Level | Name | Showroom slots | Unlocks | Cost |
|---|---|---|---|---|
| 1 | Used Lot | 3 | Common catalogue | free |
| 2 | Corner Dealer | 5 | Uncommon catalogue | $25k |
| 3 | City Showroom | 8 | Garage size +10, base lock | $150k |
| 4 | Luxury Motors | 12 | NPC buyers pay +25% | $750k |
| 5 | Supercar Gallery | 16 | Blueprint crafting bench | $3M |
| 6 | Hypercar Palace | 20 | Legendary display pedestal (x2 income) | $15M |

---

## 8. Graphics

- `Future` lighting, Atmosphere, Bloom, Sun rays, ColorCorrection, a slow day/night cycle.
- City at night: street lights and emissive windows. Rare cars carry a rarity-coloured light + beam that can be seen from far away.
- Glass and SmoothPlastic/Metal materials on cars, Asphalt/Concrete for the city.

---

## 9. Build order (each step pushed to GitHub)

1. Plan + research (this file)
2. 1000-car list + generator
3. Project setup (Rojo) + Config + DataService
4. World builder (city + plots + lighting)
5. Car builder + driving
6. Tycoon + dealership progression
7. City spawns + rarity
8. Combat + hotwire + raids
9. Blueprints + crafting
10. UI: HUD, minimap, inventory, dealership, crafting
11. Playtest in Studio, tune numbers

## 10. Later (after launch)

- Real meshes for the top 120 cars
- Gamepasses: VIP (x2 income), extra garage, radio
- Police NPCs, races, trading, daily rewards, leaderboards
