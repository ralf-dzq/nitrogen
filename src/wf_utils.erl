-module (wf_utils).
-include ("wf.inc").
-export ([
	f/1, f/2,
	id/0, guid/0, short_guid/0,
	path_search/3,
	encode/2, decode/2,
	hex_encode/1, hex_decode/1,
	pickle/1, depickle/1, depickle/2,
	url_encode/1,
	js_escape/1,
	path_to_module/1,
	replace/3,
	coalesce/1,
	is_process_alive/1
]).

%%% FORMAT %%%

f(S) -> f(S, []).
f(S, Args) -> lists:flatten(io_lib:format(S, Args)).


%%% IDS %%%

% id/0 - Return the next digit in an incremental counter.
id() -> mnesia:dirty_update_counter(counter, id, 1).

% guid/0 - Return a guid like object.
guid() ->
	MD5 = erlang:md5(term_to_binary(make_ref())),
	MD5List = lists:nthtail(8, binary_to_list(MD5)),
	F = fun(N) -> wf:f("~2.16.0B", [N]) end,
	L = [F(N) || N <- MD5List],
	lists:flatten(L).

% short_guid/0 - Return a shorter guid like object.
short_guid() ->
	MD5 = erlang:md5(term_to_binary(make_ref())),
	MD5List = lists:nthtail(14, binary_to_list(MD5)),
	F = fun(N) -> wf:f("~2.16.0B", [N]) end,
	L = [F(N) || N <- MD5List],
	lists:flatten(L).

is_process_alive(Pid) ->
	is_pid(Pid) andalso rpc:call(node(Pid), erlang, is_process_alive, [Pid]).


%%% XPATH STYLE QUERY LOOKUPS %%%

% path_search/2 - search for part of a specified path within a list of paths.
% Partial = [atom3, atom2, atom1]
% Paths=[[atom3, atom2, atom1], [atom5, atom4...]]
% Conducts 
path_search(Partial, N, Paths) -> path_search(Partial, N, Paths, 1).
path_search(_, _, [], _) -> [];
path_search([], _, Paths, _) -> Paths;
path_search(['*'], _, Paths, _) -> Paths;
path_search(_, _, _, 10) -> [];
path_search(['*'|T], N, Paths, Pos) ->
	% We have a wildcard so everything matches. 
	% Split into two new searches.
	path_search(['*'|T], N, Paths, Pos + 1) ++ path_search(T, N, Paths, Pos + 1);

path_search([H|T], N, Paths, Pos) ->
	% Return all Paths for which H matches the Nth element.
	F = fun(Tuple) -> 
		Path = erlang:element(N, Tuple),
		(Pos =< length(Path)) andalso (H == lists:nth(Pos, Path)) 
	end,
	Paths1 = lists:filter(F, Paths),
	path_search(T, N, Paths1, Pos + 1).

%%% HEX ENCODE and HEX DECODE

hex_encode(Data) -> encode(Data, 16).
hex_decode(Data) -> decode(Data, 16).

encode(Data, Base) when is_binary(Data) -> encode(binary_to_list(Data), Base);
encode(Data, Base) when is_list(Data) ->
	F = fun(C) when is_integer(C) ->
		case erlang:integer_to_list(C, Base) of
			[C1, C2] -> <<C1, C2>>;
			[C1]     -> <<$0, C1>>;
			_        -> throw("Could not hex_encode the string.")
		end
	end,
	{ok, list_to_binary([F(I) || I <- Data])}.
	
decode(Data, Base) when is_binary(Data) -> decode(binary_to_list(Data), Base);
decode(Data, Base) when is_list(Data) -> 	
	{ok, list_to_binary(inner_decode(Data, Base))}.

inner_decode(Data, Base) when is_list(Data) ->
	case Data of
		[C1, C2|Rest] -> 
			I = erlang:list_to_integer([C1, C2], Base),
			[I|inner_decode(Rest, Base)];
			
		[] -> 
			[];
			
		_  -> 
			throw("Could not hex_decode the string.")
	end.
	
%%% PICKLE / UNPICKLE %%%

get_seconds() -> calendar:datetime_to_gregorian_seconds(calendar:universal_time()).

pickle(Data) ->
	B = term_to_binary({get_seconds(), Data}, [compressed]),
	<<Signature:4/binary, _/binary>> = erlang:md5([B, wf_global:sign_key()]),
	modified_base64_encode(<<Signature/binary, B/binary>>).
	
depickle(Data) -> 
	{_IsExpired, Term} = depickle(Data, 24 * 365 * 60 * 60),
	Term.
	
