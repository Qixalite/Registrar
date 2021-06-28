#pragma semicolon 1

#include <sourcemod>
#include <color_literals>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#define RED 0
#define BLU 1


public Plugin:myinfo = 
{
    name = "Demo Recording Checker",
    author = "Aad",
    description = "Checks to see if a player on the server is actively recording POV demos",
    version = "0.0.1",
    url = "https://github.com/l-Aad-l/"
}

ArrayList playersList;
ArrayList recordingPlayers;
StringMap playerNames;

new bool:teamReadyState[2] = { false, false };
new bool:teamWarnedState[2] = { false, false };

public OnPluginStart()
{
    //AddCommandListener(Listener_StopRecord, "stop");
    playersList = new ArrayList(32);
    recordingPlayers = new ArrayList(32);
    playerNames = new StringMap();
    RegServerCmd("drc_player_list", Command_ListPlayers, "Prints a list of all players");
    RegConsoleCmd("drc_list", Command_SayList);

    // testing log message from plugin to verify how it displays as logs / chat and if it's parsed by both demos.tf and logstf
    ServerCommand("say", "hello!");
    ServerCommand("say hello :)");
    LogToGame("Test to see which file this messages goes into - needs to go into the file that eventually uploads to logs.tf & stv demo file");

    //HookEvent("teamplay_round_restart_seconds", Event_TeamplayRestartSeconds);
    HookEvent("tournament_stateupdate", Event_TournamentStateupdate);

    //if there are players already on the server
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            // Only trigger for client indexes actually in the game
            QueryClientConVar(i, "ds_enable", ConVarQueryFinished:ClientConVar, i);
            QueryClientConVar(i, "prec_mode", ConVarQueryFinished:ClientConVar, i);
        }
    } 
}

public OnMapStart()
{
    teamReadyState[RED] = false;
    teamReadyState[BLU] = false;
    teamWarnedState[RED] = false;
    teamWarnedState[BLU] = false;
}

public Event_TournamentStateupdate(Handle:event, const String:name[], bool:dontBroadcast)
{
    //TODO check to see if ppl start recording
	// significantly more robust way of getting team ready status
    teamReadyState[RED] = GameRules_GetProp("m_bTeamReady", 1, .element=2) != 0;
    teamReadyState[BLU] = GameRules_GetProp("m_bTeamReady", 1, .element=3) != 0;
    int n = playersList.Length;
    int m = recordingPlayers.Length;

    //todo red team
	// If both teams are ready
    if (teamReadyState[BLU] && n !=0)
	{
        for (new i = 1; i <= MaxClients; i++)
        {
            // Only trigger for client indexes actually in the game
            if (IsClientInGame(i) && (TF2_GetClientTeam(i) == TFTeam_Blue))
            {
                char steamID64[32];
                char clientName[32];
                if(!GetClientAuthId(i, AuthId_SteamID64, steamID64, sizeof(steamID64))) {
                    ThrowError("[DRC] Could not get Steam ID");
                }
                playerNames.GetString(steamID64, clientName, sizeof(clientName));
                if(recordingPlayers.FindString(steamID64) == -1) {
                    if(!teamWarnedState[BLU]) {
                        teamWarnedState[BLU] = true;
                    }


                    PrintToChatAll("[DRC] %s (%s) is not recording", clientName, steamID64);
                }
            }
        } 
        //stuck here needs to be fixed
        if(teamWarnedState[BLU]) {
            GameRules_SetProp("m_bTeamReady", 0, .element=3);
            PrintToChatAll("[DRC] BLU has been unreadied.");
            PrintToChatAll("[DRC] If BLU readies up again, then BLU accepts all responsibilty for the players that were not recording.");
            teamWarnedState[BLU] = false;
        } else {
            PrintToChatAll("TEST");
        }
	}	
}

