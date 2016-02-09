-module(aoproxy).

%% escript
-ignore_xref([
    {main, 1},
    {init, 3},
    {handle, 2},
    {terminate, 3}
]).
-export([
    main/1
]).

%% cowboy callbacks
-export([
    init/3,
    handle/2,
    terminate/3
]).

%% ===================================================================
%% API
%% ===================================================================

main(_) ->
    {ok, _} = application:ensure_all_started(?MODULE),

    Port = 8085,
	Dispatch = cowboy_router:compile([
		{'_', [
			{"/", ?MODULE, []}
		]}
	]),
	{ok, _} = cowboy:start_http(http, 1, [{port, Port}], [
		{env, [{dispatch, Dispatch}]}
	]),

    receive
        _NeverGoesHere -> ok
    end.

%% ===================================================================
%% cowboy callbacks
%% ===================================================================

init(_Transport, Req, []) ->
	{ok, Req, undefined}.

handle(Req, State) ->
	{Method, Req2} = cowboy_req:method(Req),
	{Proxy, Req3} = cowboy_req:qs_val(<<"proxy">>, Req2),
	{ok, Req4} = proxy(Method, Proxy, Req3),
	{ok, Req4, State}.

proxy(<<"GET">>, undefined, Req) ->
	cowboy_req:reply(400, [], <<"Missing proxy parameter.">>, Req);
proxy(<<"GET">>, ProxyUrl, Req) ->
    io:format("Req: ~p~n", [Req]),
    io:format("PorxyUrl: ~s~n", [ProxyUrl]),
    Request = {binary_to_list(ProxyUrl), []},
    HTTPOptions = [],
    Options = [{body_format, binary}],
    {ok, {StatusLine, Headers0, Body}} =
        httpc:request(get, Request, HTTPOptions, Options),
    Headers = [{<<"Access-Control-Allow-Origin">>, <<"*">>} | Headers0],
    {_HttpVersion, StatusCode, _ReasonPhrase} = StatusLine,
	cowboy_req:reply(StatusCode, Headers, Body, Req);
proxy(_, _, Req) ->
	%% Method not allowed.
	cowboy_req:reply(405, Req).

terminate(_Reason, _Req, _State) ->
	ok.
