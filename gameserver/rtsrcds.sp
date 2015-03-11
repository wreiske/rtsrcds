#pragma semicolon 1

#include <sourcemod>
#include <steamtools>
#include <smjansson>
/*
*
* Real Time SRCDS 
* Created by E3pO (wreiske) of LowLagFrag
* 
* Contributers:
*		E3pO, 
*
* The Goal:
* 		Send all SRCDS events in realtime via JSON to display
* 		in a web browser or mobile phone using MeteorJS.
*
*/
public Plugin:myinfo = 
{
	name = "Real Time SRCDS",
	author = "wreiske",
	description = "Realtime SRCDS Monitoring",
	version = "0.1",
	url = "https://rtsrcds.com/"
};

public OnPluginStart()
{

	//These hooks are custom defined because we want to build the JSON ourselves (To include things like chat message, player class, etc)
	HookEvent("player_say", Event_PlayerSay);
	HookEvent("player_spawn", Event_PlayerSpawn);

	if (!LibraryExists("jansson")){
		PrintToServer("Missing jansson");
		return 0;
	}	

	HookAllEvents();

	PrintToServer("Loaded Real Time SRCDS.");
	BasicEvent("rtsrcds_loaded", 0);

	return 1;
}

public OnClientAuthorized(client, const String:auth[]) {
	if (client){
		BasicEvent("OnClientAuthorized", client);
	}
	return true;
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new iUserId = GetEventInt(hEvent, "userid");
	new client = GetClientOfUserId(iUserId);
	if (client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		new iClass = GetEventInt(hEvent, "class");

		new Handle:hContent = json_object();

		json_object_set_new(hContent, "class", json_integer(iClass));

		ComplexEvent("player_spawn", hContent, hEvent);
	}
	return Plugin_Continue;
}

public Action:Event_PlayerSay(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	new iUserId = GetEventInt(hEvent, "userid");
	new client = GetClientOfUserId(iUserId);

	if (client < 1){
		//TODO: Probably should support sv_say.
		return Plugin_Continue;
	}

	decl String:szText[256];
	GetEventString(hEvent, "text", szText, sizeof(szText));


	new Handle:hContent = json_object();

	json_object_set_new(hContent, "message", json_string(szText));
	json_object_set_new(hContent, "isPlayerAlive", json_integer(IsPlayerAlive(client)));
	json_object_set_new(hContent, "team", json_integer(GetClientTeam(client)));
	json_object_set_new(hContent, "user_id", json_integer(iUserId));

	ComplexEvent("player_say", hContent, hEvent);

	return Plugin_Continue;
}  

stock bool:SetCommunityIDFromEvent(Handle:hEvent, Handle:hContent){
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	decl String:sAuth[32];
	GetClientAuthString(client, sAuth, sizeof(sAuth));

	new String:sCommunityID[18];
	GetCommunityIDString(sAuth, sCommunityID, sizeof(sCommunityID)); 
	if (StrEqual(sCommunityID, "")){
		//Probably should just remove this completely
		json_object_set_new(hContent, "community_id", json_string("NONE"));
	} else {
		json_object_set_new(hContent, "community_id", json_string(sCommunityID));
	}
	return true;
}
ComplexEvent(String:sEvent[], Handle:hContent, Handle:hEvent)
{
	new Handle:hObj = json_object();
	json_object_set_new(hObj, "event", json_string(sEvent));

	json_object_set_new(hObj, "api_key", json_string("API_KEY_GOES_HERE")); //This should pull from a config file...

	if(hEvent != INVALID_HANDLE){
		SetCommunityIDFromEvent(hEvent,hContent); //Lets add a community_id to the request content if we are a player.

		json_object_set_new(hObj, "content", hContent);
	}

	new String:sJSON[4096];
	json_dump(hObj, sJSON, sizeof(sJSON), 0);

	PrintToServer("%s\n", sJSON);

	SendRequest(sJSON);
	CloseHandle(hObj);
}
BasicEvent(String:sEvent[], client){
	new Handle:hObj = json_object();

	json_object_set_new(hObj, "event", json_string(sEvent));
	json_object_set_new(hObj, "api_key", json_string("API_KEY_GOES_HERE")); //This should pull from a config file...

	if(client != 0){
		new Handle:hContent = json_object();

		decl String:sAuth[32];
		GetClientAuthString(client, sAuth, sizeof(sAuth));

		new String:sCommunityID[18];
		GetCommunityIDString(sAuth, sCommunityID, sizeof(sCommunityID)); 

		if (StrEqual(sCommunityID, "")){
			json_object_set_new(hContent, "community_id", json_string("NONE")); //Probably should just remove this completely
		} else {
			json_object_set_new(hContent, "community_id", json_string(sCommunityID));
		}
		json_object_set_new(hObj, "content", hContent);
	}

	new String:sJSON[4096];
	json_dump(hObj, sJSON, sizeof(sJSON), 0);

	PrintToServer("%s\n", sJSON);

	SendRequest(sJSON);
	CloseHandle(hObj);
}
SendRequest(String:JSON[]) {
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, "https://blackbox.rtsrcds.com/api"); // Create the HTTP request
	Steam_SetHTTPRequestGetOrPostParameter(request, "json", JSON); // Set post param "json" with the contents of our JSON Request
	Steam_SendHTTPRequest(request, OnRequestComplete); // Send the request
}
public OnRequestComplete(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:status) {
	decl String:response[1024];
	Steam_GetHTTPResponseBodyData(request, response, sizeof(response)); // Get the response from the server
	PrintToServer(response);
	Steam_ReleaseHTTPRequest(request); // Close the handle
}  