public void OnClientPostAdminCheck(int client) {
    if(IsFakeClient(client)) {
        return;
    }

    // Check both Valve and PREC demo recording client convars
    QueryClientConVar(client, "ds_enable", ConVarQueryFinished:ClientConVar, client);
    QueryClientConVar(client, "prec_mode", ConVarQueryFinished:ClientConVar, client);
}

public Action:OnClientCommand(client, args)
{
    static String:Buffer[32];   
    GetCmdArg(0, Buffer, sizeof(Buffer));

    char steamID[32];
    GetCmdArg(1, steamID, sizeof(steamID));
    if(playersList.FindString(steamID) != -1) {
        if(StrEqual(Buffer, "demorestart", true) && IsClientInGame(client))
        {
            decl String:sClientName[32], String:sClientAuth[30];
            GetClientName(client, sClientName, sizeof(sClientName));
            GetClientAuthId(client, AuthId_SteamID64, sClientAuth, sizeof(sClientAuth));
            PrintColoredChat(client, "\x04[DRC] \x01%s  \x04(\x01%s\x04) has started recording a demo.", sClientName,  sClientAuth);
            
            if(recordingPlayers.FindString(steamID) == -1) {
                //If players are not recording
                //finally started recording
                //PrintColoredChat(client, "\x04[DRC] \x01%s  \x04(\x01%s\x04) has started recording a demo.", sClientName,  sClientAuth);
                recordingPlayers.PushString(steamID);
                if(playersList.FindString(steamID) != -1) {
                    playersList.Erase(playersList.FindString(steamID));
                }
                //playerNames.Remove(steamID64);
            } else {
                //If players are recording
                //check to see if they actually started recording here when the match started 
                //maybe change the recordingplayers arraylist or add a new arraylist to specifically track users who are recording with demorestart
            }
        } 
    }
  
    // else {
    //     decl String:sClientName[32], String:sClientAuth[30];
    //     GetClientName(client, sClientName, sizeof(sClientName));
    //     GetClientAuthId(client, AuthId_SteamID64, sClientAuth, sizeof(sClientAuth));
    //     PrintColoredChat(client, "\x04[DRC] \x01%s  \x04(%s) has NOT started recording a demo.", sClientName,  sClientAuth);
    // }
    //PrintToChatAll(Buffer);
    return Plugin_Continue;
}


public ClientConVar(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[]) {   
    decl String:sClientName[32], String:sClientAuth[30];
    GetClientName(client, sClientName, sizeof(sClientName));
    GetClientAuthId(client, AuthId_SteamID64, sClientAuth, sizeof(sClientAuth)); 
    
    //Temporary - testing purposes only
    LogMessage("[DRC] %s (%s): '%s' is set to '%s'", sClientName, sClientAuth, cvarName, cvarValue);
    //PrintToChat(client,"%s (%s): '%s' is set to '%s'", sClientName, sClientAuth, cvarName, cvarValue);

    char steamID64[32];
    if(!GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof(steamID64))) {
        ThrowError("Could not get Steam ID");
    }
    
    // the cvar values required by most comp scenes are coincidentally the same - no need for if statments for each one
    if(StrEqual(cvarName[0], "ds_enable") || StrEqual(cvarName[0], "prec_mode")) {
        PrintToChatAll("%s - %s", cvarName[0], cvarValue[0]);

        //add player name to player name list
        playerNames.SetString(steamID64, sClientName, true);

        if(StrEqual(cvarValue[0], "3") || StrEqual(cvarValue[0], "2"))  {
            //If players are recording
            if(recordingPlayers.FindString(steamID64) == -1 || playersList.FindString(steamID64) == -1) {
                recordingPlayers.PushString(steamID64);
                if(playersList.FindString(steamID64) != -1) {
                    playersList.Erase(playersList.FindString(steamID64));
                }
                //playerNames.Remove(steamID64);
            }
        } else {
            //If players are not recording
            if(recordingPlayers.FindString(steamID64) == -1) {
                if(playersList.FindString(steamID64) == -1) {
                    playersList.PushString(steamID64);
                }
            }
        }
    }
} 

