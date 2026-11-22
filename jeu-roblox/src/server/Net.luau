-- Crée les RemoteEvents / RemoteFunctions partagés avec le client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

local Net = {
	State = event("State"), -- serveur → client : état du joueur
	Notify = event("Notify"), -- serveur → client : message / annonce / effet
	Session = event("Session"), -- serveur → client : ouverture/fermeture de l'atelier coiffure
	Action = Instance.new("RemoteFunction"), -- client → serveur
}
Net.Action.Name = "Action"
Net.Action.Parent = folder
folder.Parent = ReplicatedStorage

-- kind : "info" | "success" | "error" | "money" | "announce"
function Net.Toast(player: Player, text: string, kind: string?)
	Net.Notify:FireClient(player, { Type = "toast", Text = text, Kind = kind or "info" })
end

function Net.Announce(text: string, color: Color3?)
	Net.Notify:FireAllClients({ Type = "announce", Text = text, Color = color })
end

return Net
