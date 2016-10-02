#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_checkpoint>


#define DEBUG_ADDS
#define DEBUG_ZONE
#define DEBUG_INSERTREC
#define DEBUG_DB
#define DEBUG_SETS


enum
{
    CPZONE_ID = 0,
    
    CPZONE_RUN_ID,
    
    CPZONE_NUM,
    
    CPZONE_ENTREF,
    
    CPZONE_SIZE
};

enum
{
    CP_NAME[MAX_CP_NAME_CELL] = 0,
    
    CP_NUM,
    
    CP_RUN_ID,
    
    CP_BESTTIMES[MAX_MODES * MAX_STYLES],
    CP_BESTTIMES_UID[MAX_MODES * MAX_STYLES],
    //CP_BESTTIMES_NAME[MAX_MODES * MAX_STYLES * MAX_BEST_NAME_CELL],
    
    //CP_RECTIMES[MAX_MODES * MAX_STYLES],
    //CP_RECTIMES_UID[MAX_MODES * MAX_STYLES],
    
    
    CP_SIZE
};

enum
{
    CCP_NUM = 0,
    
    CCP_TIME,
    
    CCP_SIZE
};



ArrayList g_hCPZones;

ArrayList g_hCPs;


int g_iBuildingNum[INF_MAXPLAYERS];


ArrayList g_hClientCP[INF_MAXPLAYERS];
int g_iClientLatestCP[INF_MAXPLAYERS];


// Cache for hud.
float g_flLastTouch[INF_MAXPLAYERS];
float g_flLastCPTime[INF_MAXPLAYERS];
float g_flLastCPBestTime[INF_MAXPLAYERS];



// CONVARS
//ConVar g_ConVar_ReqCPs;



#include "influx_zones_checkpoint/db.sp"


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Checkpoint",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_CP );
    
    
    CreateNative( "Influx_SaveClientCP", Native_SaveClientCP );
    CreateNative( "Influx_AddCP", Native_AddCP );
    
    CreateNative( "Influx_PrintCPTimes", Native_PrintCPTimes );
    
    CreateNative( "Influx_GetClientLastCPTouch", Native_GetClientLastCPTouch );
    CreateNative( "Influx_GetClientLastCPTime", Native_GetClientLastCPTime );
    CreateNative( "Influx_GetClientLastCPBestTime", Native_GetClientLastCPBestTime );
}

public void OnPluginStart()
{
    g_hCPs = new ArrayList( CP_SIZE );
    
    g_hCPZones = new ArrayList( CPZONE_SIZE );
    
    
    // CONVARS
    //g_ConVar_ReqCPs = CreateConVar( "influx_checkpoint_requirecps", "0", "In order to beat the map, player must activate all checkpoints?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
}

public void OnAllPluginsLoaded()
{
    DB_Init();
}

public void OnClientPutInServer( int client )
{
    delete g_hClientCP[client];
    
    g_hClientCP[client] = new ArrayList( CCP_SIZE );
    
    
    g_iClientLatestCP[client] = 0;
    
    g_flLastTouch[client] = 0.0;
    g_flLastCPBestTime[client] = INVALID_RUN_TIME;
    g_flLastCPTime[client] = INVALID_RUN_TIME;
    
    
    g_iBuildingNum[client] = 0;
}

public void Influx_OnPreRunLoad()
{
    g_hCPs.Clear();
}

public void Influx_OnPostRecordsLoad()
{
    DB_GetCPTimes();
}

public void Influx_OnPreZoneLoad()
{
    g_hCPZones.Clear();
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    g_hClientCP[client].Clear();
    
    g_iClientLatestCP[client] = 0;
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    if ( flags & (RES_TIME_PB | RES_TIME_FIRSTOWNREC) )
    {
        DB_InsertClientTimes( client, runid, mode, style, flags );
    }
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_CP ) return Plugin_Continue;
    
    
    int runid = kv.GetNum( "run_id", -1 );
    if ( runid < 1 ) return Plugin_Stop;
    
    
    int cpnum = kv.GetNum( "cp_num", -1 );
    if ( cpnum < 1 ) return Plugin_Stop;
    
    
    //char szName[MAX_CP_NAME];
    //kv.GetString( "cp_name", szName, sizeof( szName ), "" );
    
    
    decl data[CPZONE_SIZE];
    
    data[CPZONE_ID] = zoneid;
    
    data[CPZONE_RUN_ID] = runid;
    
    data[CPZONE_NUM] = cpnum;
    
    data[CPZONE_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hCPZones.PushArray( data );
    
    
    AddCP( runid, cpnum );
    
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_CP ) return Plugin_Continue;
    
    
    int index = FindCPById( zoneid );
    if ( index == -1 ) return Plugin_Stop;
    
    
    kv.SetNum( "run_id", g_hCPZones.Get( index, CPZONE_RUN_ID ) );
    
    kv.SetNum( "cp_num", g_hCPZones.Get( index, CPZONE_NUM ) );
    
    return Plugin_Handled;
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_CP ) return;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid < 1 ) return;
    
    
    int cpnum = g_iBuildingNum[client];
    if ( cpnum < 1 ) return;
    
    
    
    decl data[CPZONE_SIZE];
    
    data[CPZONE_ID] = zoneid;
    
    data[CPZONE_RUN_ID] = runid;
    
    data[CPZONE_NUM] = cpnum;
    
    data[CPZONE_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hCPZones.PushArray( data );
    
    
    AddCP( runid, cpnum );
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_CP ) return;
    
    
    int index = FindCPById( zoneid );
    if ( index == -1 ) return;
    
    
    // Update ent reference.
    g_hCPZones.Set( index, EntIndexToEntRef( ent ), CPZONE_ENTREF );
    
    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_CP );
    
    
    Inf_SetZoneProp( ent, g_hCPZones.Get( index, CPZONE_ID ) );
}