public void OnClientDisconnect(int client)
{
    char steamID64[32];
    if(!GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof(steamID64))) {
        ThrowError("Could not get Steam ID");
    }

    if(playersList.FindString(steamID64) != -1) {
        playersList.Erase(playersList.FindString(steamID64));
    }

    if(recordingPlayers.FindString(steamID64) != -1) {
        recordingPlayers.Erase(recordingPlayers.FindString(steamID64));
    }
    playerNames.Remove(steamID64);
}

public Action Command_ListPlayers(int args) {
    int n = playersList.Length;
    int m = recordingPlayers.Length;

    char clientSteamID64[32];
    char clientName[32];

    PrintToChatAll("[DRC] Players NOT Recording Demos");
    if(n == 0) {
        char cmdName[32];
        GetCmdArg(0, cmdName, sizeof(cmdName));
        //PrintToServer("%s: No players added to list", cmdName);
        PrintToChatAll("%s: No players added to list", cmdName);
        PrintCenterTextAll("%s: No players added to list", cmdName);
    }
    for (int i = 0; i < n; i++) {
        playersList.GetString(i, clientSteamID64, sizeof(clientSteamID64));
        playerNames.GetString(clientSteamID64, clientName, sizeof(clientName));
        //PrintToServer("%d: %s (%s)", i, clientName, clientSteamID64);
        PrintToChatAll("%d: %s (%s)", i, clientName, clientSteamID64);
        PrintCenterTextAll("%d: %s (%s)", i, clientName, clientSteamID64);
    }
    PrintToChatAll("---------------------------");
    PrintToChatAll("[DRC] Players Recording Demos");
    if(m == 0) {
        char cmdName[32];
        GetCmdArg(0, cmdName, sizeof(cmdName));
        //PrintToServer("%s: No players added to list", cmdName);
        PrintToChatAll("%s: No players added to list", cmdName);
    }
    for (int i = 0; i < m; i++) {
        recordingPlayers.GetString(i, clientSteamID64, sizeof(clientSteamID64));
        playerNames.GetString(clientSteamID64, clientName, sizeof(clientName));
       // PrintToServer("%d: %s (%s)", i, clientName, clientSteamID64);
        PrintToChatAll("%d: %s (%s)", i, clientName, clientSteamID64);
    }
}

public Action Command_SayList(int client, int args) {


    int n = playersList.Length;
    int m = recordingPlayers.Length;

    char clientSteamID64[32];
    char clientName[32];

    PrintToChatAll("[DRC] Players NOT Recording Demos");
    if(n == 0) {
        char cmdName[32];
        GetCmdArg(0, cmdName, sizeof(cmdName));
        //PrintToServer("%s: No players added to list", cmdName);
        PrintToChatAll("%s: No players added to list", cmdName);
    }
    for (int i = 0; i < n; i++) {
        playersList.GetString(i, clientSteamID64, sizeof(clientSteamID64));
        playerNames.GetString(clientSteamID64, clientName, sizeof(clientName));
        //PrintToServer("%d: %s (%s)", i, clientName, clientSteamID64);
        PrintToChatAll("%d: %s (%s)", i, clientName, clientSteamID64);
    }
    PrintToChatAll("---------------------------");
    PrintToChatAll("[DRC] Players Recording Demos");
    if(m == 0) {
        char cmdName[32];
        GetCmdArg(0, cmdName, sizeof(cmdName));
        //PrintToServer("%s: No players added to list", cmdName);
        PrintToChatAll("%s: No players added to list", cmdName);
    }
    for (int i = 0; i < m; i++) {
        recordingPlayers.GetString(i, clientSteamID64, sizeof(clientSteamID64));
        playerNames.GetString(clientSteamID64, clientName, sizeof(clientName));
       // PrintToServer("%d: %s (%s)", i, clientName, clientSteamID64);
        PrintToChatAll("%d: %s (%s)", i, clientName, clientSteamID64);
    }
}
