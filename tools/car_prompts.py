"""Print AI mesh-generation prompts for the 100 cars (used with Roblox Studio's generate_mesh).

The real car name is used only inside the prompt so the shape comes out accurate;
the game never shows it. Every prompt asks for no logos/badges/text.
Output: data/car_prompts.json  [{id, name, prompt, size:{x,y,z}}]
"""
import csv
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 3  # studs per metre

PAINT_WORDS = {
    "Crimson": "glossy crimson red", "Midnight Blue": "deep midnight blue metallic", "Pearl White": "pearl white",
    "Gunmetal": "gunmetal grey metallic", "Racing Green": "dark racing green", "Sunset Orange": "bright orange",
    "Lime": "lime green", "Jet Black": "glossy black", "Silver": "silver metallic", "Canary Yellow": "bright yellow",
    "Royal Purple": "royal purple metallic", "Sky Blue": "light sky blue", "Burgundy": "burgundy",
    "Bronze": "bronze metallic", "Matte Grey": "matte grey", "Hot Pink": "hot pink", "Teal": "teal metallic",
}

out = []
with open(os.path.join(ROOT, "data", "cars.csv"), encoding="utf-8") as f:
    for row in csv.DictReader(f):
        L, W, H = float(row["L"]), float(row["W"]), float(row["H"])
        paint = PAINT_WORDS.get(row["paint"], "silver metallic")
        prompt = (
            f"Highly accurate realistic 3D model of a {row['basedOn']} ({row['body']}), {paint} paint, "
            f"correct real-world proportions, detailed headlights and taillights, tinted glass windows, "
            f"detailed alloy rims and tyres, clean car game asset, no logos, no badges, no text, no license plate"
        )
        out.append({
            "id": int(row["id"]), "name": row["name"], "prompt": prompt,
            "size": {"x": round(W * S, 2), "y": round(H * S, 2), "z": round(L * S, 2)},
        })

with open(os.path.join(ROOT, "data", "car_prompts.json"), "w", encoding="utf-8") as f:
    json.dump(out, f, indent=1)
for c in out[-12:]:
    print(c["id"], c["name"], "|", c["prompt"][:90], c["size"])