public Action Influx_OnZoneBuildAsk( int client, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_CP ) return Plugin_Continue;
    
    
    
    int runid = Influx_GetClientRunId( client );
    
    if ( runid == -1 ) return Plugin_Continue;
    
    
    
    char szDisplay[32];
    char szInfo[32];
    char szRun[MAX_RUN_NAME];
    
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    
    Menu menu = new Menu( Hndlr_CreateZone_SelectCPNum );
    menu.SetTitle( "Which stage do you want to create?\nRun: %s\nCheckpoints: %i\n ",
        szRun,
        GetRunCPCount( runid ) );
    
    
    
    
    int highest = 0;
    
    int cpnum;
    
    
    int len = g_hCPZones.Length;
    for( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) != runid ) continue;
        
        
        cpnum = g_hCPZones.Get( i, CP_NUM );
        
        if ( cpnum > highest )
        {
            highest = cpnum;
        }
    }
    
    ++highest;
    
    
    // Add highest to the top.
    FormatEx( szInfo, sizeof( szInfo ), "%i", highest );
    FormatEx( szDisplay, sizeof( szDisplay ), "New CP #%02i\n ", highest );
    
    menu.AddItem( szInfo, szDisplay );
    
    
    
    // Display them in a sorted order.
    
    
    for ( int i = 1; i < highest; i++ )
    {
        FormatEx( szInfo, sizeof( szInfo ), "%i", i );
        FormatEx( szDisplay, sizeof( szDisplay ), "CP %02i", i );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Stop;
}

public int Hndlr_CreateZone_SelectCPNum( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    char szInfo[16];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid < 1 ) return 0;
    
    
    int cpnum = StringToInt( szInfo );
    if ( cpnum < 1 ) return 0;
    
    
    if ( FindCPByNum( runid, cpnum ) != -1 )
    {
        Menu menu = new Menu( Hndlr_CreateZone_SelectMethod );
        
        menu.SetTitle( "That CP already exists!\n " );
        
        menu.AddItem( szInfo, "Create a new instance (keep both)" );
        menu.AddItem( szInfo, "Replace existing one(s)\n " );
        menu.AddItem( "", "Cancel" );
        
        menu.ExitButton = false;
        
        menu.Display( client, MENU_TIME_FOREVER );
    }
    else
    {
        StartToBuild( client, cpnum );
    }
    
    return 0;
}

public int Hndlr_CreateZone_SelectMethod( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    char szInfo[16];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid < 1 ) return 0;
    
    
    int cpnum = StringToInt( szInfo );
    if ( cpnum < 1 ) return 0;
    
    
    switch ( index )
    {
        case 0 : // Keep both
        {
            StartToBuild( client, cpnum );
        }
        case 1 : // Replace existing ones
        {
            int len = g_hCPZones.Length;
            for ( int i = 0; i < len; i++ )
            {
                if ( g_hCPZones.Get( i, CPZONE_RUN_ID ) != runid ) continue;
                
                if ( g_hCPZones.Get( i, CPZONE_NUM ) != cpnum ) continue;
                
                
                int zoneid = g_hCPZones.Get( i, CPZONE_ID );
                
                
                g_hCPZones.Erase( i );
                
                --i;
                len = g_hCPZones.Length;
                
                
                Influx_DeleteZone( zoneid );
            }
            
            StartToBuild( client, cpnum );
        }
    }
    
    return 0;
}

