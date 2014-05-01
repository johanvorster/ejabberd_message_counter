%% name of module must match file name
-module(mod_message_counter).
 
-author("Johan Vorster").
 
%% Every ejabberd module implements the gen_mod behavior
%% The gen_mod behavior requires two functions: start/2 and stop/1
-behaviour(gen_mod).
 
%% public methods for this module
-export([start/2, stop/1, send_packet/3]).
 
%% included for writing to ejabberd log file
-include("ejabberd.hrl").

-record(message_counter, {yearweeknum, count}).

start(_Host, _Opt) -> 

        ?INFO_MSG("mod_message_counter loading", []),

        mnesia:create_table(message_counter, 
           [{attributes, record_info(fields, message_counter)}]),
        ?INFO_MSG("mod_message_counter: created message counter table", []),
        
        ejabberd_hooks:add(user_send_packet, _Host, ?MODULE, send_packet, 50),   
        ?INFO_MSG("mod_message_counter: start user_send_packet hook", []).

stop(_Host) -> 
        ?INFO_MSG("mod_message_counter: stopping mod_confirm_delivery", []),
        
        ejabberd_hooks:delete(user_send_packet, _Host, ?MODULE, send_packet, 50),
        ?INFO_MSG("mod_message_counter: stop user_send_packet hook", []).

send_packet(From, To, Packet) ->    
    ?INFO_MSG("mod_message_counter: end_packet FromJID ~p ToJID ~p Packet ~p~n",[From, To, Packet]),

    Type = xml:get_tag_attr_s("type", Packet),
    ?INFO_MSG("mod_message_counter: Message Type ~p~n",[Type]),

    Body = xml:get_path_s(Packet, [{elem, "body"}, cdata]), 
    ?INFO_MSG("mod_message_counter: Message Body ~p~n",[Body]),  

    ?INFO_MSG("mod_message_counter: From ~p~n",[From]),    
    LUser = element(2, From),
    ?INFO_MSG("mod_message_counter: From -> LUser ~p~n",[LUser]),    

    %%checking to see if the message was send by a user or admin
    FromMessage = string:str(LUser, "admin"),
    ?INFO_MSG("mod_message_counter: Admin JID ~p~n",[FromMessage]),   

    if FromMessage == 0 ->
        FromCounter = "AllUserAccount";
    true ->
        FromCounter = "AdminAccount"
    end,
    ?INFO_MSG("mod_message_counter: From User Counter ~p~n",[FromCounter]),

    case Type =:= "chat" andalso Body =/= [] of
        true ->        
        %%Need to compile per server. Found that Mnesia data replication isn't very reliable.
        ServerName = "server1.xmpp.com",      

        Year_Week_Num = calendar:iso_week_number(),
        ?INFO_MSG("mod_message_counter: Year_Week_Num ~p~n",[Year_Week_Num]),

        Year_Week_Num_Server_From = {Year_Week_Num, ServerName, FromCounter},

        Week_Info = mnesia:dirty_read(message_counter, Year_Week_Num_Server_From),
        ?INFO_MSG("Year Week Number and Count: ~p~n",[Year_Week_Num_Server_From]),

        if Week_Info =/= [] ->
            ets:update_counter(message_counter, Year_Week_Num_Server_From, 1),
            ?INFO_MSG("Override message_counter yearweeknum ~p ~n",[Year_Week_Num_Server_From]);
        true ->
            F = fun() ->
                mnesia:write(#message_counter{yearweeknum=Year_Week_Num_Server_From, count=1})
            end,
            mnesia:transaction(F),
            ?INFO_MSG("Saving new message_counter yearweeknum ~p count 0 ~n",[Year_Week_Num_Server_From])
        end;
       
    _ ->
        ok
    end.  
