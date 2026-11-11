"""Generate the 1000-car list for DrivinDealz.

Reads tools/base_models.txt (real base models with real dimensions), expands
them with trims/generations to exactly 1000 cars, assigns rarity by value rank,
and writes:
  src/shared/CarData/Chunk1..4.luau   (game data, split to keep scripts small)
  data/cars.csv                       (human-readable copy)

Run:  python tools/gen_cars.py
"""
import csv
import hashlib
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = 1000

# Cars per rarity (lowest -> highest). Must sum to TARGET.
TIER_COUNTS = [
    ("Common", 300),
    ("Uncommon", 250),
    ("Rare", 200),
    ("Epic", 130),
    ("Mythic", 80),
    ("Legendary", 40),
]

# Trims per body type: (suffix, value multiplier, hp multiplier)
TRIMS = {
    "hatch": [("Sport", 1.18, 1.15), ("Turbo", 1.35, 1.35), ("Limited", 1.25, 1.05), ("Rally Spec", 1.6, 1.5)],
    "sedan": [("Sport", 1.18, 1.15), ("Limited", 1.25, 1.05), ("Turbo", 1.35, 1.35), ("Hybrid", 1.12, 1.0)],
    "wagon": [("Sport", 1.2, 1.15), ("Touring", 1.15, 1.0), ("Turbo", 1.35, 1.3)],
    "coupe": [("GT", 1.3, 1.2), ("Turbo", 1.4, 1.35), ("Widebody", 1.6, 1.3), ("Drift Spec", 1.25, 1.2)],
    "suv": [("Sport", 1.2, 1.15), ("Limited", 1.3, 1.05), ("Off-Road", 1.25, 1.05), ("Hybrid", 1.12, 1.0)],
    "truck": [("Off-Road", 1.25, 1.05), ("Lifted", 1.35, 1.0), ("Sport", 1.2, 1.15), ("Limited", 1.3, 1.05)],
    "offroad": [("Trail", 1.2, 1.0), ("Lifted", 1.35, 1.0), ("Expedition", 1.3, 1.05)],
    "van": [("Camper", 1.4, 1.0), ("Sport", 1.15, 1.15), ("Limited", 1.25, 1.0)],
    "muscle": [("Widebody", 1.5, 1.2), ("Drag Spec", 1.6, 1.4), ("Classic Edition", 1.3, 1.0)],
    "sports": [("Track Edition", 1.4, 1.2), ("Turbo", 1.35, 1.3), ("Widebody", 1.55, 1.25), ("Drift Spec", 1.3, 1.2)],
    "super": [("Track Edition", 1.45, 1.15), ("Carbon Edition", 1.35, 1.05), ("Spyder", 1.2, 1.0)],
    "hyper": [],  # hypercars stay one-of-a-kind
    "classic": [("Restomod", 1.4, 1.6), ("Concours", 1.5, 1.0), ("Barn Find", 0.6, 0.8)],
}
UNIQUE_VALUE = 1_500_000  # anything worth more than this never gets trims

BODY_SPEED = {"truck": 0.88, "van": 0.82, "offroad": 0.85, "suv": 0.93, "hyper": 1.04, "classic": 0.95}

PAINTS = [
    "Crimson", "Midnight Blue", "Pearl White", "Gunmetal", "Racing Green", "Sunset Orange",
    "Lime", "Jet Black", "Silver", "Canary Yellow", "Royal Purple", "Sky Blue", "Burgundy",
    "Bronze", "Matte Grey", "Hot Pink", "Teal",
]