depickle(Data, SecondsToLive) ->
	{CreatedOn, Term} = try
		<<S:4/binary, B/binary>> = modified_base64_decode(wf:to_binary(Data)),
		<<Signature:4/binary, _/binary>> = erlang:md5([B, wf_global:sign_key()]),
		wf:assert(S == Signature, invalid_signature),
		binary_to_term(B)
	catch _Type : _Message ->
		%?PRINT({Type, Message}),
		{0, undefined}
	end,
	IsExpired = (CreatedOn + SecondsToLive) < get_seconds(),
	{not IsExpired, Term}.
	
% modified_base64_encode/1 
%	- Replace '+' and '/' with '-' and '_', respectively. 
% - Strip '='.
modified_base64_encode(B) -> m_b64_e(base64:encode(B), <<>>).
m_b64_e(<<>>, Acc) -> Acc;
m_b64_e(<<$+, Rest/binary>>, Acc) -> m_b64_e(Rest, <<Acc/binary, $->>);
m_b64_e(<<$/, Rest/binary>>, Acc) -> m_b64_e(Rest, <<Acc/binary, $_>>);
m_b64_e(<<$=, Rest/binary>>, Acc) -> m_b64_e(Rest, Acc);
m_b64_e(<<H,  Rest/binary>>, Acc) -> m_b64_e(Rest, <<Acc/binary, H>>).
		
% modified_base64_decode/1 
% - Replace '-' and '_' with '+' and '/', respectively. 
% - Pad with '=' to a multiple of 4 chars.
modified_base64_decode(B) -> base64:decode(m_b64_d(B, <<>>)).
m_b64_d(<<>>, Acc) when size(Acc) rem 4 == 0 -> Acc;
m_b64_d(<<>>, Acc) when size(Acc) rem 4 /= 0 -> m_b64_d(<<>>, <<Acc/binary, $=>>);
m_b64_d(<<$-, Rest/binary>>, Acc) -> m_b64_d(Rest, <<Acc/binary, $+>>);
m_b64_d(<<$_, Rest/binary>>, Acc) -> m_b64_d(Rest, <<Acc/binary, $/>>);
m_b64_d(<<H,  Rest/binary>>, Acc) -> m_b64_d(Rest, <<Acc/binary, H>>).
	
%%% URL ENCODE %%%

url_encode(S) -> mochiweb_util:quote_plus(S).

%%% ESCAPE JAVASCRIPT %%%

js_escape(undefined) -> [];
js_escape(Value) when is_list(Value) -> binary_to_list(js_escape(list_to_binary(lists:flatten(Value))));
js_escape(Value) -> js_escape(Value, <<>>).
js_escape(<<"\\", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\\\">>);
js_escape(<<"\r", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\r">>);
js_escape(<<"\n", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\n">>);
js_escape(<<"\"", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\\"">>);
js_escape(<<"<script", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "<scr\" + \"ipt">>);
js_escape(<<"script>", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "scr\" + \"ipt>">>);
js_escape(<<C, Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, C>>);
js_escape(<<>>, Acc) -> Acc.

%%% MODULE PATH %%%

%% path_to_module/1 - Convert a web path to a module.
path_to_module(undefined) -> web_index;
path_to_module(S) ->
	case hd(lists:reverse(S)) of
		$/ -> 
			path_to_module(S ++ "index");
		_ ->
			list_to_atom(string:join(string:tokens(S, "/"), "_"))
	end.


%%% STRING REPLACE %%%

replace([], _, _) -> [];
replace(String, S1, S2) when is_list(String), is_list(S1), is_list(S2) ->
	Length = length(S1),
	case string:substr(String, 1, Length) of 
		S1 -> 
			S2 ++ replace(string:substr(String, Length + 1), S1, S2);
		_ -> 
			[hd(String)|replace(tl(String), S1, S2)]
	end.
	
%%% COALESCE %%%

coalesce([]) -> undefined;
coalesce([H]) -> H;
coalesce([undefined|T]) -> coalesce(T);
coalesce([[]|T]) -> coalesce(T);
coalesce([H|_]) -> H.

		
%%% DEBUG %%%
		
debug() ->
	% Get all web and wf modules.
	F = fun(X) ->
		{value, {source, Path}} = lists:keysearch(source, 1, X:module_info(compile)), Path
	end,

	L =  [list_to_binary(atom_to_list(X)) || X <- erlang:loaded()],
	ModulePaths = 
		[F(wf)] ++
		[F(list_to_atom(binary_to_list(X))) || <<"web_", _/binary>>=X <- L] ++
		[F(list_to_atom(binary_to_list(X))) || <<"wf_", _/binary>>=X <- L],
	
	i:im(),
	i:ii(ModulePaths),
	
	i:iaa([break]),
	i:ib(?MODULE, break, 0).

break() -> ok.