public void E_StartTouchPost_CP( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int zoneid = Inf_GetZoneProp( ent );
    
#if defined DEBUG_ZONE
    PrintToServer( INF_DEBUG_PRE..."Player %i hit cp %i (ent: %i)!", activator, zoneid, ent );
#endif
    
    int zindex = FindCPById( zoneid );
    if ( zindex == -1 ) return;
    
    
    
    int runid = g_hCPZones.Get( zindex, CPZONE_RUN_ID );
    
    if ( Influx_GetClientRunId( activator ) != runid ) return;
    
    
    
    if ( ent != EntRefToEntIndex( g_hCPZones.Get( zindex, CPZONE_ENTREF ) ) )
    {
        return;
    }
    
    
    SaveClientCP( activator, g_hCPZones.Get( zindex, CPZONE_NUM ) );
}

stock void SaveClientCP( int client, int cpnum )
{
    if ( Influx_GetClientState( client ) != STATE_RUNNING ) return;
    
    
    int runid = Influx_GetClientRunId( client );
    if ( runid == -1 ) return;
    
    
    int index = FindCPByNum( runid, cpnum );
    if ( index == -1 ) return;
    
    
    
#if defined DEBUG_ZONE
    PrintToServer( INF_DEBUG_PRE..."Stage num is %i!", cpnum );
#endif
    
    
    // Update our stage times if we haven't gone in here yet.
    if ( !ShouldSaveCP( client, cpnum ) ) return;
    
    
    float time = Influx_GetClientTime( client );
    
#if defined DEBUG_ZONE
    PrintToServer( INF_DEBUG_PRE..."Inserting new client time %.3f", time );
#endif
    
    decl data[CCP_SIZE];
    data[CCP_NUM] = cpnum;
    data[CCP_TIME] = view_as<int>( time );
    
    g_hClientCP[client].PushArray( data );
    
    
    
    int mode = Influx_GetClientMode( client );
    int style = Influx_GetClientStyle( client );
    
    
    g_iClientLatestCP[client] = cpnum;
    
    g_flLastCPTime[client] = time;
    g_flLastCPBestTime[client] = GetBestTime( index, mode, style );
    
    g_flLastTouch[client] = GetEngineTime();
}

stock void StartToBuild( int client, int cpnum )
{
    g_iBuildingNum[client] = cpnum;
    
    
    char szName[MAX_ZONE_NAME];
    char szRun[MAX_RUN_NAME];
    
    Influx_GetRunName( Influx_GetClientRunId( client ), szRun, sizeof( szRun ) );
    
    FormatEx( szName, sizeof( szName ), "%s CP %02i", szRun, cpnum );
    
    
    Influx_BuildZone( client, ZONETYPE_CP, szName );
}

stock int GetRunCPCount( int runid )
{
    int num = 0;
    
    int len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) == runid )
        {
            ++num;
        }
    }

    return num;
}

stock int FindCPById( int id )
{
    int len = g_hCPZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPZones.Get( i, CPZONE_ID ) == id )
        {
            return i;
        }
    }
    
    return -1;
}

stock int FindCPByNum( int runid, int num )
{
    int len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) != runid ) continue;
        
        if ( g_hCPs.Get( i, CP_NUM ) == num )
        {
            return i;
        }
    }
    
    return -1;
}

stock bool ShouldSaveCP( int client, int cpnum )
{
    if ( g_hClientCP[client] == null ) return false;
    
    if ( cpnum <= g_iClientLatestCP[client] ) return false;
    
    
    // Start from the end.
    /*for ( int i = g_hClientCP[client].Length - 1; i >= 0; i-- )
    {
        if ( g_hClientCP[client].Get( i, CCP_NUM ) >= cpnum )
        {
            return false;
        }
    }*/
    
    return true;
}

stock int AddCP( int runid, int cpnum, const char[] szName = "", bool bUpdateName = false )
{
    int index = FindCPByNum( runid, cpnum );
    if ( index != -1 )
    {
        // Update our name.
        if ( bUpdateName && szName[0] != '\0' )
        {
            decl name[MAX_CP_NAME_CELL];
            
            strcopy( view_as<char>( name ), MAX_CP_NAME, szName );
            
            for ( int i = 0; i < MAX_CP_NAME_CELL; i++ )
            {
                g_hCPs.Set( index, name[i], CP_NAME + i );
            }
        }
        
        return index;
    }
    
    
    int data[CP_SIZE];
    
    if ( szName[0] != '\0' )
    {
        strcopy( view_as<char>( data[CP_NAME] ), MAX_CP_NAME, szName );
    }
    else
    {
        FormatEx( view_as<char>( data[CP_NAME] ), MAX_CP_NAME, "CP #%i", cpnum );
    }
    
    data[CP_NUM] = cpnum;
    data[CP_RUN_ID] = runid;
    
    return g_hCPs.PushArray( data );
}

stock void GetCPName( int index, char[] sz, int len )
{
    decl data[MAX_CP_NAME_CELL];
    
    for ( int i = 0; i < MAX_CP_NAME_CELL; i++ )
    {
        data[i] = g_hCPs.Get( index, CP_NAME + i );
    }
    
    strcopy( sz, len, view_as<char>( data ) );
}