public Action:Steam_RestartRequested()
{
	BasicEvent("Steam_RestartRequested", 0);
	return Plugin_Continue;
}

public Steam_FullyLoaded()
{
	new Handle:hContent = json_object();

	new octets[4];
	Steam_GetPublicIP(octets);

	new String:ServerIp[16];
	Format(ServerIp, 16, "%d.%d.%d.%d", octets[0], octets[1], octets[2], octets[3]);

	new iPort = GetConVarInt( FindConVar( "hostport" ) );

	decl String:sPassword[240];
	GetConVarString(FindConVar( "sv_password" ),sPassword,sizeof(sPassword)); 	

	decl String:sHostname[64];
	GetConVarString(FindConVar( "hostname" ),sHostname,sizeof(sHostname));

	json_object_set_new(hContent, "vac", json_boolean(Steam_IsVACEnabled()));
	json_object_set_new(hContent, "ip", json_string(ServerIp));
	json_object_set_new(hContent, "port", json_integer(iPort));
	json_object_set_new(hContent, "hostname", json_string(sHostname));
	json_object_set_new(hContent, "maxplayers", json_integer(MaxClients));
	json_object_set_new(hContent, "password", json_string(sPassword));

	ComplexEvent("Steam_FullyLoaded", hContent, INVALID_HANDLE);

	return;
}
public OnMapStart()
{
	new Handle:hContent = json_object();
	new String:sMap[64];

	GetCurrentMap(sMap, 64);

	json_object_set_new(hContent, "map", json_string(sMap));

	ComplexEvent("OnMapStart", hContent, INVALID_HANDLE);
}

public OnMapEnd()
{
	new Handle:hContent = json_object();
	new String:sMap[64];

	GetCurrentMap(sMap, 64);

	json_object_set_new(hContent, "map", json_string(sMap));

	ComplexEvent("OnMapEnd", hContent, INVALID_HANDLE);
}

stock bool:GetCommunityIDString(const String:SteamID[], String:CommunityID[], const CommunityIDSize) 
{ 
	decl String:SteamIDParts[3][11]; 
	new const String:Identifier[] = "76561197960265728"; 

	if ((CommunityIDSize < 1) || (ExplodeString(SteamID, ":", SteamIDParts, sizeof(SteamIDParts), sizeof(SteamIDParts[])) != 3)) 
	{ 
		CommunityID[0] = '\0'; 
		return false; 
	} 

	new Current, CarryOver = (SteamIDParts[1][0] == '1'); 
	for (new i = (CommunityIDSize - 2), j = (strlen(SteamIDParts[2]) - 1), k = (strlen(Identifier) - 1); i >= 0; i--, j--, k--) 
	{ 
		Current = (j >= 0 ? (2 * (SteamIDParts[2][j] - '0')) : 0) + CarryOver + (k >= 0 ? ((Identifier[k] - '0') * 1) : 0); 
		CarryOver = Current / 10; 
		CommunityID[i] = (Current % 10) + '0'; 
	} 

	CommunityID[CommunityIDSize - 1] = '\0'; 
	return true; 
}




//--------------------------------------------------
//EVENT hooks! Copy pasty from https://github.com/raziEiL/SourceMod/blob/master/say_event.sp
//This should be replaced by parsing 
//--------------------------------------------------


public EventCallback(Handle:hEvent, const String:sName[], bool:dontBroadcast)
{

	PrintToServer("EVENT FIRED!");
	new Handle:hContent = json_object();

	decl String:buffer[512];
	Format(buffer, sizeof(buffer), "%s", sName);

	ComplexEvent(buffer, hContent, hEvent);
}

public HookAllEvents(){
	PrintToServer("HOOKING ALL EVENTS.");

	HookEvent("achievement_earned", EventCallback, EventHookMode_PostNoCopy);
	HookEvent("achievement_event", EventCallback, EventHookMode_PostNoCopy);

	HookEvent("server_addban", EventCallback, EventHookMode_PostNoCopy);
	HookEvent("server_cvar", EventCallback, EventHookMode_PostNoCopy);
	HookEvent("server_removeban", EventCallback, EventHookMode_PostNoCopy);
	HookEvent("server_shutdown", EventCallback, EventHookMode_PostNoCopy);
	HookEvent("server_spawn", EventCallback, EventHookMode_PostNoCopy);

	HookEvent("player_death", EventCallback, EventHookMode_PostNoCopy);
	HookEvent("item_found", EventCallback, EventHookMode_PostNoCopy);
	HookEvent("player_teleported", EventCallback, EventHookMode_PostNoCopy);
	
}