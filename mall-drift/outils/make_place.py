# Fabrique GoldenMallDrift.rbxlx à partir des scripts de src/ :
#   python3 outils/make_place.py src GoldenMallDrift.rbxlx
import sys, os, glob, xml.dom.minidom
src, out = sys.argv[1], sys.argv[2]
ref = [0]
def r():
    ref[0] += 1
    return "RBX%d" % ref[0]
def script(cls, path):
    name = os.path.basename(path).split(".")[0]
    code = open(path, encoding="utf-8").read()
    assert "]]>" not in code
    return ('<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>'
            '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString></Properties></Item>') % (cls, r(), name, code)
def item(cls, children):
    return '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string></Properties>%s</Item>' % (cls, r(), cls, "".join(children))
mods = [script("ModuleScript", p) for p in sorted(glob.glob(os.path.join(src, "ReplicatedStorage", "*.luau")))]
srv = [script("Script", p) for p in sorted(glob.glob(os.path.join(src, "ServerScriptService", "*.server.luau")))]
cli = [script("LocalScript", p) for p in sorted(glob.glob(os.path.join(src, "StarterPlayerScripts", "*.client.luau")))]
data = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        # Éclairage « Future » (ombres et reflets réalistes) : ne se règle pas par script
        + ('<Item class="Lighting" referent="%s"><Properties><string name="Name">Lighting</string>'
           '<token name="Technology">4</token><bool name="GlobalShadows">true</bool></Properties></Item>') % r()
        + item("ReplicatedStorage", mods) + item("ServerScriptService", srv)
        + item("StarterPlayer", [item("StarterPlayerScripts", cli)]) + '</roblox>')
xml.dom.minidom.parseString(data.encode("utf-8"))
open(out, "w", encoding="utf-8").write(data)
print("OK", out, len(data), "octets,", len(mods) + len(srv) + len(cli), "scripts")
