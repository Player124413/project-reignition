using Netfox;
using Godot;

namespace Project.Party;

/// <summary> Responsible for handling network connections. </summary>
public partial class NetworkManager : Node
{
	private ENetMultiplayerPeer peer = new();

	private int port = 9999;
	private string ipAddress = "127.0.0.1";

	public void StartServer()
	{
		peer.CreateServer(port);
		Multiplayer.MultiplayerPeer = peer;
		Multiplayer.Connect(MultiplayerApi.SignalName.PeerConnected, new Callable(this, MethodName.AddPlayer));
	}

	private void AddPlayer(int peerId)
	{
		GD.Print($"{peerId} has connected.");

		if (peerId == 1)
			return;
	}
}

