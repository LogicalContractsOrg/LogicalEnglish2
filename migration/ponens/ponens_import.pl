/** <module> File ▸ Open and Export for Ponens policies

    The adapter of le_importers.pl (LE2's le_import registry):

      - File ▸ Open of a Ponens policy (`gallery/policies/<id>.json`), a list
        of policies (`ponens trace check --policy-file` reads one), or a
        Ponens trace that carries its policies (`"policies": [...]`): the
        policies as a program of Logical English for LPS (ponens_twin.pl).
        A trace is also the program's scenario, when the `ponens` package is
        installed (ponens_reading.py reads the trace as Ponens does);
        without it the program has no scenario, and a note says so.
      - Export to Another System… ▸ Ponens: a program whose laws record
        breaches (`the policy P is broken at step S`) as Ponens policies
        (ponens_writer.pl), one JSON list, ready for `ponens trace check
        --policy-file`. A law the writer cannot read back is a problem, at
        the line of the law, and the export is refused with it.

    Each policy written carries `le_source`: the lines of the program it was
    read from (its law, and the named conditions the law asks), as
    `"Logical English line 74"` or `"Logical English lines 74, 80"`. JSON has
    no comments; Ponens reads a policy file's policies by key (`policy_id`,
    `name`, `formula`, `severity`, …: trace.py, `--policy-file`) and its
    schema (trace.v1_15.json, `$defs/policy`) does not forbid other keys —
    ponens_build.pl's files already carry `oracle` and `reasoner` — so an
    extra key is read past. The import side (input_policies/2) ignores it
    too.
*/

:- module(ponens_import, [import_ponens/3, import_ponens/4, detect_ponens/1,
                          export_ponens/3, applies_ponens/1]).

:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- use_module(ponens_formula).
:- use_module(ponens_twin).
:- use_module(ponens_writer).

%!  detect_ponens(+Input) is semidet.
%   A JSON file holding Ponens policies, or a trace with its policies.
detect_ponens(Input) :-
    catch(read_json(Input, D), _, fail),
    input_policies(D, Ps), Ps \== [].

read_json(File, Dict) :-
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       json_read_dict(In, Dict, [default_tag(json)]),
                       close(In)).

%   The policies of a file, in the gallery's shape (id, formula, severity…).
input_policies(D, Ps) :-
    (   is_list(D) -> Ps0 = D
    ;   is_dict(D), get_dict(policies, D, L), is_list(L) -> Ps0 = L
    ;   is_dict(D), get_dict(formula, D, _) -> Ps0 = [D]
    ;   Ps0 = []
    ),
    include([P]>>( is_dict(P), get_dict(formula, P, F), string(F) ), Ps0, Ps1),
    maplist(gallery_shape, Ps1, Ps).

gallery_shape(P, G) :-
    (   get_dict(id, P, Id) -> true
    ;   get_dict(policy_id, P, Id) -> true
    ;   get_dict(name, P, Id)
    ),
    G0 = P.put(id, Id),
    (   get_dict(name, G0, _) -> G1 = G0 ; G1 = G0.put(name, Id) ),
    (   get_dict(rationale, G1, _) -> G = G1
    ;   get_dict(description, G1, Ds) -> G = G1.put(rationale, Ds)
    ;   G = G1
    ).

import_ponens(Input, OutDir, Result) :- import_ponens(Input, OutDir, [], Result).

import_ponens(Input, OutDir0, _Options, imported(LEFile, Notes)) :-
    absolute_file_name(OutDir0, OutDir),
    read_json(Input, D),
    input_policies(D, Policies),
    file_base_name(Input, Base), file_name_extension(Name0, _, Base),
    atomic_list_concat(Parts, '-', Name0), atomic_list_concat(Parts, '_', Name),
    atomic_list_concat([OutDir, '/sources'], SD), make_directory_path(SD),
    atomic_list_concat([SD, '/', Base], Copy), copy_file(Input, Copy),
    (   is_dict(D), get_dict(actions, D, As), As \== []
    ->  pack_atoms(Policies, Atoms),
        (   catch(trace_reading(Input, Atoms, Reading), _, fail)
        ->  Traces = [trace(Name, Input, Reading, [])],
            TNote = "The trace is the program's scenario: press Run, and each breach is on the timeline at the step where its policy failed."
        ;   Traces = [],
            TNote = "The trace is not a scenario here: reading it as Ponens does needs Ponens's own package (pip install ponens), which this server does not have."
        )
    ;   Traces = [], TNote = "No trace came with the policies: add a scenario, one event per fact of each step, to run them."
    ),
    twin_text(Name, Policies, Traces, twin(Text, Ledger)),
    atomic_list_concat([OutDir, '/', Name, '.le'], LEFile),
    setup_call_cleanup(open(LEFile, write, Out, [encoding(utf8)]), write(Out, Text), close(Out)),
    include([E]>>(get_dict(verdict, E, residue)), Ledger, Res), length(Res, NR),
    length(Policies, NP),
    format(string(N1), "~w Ponens policies, each a law that records a breach; ~w kept as residue (formulas that Ponens's own parser cannot read, or that this translator does not cover: the comment at each formula says which).", [NP, NR]),
    Notes = [N1, TNote].

		 /*******************************
		 *	      the way back		*
		 *******************************/