stock float GetBestTime( int index, int mode, int style )
{
    return view_as<float>( g_hCPs.Get( index, CP_BESTTIMES + OFFSET_MODESTYLE( mode, style ) ) );
}

stock void SetBestTime( int index, int mode, int style, float time, int uid = 0 )
{
#if defined DEBUG_SETS
    PrintToServer( INF_DEBUG_PRE..."Setting best time (%i, %i, %.3f, %i)", mode, style, time, uid );
#endif
    
    int offset = OFFSET_MODESTYLE( mode, style );
    
    g_hCPs.Set( index, time, CP_BESTTIMES + offset );
    g_hCPs.Set( index, uid, CP_BESTTIMES_UID + offset );
}

/*stock float GetRecordTime( ArrayList stages, int index, int mode, int style )
{
    return view_as<float>( stages.Get( index, CP_RECTIMES + OFFSET_MODESTYLE( mode, style ) ) );
}

stock void SetRecordTime( ArrayList stages, int index, int mode, int style, float time, int uid = 0 )
{
#if defined DEBUG_SETS
    PrintToServer( INF_DEBUG_PRE..."Setting record time (%i, %i, %.3f, %i)", mode, style, time, uid );
#endif
    
    int offset = OFFSET_MODESTYLE( mode, style );
    
    stages.Set( index, time, CP_RECTIMES + offset );
    stages.Set( index, uid, CP_RECTIMES_UID + offset );
}*/

/*stock void GetRunRecordName( ArrayList stages, int index, int mode, int style, char[] out, int len )
{
    decl name[MAX_BEST_NAME_CELL];
    
    GetName( stages, index, STAGE_RECTIMES_NAME, mode, style, name );
    
    strcopy( out, len, view_as<char>( name ) );
}*/

/*stock void GetRunBestName( ArrayList stages, int index, int mode, int style, char[] out, int len )
{
    decl name[MAX_BEST_NAME_CELL];
    
    GetName( stages, index, STAGE_BESTTIMES_NAME, mode, style, name );
    
    strcopy( out, len, view_as<char>( name ) );
}*/

/*stock void SetRecordName( ArrayList stages, int index, int mode, int style, const char[] szName )
{
    SetName( stages, index, STAGE_RECTIMES_NAME, mode, style, szName );
}*/

/*stock void SetBestName( ArrayList stages, int index, int mode, int style, const char[] szName )
{
    SetName( stages, index, STAGE_BESTTIMES_NAME, mode, style, szName );
}

stock void SetName( ArrayList stages, int index, int block, int mode, int style, const char[] szName )
{
    decl String:sz[MAX_BEST_NAME + 1];
    decl name[MAX_BEST_NAME_CELL];
    
    strcopy( sz, sizeof( sz ), szName );
    
    
    LimitString( sz, sizeof( sz ), MAX_BEST_NAME );
    
    
    strcopy( view_as<char>( name ), MAX_BEST_NAME, sz );
    
    
    int offset = block + OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        stages.Set( index, name[i], offset + i );
    }
}

stock void GetName( ArrayList stages, int index, int block, int mode, int style, int name[MAX_BEST_NAME_CELL] )
{
    int offset = block + OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        name[i] = stages.Get( index, offset + i );
    }
}*/

stock int FindClientCPByNum( int client, int num )
{
    int len = GetArrayLength_Safe( g_hClientCP[client] );
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hClientCP[client].Get( i, CCP_NUM ) == num )
        {
            return i;
        }
    }

    return -1;
}

// NATIVES
public int Native_SaveClientCP( Handle hPlugin, int nParms )
{
    SaveClientCP( GetNativeCell( 1 ), GetNativeCell( 2 ) );
    
    return 1;
}

public int Native_AddCP( Handle hPlugin, int nParms )
{
    decl String:szName[MAX_CP_NAME];
    
    int runid = GetNativeCell( 1 );
    int cpnum = GetNativeCell( 2 );
    
    GetNativeString( 3, szName, sizeof( szName ) );
    
    
    AddCP( runid, cpnum, szName );
    
    return 1;
}

public int Native_PrintCPTimes( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    int uid = GetNativeCell( 2 );
    int mapid = GetNativeCell( 3 );
    int runid = GetNativeCell( 4 );
    int mode = GetNativeCell( 5 );
    int style = GetNativeCell( 6 );
    
    
    DB_PrintCPTimes( client, uid, mapid, runid, mode, style );
    
    return 1;
}

public int Native_GetClientLastCPTouch( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastTouch[client] );
}

public int Native_GetClientLastCPTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastCPTime[client] );
}

public int Native_GetClientLastCPBestTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flLastCPBestTime[client] );
}