def parse_base():
    cars = []
    brand_real = brand_game = None
    with open(os.path.join(ROOT, "tools", "base_models.txt"), encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("@"):
                brand_real, brand_game = line[1:].split("=")
                continue
            model, real_model, body, L, W, H, hp, value = line.split("|")
            assert body in TRIMS, f"bad body {body} on {line}"
            cars.append(dict(
                brand=brand_game, model=model, basedOn=f"{brand_real} {real_model}",
                body=body, L=float(L), W=float(W), H=float(H), hp=int(hp), value=int(value),
            ))
    return cars


def expand(base):
    cars = [dict(c, trim="") for c in base]
    # Round-robin through trims until we hit TARGET.
    level = 0
    while len(cars) < TARGET:
        added = False
        for c in base:
            if len(cars) >= TARGET:
                break
            trims = TRIMS[c["body"]]
            if c["value"] >= UNIQUE_VALUE or level >= len(trims):
                continue
            suffix, vmul, hmul = trims[level]
            cars.append(dict(
                c, trim=suffix, model=f'{c["model"]} {suffix}',
                value=int(round(c["value"] * vmul, -2)), hp=int(c["hp"] * hmul),
            ))
            added = True
        if not added:
            raise SystemExit(f"ran out of trims at {len(cars)} cars; add base models or trims")
        level += 1
    return cars


def stable_hash(s):
    return int(hashlib.md5(s.encode()).hexdigest()[:8], 16)


def finish(cars):
    # Rarity by value rank (ties broken by hp so stronger trims rank higher).
    order = sorted(range(len(cars)), key=lambda i: (cars[i]["value"], cars[i]["hp"]))
    idx = 0
    for tier, count in TIER_COUNTS:
        for i in order[idx: idx + count]:
            cars[i]["rarity"] = tier
        idx += count

    # Stable ordering in the catalogue: by rarity then value.
    tier_rank = {t: n for n, (t, _) in enumerate(TIER_COUNTS)}
    cars.sort(key=lambda c: (tier_rank[c["rarity"]], c["value"], c["brand"], c["model"]))
    for n, c in enumerate(cars, 1):
        c["id"] = n
        c["topKmh"] = int((60 + 11 * math.sqrt(c["hp"])) * BODY_SPEED.get(c["body"], 1.0))
        c["income"] = max(1, int(round(0.02 * c["value"] ** 0.75)))
        c["paint"] = PAINTS[stable_hash(c["brand"] + c["model"]) % len(PAINTS)]
    return cars


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_outputs(cars, chunks=4):
    # CSV
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True)
    for c in cars:
        c.setdefault("name", f'{c["brand"]} {c["model"]}')
    cols = ["id", "rarity", "name", "brand", "model", "basedOn", "body", "L", "W", "H", "hp", "topKmh", "value", "income", "paint"]
    with open(os.path.join(ROOT, "data", "cars.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for c in cars:
            w.writerow([c[k] for k in cols])

    # Luau chunks. Row layout documented in CarData/init.luau.
    out_dir = os.path.join(ROOT, "src", "shared", "CarData")
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.startswith("Chunk"):
            os.remove(os.path.join(out_dir, old))
    per = math.ceil(len(cars) / chunks)
    for n in range(chunks):
        part = cars[n * per:(n + 1) * per]
        lines = ["-- AUTO-GENERATED by tools/gen_cars.py. Do not edit by hand.", "return {"]
        for c in part:
            lines.append("\t{%d,%s,%s,%s,%s,%s,%.2f,%.2f,%.2f,%d,%d,%d,%d,%s,%s}," % (
                c["id"], lua_str(c["rarity"]), lua_str(c["brand"]), lua_str(c["model"]),
                lua_str(c["basedOn"]), lua_str(c["body"]), c["L"], c["W"], c["H"],
                c["hp"], c["topKmh"], c["value"], c["income"], lua_str(c["paint"]), lua_str(c["name"]),
            ))
        lines.append("}")
        with open(os.path.join(out_dir, f"Chunk{n + 1}.luau"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")


def curated(base):
    """The 100-car list: picks from base_models.txt with a tier and a short display name."""
    by_key = {(c["brand"], c["model"]): c for c in base}
    cars = []
    with open(os.path.join(ROOT, "tools", "top100.txt"), encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            tier, brand, model, short = line.split("|")
            c = dict(by_key[(brand, model)])
            assert len(short) <= 20, short
            c["rarity"] = tier
            c["name"] = short
            cars.append(c)
    tier_rank = {t: n for n, (t, _) in enumerate(TIER_COUNTS)}
    cars.sort(key=lambda c: (tier_rank[c["rarity"]], c["value"]))
    for n, c in enumerate(cars, 1):
        c["id"] = n
        c["topKmh"] = int((60 + 11 * math.sqrt(c["hp"])) * BODY_SPEED.get(c["body"], 1.0))
        c["income"] = max(1, int(round(0.02 * c["value"] ** 0.75)))
        c["paint"] = PAINTS[stable_hash(c["brand"] + c["model"]) % len(PAINTS)]
    names = [c["name"] for c in cars]
    assert len(set(names)) == len(names), "duplicate short names"
    return cars


def main():
    base = parse_base()
    cars = curated(base)
    write_outputs(cars, chunks=1)
    from collections import Counter
    print(f"cars: {len(cars)}", dict(Counter(c["rarity"] for c in cars)))
    print("longest name:", max((c["name"] for c in cars), key=len))


def main_full():
    """Old 1000-car expansion, kept for reference."""
    base = parse_base()
    names = [(c["brand"], c["model"]) for c in base]
    dupes = {n for n in names if names.count(n) > 1}
    assert not dupes, f"duplicate models: {dupes}"
    cars = finish(expand(base))
    assert len(cars) == TARGET
    write_outputs(cars)
    from collections import Counter
    print(f"base models: {len(base)}  total cars: {len(cars)}")
    print("by rarity:", dict(Counter(c["rarity"] for c in cars)))
    for tier, _ in TIER_COUNTS:
        tc = [c for c in cars if c["rarity"] == tier]
        print(f"  {tier:9s} ${tc[0]['value']:>11,} - ${tc[-1]['value']:>11,}  e.g. {tc[len(tc)//2]['brand']} {tc[len(tc)//2]['model']}")


if __name__ == "__main__":
    main()
