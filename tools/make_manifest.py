"""Turn src/ into build/manifest.json (Rojo-style rules) so Studio can pull it over HTTP.

Used for quick syncing into an open Studio place without the Rojo plugin.
Rojo (`rojo build -o DrivinDealz.rbxlx`) is still the normal way to build the place.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPPING = [
    ("src/shared", "ReplicatedStorage", "Shared"),
    ("src/server", "ServerScriptService", "Server"),
    ("src/client", "StarterPlayer.StarterPlayerScripts", "Client"),
]


def script_class(filename):
    if filename.endswith(".server.luau"):
        return "Script", filename[: -len(".server.luau")]
    if filename.endswith(".client.luau"):
        return "LocalScript", filename[: -len(".client.luau")]
    return "ModuleScript", filename[: -len(".luau")]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def node_for_dir(path, name):
    node = {"name": name, "class": "Folder", "children": []}
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            node["children"].append(node_for_dir(full, entry))
        elif entry.endswith(".luau"):
            cls, base = script_class(entry)
            if base == "init":
                node["class"] = cls
                node["source"] = read(full)
            else:
                node["children"].append({"name": base, "class": cls, "source": read(full), "children": []})
    return node


def main():
    out = []
    for src, parent, name in MAPPING:
        if not os.path.isdir(os.path.join(ROOT, src)):
            continue
        out.append({"parent": parent, "node": node_for_dir(os.path.join(ROOT, src), name)})
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    with open(os.path.join(ROOT, "build", "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(out, f)
    print("wrote build/manifest.json")


if __name__ == "__main__":
    main()
