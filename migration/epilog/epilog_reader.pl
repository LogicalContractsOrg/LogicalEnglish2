/** <module> Epilog, read: sentences as Prolog terms

    The front end of the Epilog -> Logical English translator (Phase 2d,
    the design notes roadmap.md §5.7). Epilog's own parser (EpilogJS,
    through tools/epilog_tool.cjs) reads the text; this module turns its
    lists into Prolog terms:

      ["rule", H, B1, ...]            rule(H, [B1, ...])        H :- B1 & ...
      ["handler", A, ["transition", C, E]]
                                      handler(A, C, E)          A :: C ==> E
      ["handler", A, E]               handler(A, true, E)       A :: E
      ["definition", F, E]            definition(F, E)          F := E
      [F, A1, ...] / "c"              fact(F(A1, ...)) / fact(c)
      ["not", P], ["and", P, ...]     not(P), and([P, ...])

    A symbol starting with an upper-case letter or `_` is a variable (one
    Prolog variable per name in a sentence); a numeral a number; anything
    else an atom (`student.major` too).
*/

:- module(epilog_reader, [
    epilog_sentences/2,      % +File, -Sentences (each Sentence-Bindings)
    epilog_node/3,           % +Args, -Dict/List, +Options
    json_term/3              % +JSON, -Term, +VarMap
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(json)).
:- use_module(library(time)).

:- dynamic here/1.
:- prolog_load_context(directory, D), retractall(here(_)), assertz(here(D)).

%!  epilog_node(+Args, -Reply, +Options) is det.
%
%   Runs tools/epilog_tool.cjs with Args; Reply is its JSON (dicts or
%   lists). Options: env([Name=Value, ...]), timeout(Seconds) (default
%   120: EpilogJS is killed after it, and the call throws).
epilog_node(Args, Reply, Options) :-
    here(H), atomic_list_concat([H, '/tools/epilog_tool.cjs'], Tool),
    ( memberchk(env(Env0), Options) -> true ; Env0 = [] ),
    ( memberchk(timeout(TO), Options) -> true ; TO = 120 ),
    findall(N=V, ( member(N, ['PATH', 'HOME', 'EPILOG_JS']), getenv(N, V) ), Inherit),
    append(Inherit, Env0, Env),
    tmp_file_stream(text, ErrF, ES0),
    setup_call_cleanup(
        ( process_create(path(node), [Tool|Args], [stdout(pipe(O)), stderr(stream(ES0)), process(P), environment(Env)]),
          close(ES0) ),
        catch(call_with_time_limit(TO, ( read_string(O, _, S), process_wait(P, St) )),
              time_limit_exceeded,
              ( catch(process_kill(P), _, true), St = timeout )),
        close(O)),
    read_file_to_string(ErrF, ES, []), delete_file(ErrF),
    (   St == exit(0) -> atom_json_dict(S, Reply, [value_string_as(atom)])
    ;   St == timeout -> throw(error(epilog_tool_timeout(Args, TO), _))
    ;   throw(error(epilog_tool_failed(Args, ES), _))
    ).

%!  epilog_sentences(+File, -Sentences) is det.
epilog_sentences(File, Sentences) :-
    epilog_node([parse, File], JSON, []),
    maplist(sentence, JSON, Sentences).

%   Bindings: Name=Var for the sentence's variables (the names Epilog wrote).
sentence(J, S-Bs) :-
    json_term(J, T, Map),
    close_map(Map, Bs),
    (   T = rule(H, B) -> S = rule(H, B)
    ;   T = handler(A, transition(C, E)) -> S = handler(A, C, E)
    ;   T = handler(A, E) -> S = handler(A, true, E)
    ;   T = definition(H, E) -> S = definition(H, E)
    ;   S = fact(T)
    ).

%!  json_term(+JSON, -Term, ?VarMap) is det.
json_term(J, T, Map) :- json_term_(J, T, Map), !.

json_term_(J, T, Map) :- is_list(J), !,
    %  (no lambdas here: yall would copy the open variable map)
    (   J = [rule, H|Bs]
    ->  json_term_(H, HT, Map), json_terms(Bs, BTs, Map), T = rule(HT, BTs)
    ;   J = [and|Ps] -> json_terms(Ps, PTs, Map), T = and(PTs)
    ;   J = [F|As], atom(F) -> json_terms(As, ATs, Map), T =.. [F|ATs]
    ;   json_terms(J, T, Map)
    ).
json_term_(A, T, Map) :- atom(A), !,
    (   atom_number(A, N) -> T = N
    ;   sub_atom(A, 0, 1, _, '.'), atom_concat('0', A, A0), atom_number(A0, N) -> T = N   % `.6`
    ;   A == '_' -> true                  % each `_` a variable of its own
    ;   sub_atom(A, 0, 1, _, C), ( C == '_' ; char_type(C, upper) )
    ->  var_of(A, Map, T)
    ;   sub_atom(A, 0, 1, _, '"'), sub_atom(A, _, 1, 0, '"') -> sub_atom(A, 1, _, 1, S0), atom_string(S0, T)
    ;   T = A
    ).
json_term_(N, N, _) :- number(N), !.
json_term_(S, T, Map) :- string(S), !, atom_string(A, S), json_term_(A, T, Map).

close_map(Map, []) :- var(Map), !.
close_map([N-V|R], [N=V|Bs]) :- close_map(R, Bs).

json_terms([], [], _).
json_terms([J|Js], [T|Ts], Map) :- json_term_(J, T, Map), json_terms(Js, Ts, Map).

var_of(Name, Map, V) :-
    (   var(Map) -> Map = [Name-V|_]
    ;   Map = [N-V0|Rest] -> ( N == Name -> V = V0 ; var_of(Name, Rest, V) )
    ).