%!  applies_ponens(+KB) is semidet.
%   A program for LPS whose laws record breaches of policies.
applies_ponens(KB) :-
    catch(le_writer:kb_to_ir(KB, program(H, _)), _, fail),
    memberchk(target(lps), H),
    %   the fluent of a breach, named after its template here (`known as
    %   broken_at` names it in the program's LPS form only)
    catch(( KB:le_dict(dict([F|_], _, _, _, _, _, _)),
            memberchk(F, [the_policy_is_broken_at_step, the_policy_is_broken, broken_at, broken]) ), _, fail), !.

%!  export_ponens(+KB, +Options, -Result) is det.
export_ponens(KB, Options, Result) :-
    ( memberchk(text(Doc), Options) -> true ; Doc = "" ),
    le_lps:le_lps_module(KB, Doc, Internal, Prov, _),
    term_string_terms(Internal, Terms),
    terms_policies(Terms, Doc, Policies0),
    findall(problem(W, M),
            ( member(P, Policies0), get_dict(formula, P, F),
              ( F == '' ; sub_atom(F, _, _, _, '"') ),
              format(string(M), "The law of the policy ~w cannot be written as a Ponens formula.", [P.policy_id]),
              %  at each law of the policy (a law is a sentence of its own)
              law_terms(Terms, P.policy_id, Ks),
              findall(line(L), ( member(K, Ks), term_line(Prov, K, L) ), Ws0),
              ( Ws0 == [] -> Ws = [none] ; Ws = Ws0 ),
              member(W, Ws) ),
            Problems),
    maplist(policy_source(Terms, Prov), Policies0, Policies),
    (   Problems \== []
    ->  Result = refused(Problems)
    ;   with_output_to(string(Text), json_write_dict(current_output, Policies, [width(100)])),
        length(Policies, N),
        format(string(Note), "~w policies, ready for: ponens trace check TRACE.json --policy-file policies.json", [N]),
        Result = exported('policies.json', Text, [Note], [])
    ).

%   The terms (by index, from 0) of the laws that record a breach of the
%   policy Id.
law_terms(Terms, Id0, Ks) :-
    atom_string(Id, Id0),
    findall(K, ( nth0(K, Terms, initiated(happens(E, _, _), F, _)),
                 memberchk(E, [step_ends(_), session_ends]),
                 ( F = broken_at(I, _) ; F = broken(I) ), atom(I), I == Id ), Ks).

%   The terms of the named conditions a law asks (`step S meets "…"`), and
%   of those they ask in turn.
condition_terms(Terms, Ks0, Ks) :-
    findall(N, ( member(K, Ks0), nth0(K, Terms, T), condition_name(T, N) ), Ns0),
    sort(Ns0, Ns),
    findall(K, ( nth0(K, Terms, l_int(holds(H, _), _)), \+ memberchk(K, Ks0),
                 defined_name(H, N), memberchk(N, Ns) ), New0),
    sort(New0, New),
    (   New == [] -> Ks = Ks0
    ;   append(Ks0, New, Ks1), condition_terms(Terms, Ks1, Ks)
    ).

condition_name(T, N) :- sub_term(X, T), compound(X), ( X = meets(_, N) ; X = trace_meets(N) ; X = meets_with(_, N, _) ), nonvar(N).
defined_name(meets(_, N), N).
defined_name(trace_meets(N), N).
defined_name(meets_with(_, N, _), N).

term_line(Prov, K, L) :- memberchk(prov(K, L, _), Prov), integer(L), L > 0.

%   A policy with the lines it was read from (le_source).
policy_source(Terms, Prov, P0, P) :-
    law_terms(Terms, P0.policy_id, Ks0),
    condition_terms(Terms, Ks0, Ks),
    findall(L, ( member(K, Ks), term_line(Prov, K, L) ), Ls0), sort(Ls0, Ls),
    (   Ls == [] -> P = P0
    ;   Ls = [L] -> format(string(S), "Logical English line ~w", [L]), P = P0.put(le_source, S)
    ;   atomic_list_concat(Ls, ', ', LT), format(string(S), "Logical English lines ~w", [LT]), P = P0.put(le_source, S)
    ).

term_string_terms(Text, Terms) :-
    setup_call_cleanup(open_string(Text, In), read_all(In, Terms), close(In)).

read_all(In, Ts) :-
    catch(read_term(In, T, []), _, T = end_of_file),
    ( T == end_of_file -> Ts = [] ; Ts = [T|Ts1], read_all(In, Ts1) ).
