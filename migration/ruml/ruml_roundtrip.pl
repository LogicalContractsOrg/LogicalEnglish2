/*  The way back checked (the design notes ruml.md §10, step 6).

        swipl -q migration/ruml/ruml_roundtrip.pl              everything
        swipl -q migration/ruml/ruml_roundtrip.pl -- twins     the RUML twins only

    Run from the LE2 checkout. Three sets of programs, each exported to RUML
    (ruml_export.pl):

    1. The RUML twins (LE2 examples/migration/ruml/): each comes back. The
       exported rulemap and the original are evaluated by the oracle on the
       original's generated cases; every node of the same label must have
       the same result. The rulemap must be valid (the published schema and
       the reader's checks).
    2. LE2's own programs (the .le files under examples/regulatory and examples/moreExamples):
       how many export and how many are refused, and why.
    3. The twins of the other doors (LE2 examples/migration/<source>/, DMN
       first): the same counts. A program that exports is a way from that
       system into RUML, through Logical English.

    Results: runs/roundtrip.txt.
*/

:- use_module('../le2_paths', [le2_dir/1]).
:- use_module(le2(le_kbs)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(http/json)).
:- use_module(library(time)).
:- use_module(ruml_export).
:- use_module(ruml_reader).
:- use_module(ruml_cases).
:- use_module(ruml_paths).
:- use_module(gate, [schema_verdicts/3]).

:- initialization(main, main).

here(D) :- prolog_load_context(directory, D0) -> D = D0 ; D = 'migration/ruml'.
:- dynamic dir/1.
:- prolog_load_context(directory, D), assertz(dir(D)).

main :-
    current_prolog_flag(argv, Argv),
    dir(D), atomic_list_concat([D, '/runs/roundtrip.txt'], Log),
    atomic_list_concat([D, '/runs/exports'], XD), make_directory_path(XD),
    setup_call_cleanup(open(Log, write, Out),
        (   twins(Out, XD),
            (   Argv = [twins] -> true
            ;   le2_dir(L2),
                atomic_list_concat([L2, '/examples/regulatory'], Reg),
                atomic_list_concat([L2, '/examples/moreExamples'], More),
                programs(Out, XD, "LE2's own programs (examples/regulatory, examples/moreExamples)", [Reg, More]),
                atomic_list_concat([L2, '/examples/migration/dmn'], Dmn),
                programs(Out, XD, "The DMN twins (LE2 examples/migration/dmn)", [Dmn]),
                forall(member(Src, [oia, catala, rulespec, l4, legalruleml, blawx, scasp, oipa, miniscript]),
                       ( atomic_list_concat([L2, '/examples/migration/', Src], SD),
                         ( exists_directory(SD) -> format(string(T), "The ~w twins (LE2 examples/migration/~w)", [Src, Src]), programs(Out, XD, T, [SD]) ; true ) ))
            )
        ),
        close(Out)).

load_program(File, KB, Text) :-
    read_file_to_string(File, Text, []), file_directory_name(File, Dir),
    le_kbs:set_le_issue_reporting(false),
    catch(le_kbs:load_text(Text, Dir, KB), _, fail),
    le_kbs:set_le_issue_reporting(true).

export(File, Result) :-
    (   load_program(File, KB, Text)
    ->  file_directory_name(File, Dir),
        (   catch(call_with_time_limit(60, export_ruml(KB, [text(Text), base(Dir)], R0)), E, ( format(string(M), "~q", [E]), R0 = error(M) ))
        ->  Result = R0
        ;   Result = error("the exporter failed")
        )
    ;   Result = error("does not load")
    ).

		 /*******************************
		 *           THE TWINS          *
		 *******************************/

twins(Out, XD) :-
    le2_dir(L2), atomic_list_concat([L2, '/examples/migration/ruml'], Root),
    findall(F, ( directory_member(Root, F, [recursive(true), extensions([le])]), \+ sub_atom(F, _, _, _, '/sources/') ), Fs0), msort(Fs0, Fs),
    format(Out, "## The RUML twins: export, then the oracle on the original's generated cases~n~n", []),
    foldl(twin(Out, XD), Fs, t(0, 0, 0, 0, [])-t(0, 0), t(N, Ex, Same, Cases, Files)-t(NS, NT)),
    schema_verdicts(ruml, Files, SV), include([_-V]>>(V == valid), SV, Valid), length(Valid, NV), length(Files, NF),
    forall(member(F-invalid(E), SV), format(Out, "INVALID ~w ~q~n", [F, E])),
    format(Out, "~nTOTAL twins: ~d, exported ~d, valid ~d of ~d; same results as the original in ~d of ~d twins (~d cases; ~d of ~d node results)~n~n",
           [N, Ex, NV, NF, Same, Ex, Cases, NS, NT]),
    format("twins: ~d, exported ~d, valid ~d of ~d; same results in ~d of ~d (~d of ~d node results)~n", [N, Ex, NV, NF, Same, Ex, NS, NT]).

twin(Out, XD, File, t(N0, E0, S0, C0, Fs0)-t(NS0, NT0), t(N, E, S, C, Fs)-t(NS, NT)) :-
    N is N0 + 1,
    file_base_name(File, B),
    export(File, R),
    (   R = exported(_, Text, _, _)
    ->  E is E0 + 1,
        atomic_list_concat([XD, '/', B, '.ruml'], XF),
        setup_call_cleanup(open(XF, write, O, [encoding(utf8)]), write(O, Text), close(O)),
        Fs = [XF|Fs0],
        file_directory_name(File, Dir), atomic_list_concat([Dir, '/sources'], SD),
        (   directory_member(SD, Orig, [extensions([ruml])])
        ->  compare_twin(Orig, XF, NCase, Agree, Total, Diffs),
            NS is NS0 + Agree, NT is NT0 + Total, C is C0 + NCase,
            (   Agree =:= Total -> S is S0 + 1, format(Out, "same  ~w  (~d cases, ~d node results)~n", [B, NCase, Total])
            ;   nondeterministic(Orig) -> S is S0 + 1, format(Out, "same, but for $random  ~w  ~d of ~d: two runs of the oracle differ too~n", [B, Agree, Total])
            ;   S = S0, format(Out, "DIFF  ~w  ~d of ~d: ~w~n", [B, Agree, Total, Diffs])
            )
        ;   S = S0, NS = NS0, NT = NT0, C = C0, format(Out, "no original  ~w~n", [B])
        )
    ;   E = E0, S = S0, C = C0, Fs = Fs0, NS = NS0, NT = NT0,
        format(Out, "NOT EXPORTED  ~w  ~q~n", [B, R])
    ).

%   The oracle on both, case by case; a node's result compared by label.
compare_twin(Orig, Exported, NCase, Agree, Total, Diffs) :-
    ruml_read_file(Orig, OD, _), ruml_read_file(Exported, ED, _),
    case_inputs(OD, Inputs),
    findall(case(Id, '', In, []), ( nth1(I, Inputs, In-_), format(atom(Id), 'c~d', [I]) ), Cases),
    length(Cases, NCase),
    oracle_results(Orig, Cases, complete, R1), oracle_results(Exported, Cases, complete, R2),
    findall(ok-x, ( member(Id-P1, R1), memberchk(Id-P2, R2), labelled(OD, P1, L1), labelled(ED, P2, L2),
                    member(Lab-S, L1), memberchk(Lab-S2, L2), ( S == S2 -> true ; fail ) ), Oks),
    findall(Id-Lab-S-S2, ( member(Id-P1, R1), memberchk(Id-P2, R2), labelled(OD, P1, L1), labelled(ED, P2, L2),
                    member(Lab-S, L1), memberchk(Lab-S2, L2), S \== S2 ), Diffs0),
    length(Oks, Agree), length(Diffs0, ND), Total is Agree + ND,
    ( Diffs0 = [D1|_] -> Diffs = [D1] ; Diffs = [] ).

%   Label-Status at the shallowest path of each label (a recursive node's
%   deepest round is undefined by the depth limit).
labelled(Doc, PRs, LS) :-
    findall(Lab-(D-S), ( member(P-(L-S), PRs), node(Doc, L, N), j(N, label, Lab0), label_key(Lab0, Lab),
                         atomic_list_concat(Ps, '.', P), length(Ps, D) ), LS0),
    keysort(LS0, LS1), group_pairs_by_key(LS1, G),
    findall(Lab-S, ( member(Lab-DSs, G), msort(DSs, [_-S|_]) ), LS).
label_key(L, K) :- ruml_names:label_text(L, K).

		 /*******************************
		 *        OTHER PROGRAMS        *
		 *******************************/

programs(Out, XD, Title, Dirs) :-
    findall(F, ( member(D, Dirs), directory_member(D, F, [recursive(true), extensions([le])]),
                 \+ sub_atom(F, _, _, _, '/sources/'), \+ sub_atom(F, _, _, _, '.original.'),
                 %  the programs LE2's own suite leaves out without le_extensions.pl
                 \+ extension_dependent(F) ), Fs0),
    msort(Fs0, Fs),
    format(Out, "## ~w~n~n", [Title]),
    foldl(program(Out, XD), Fs, 0-0-[]-[], Ex-Ref-Files-Reasons),
    length(Fs, N),
    schema_verdicts(ruml, Files, SV), include([_-V]>>(V == valid), SV, Valid), length(Valid, NV), length(Files, NF),
    forall(member(F-invalid(E), SV), format(Out, "INVALID ~w ~q~n", [F, E])),
    msort(Reasons, RS), clumped(RS, RC), sort(2, @>=, RC, RCs),
    format(Out, "~nTOTAL ~w: ~d programs, ~d exported (valid ~d of ~d), ~d refused~n", [Title, N, Ex, NV, NF, Ref]),
    forall(member(R-K, RCs), format(Out, "    refused ~d times: ~w~n", [K, R])),
    nl(Out),
    format("~w: ~d programs, ~d exported (valid ~d of ~d), ~d refused~n", [Title, N, Ex, NV, NF, Ref]).

program(Out, XD, File, E0-R0-Fs0-Rs0, E-R-Fs-Rs) :-
    file_base_name(File, B),
    export(File, Res),
    (   Res = exported(_, Text, _, _)
    ->  E is E0 + 1, R = R0, Rs = Rs0,
        atomic_list_concat([XD, '/', B, '.ruml'], XF),
        setup_call_cleanup(open(XF, write, O, [encoding(utf8)]), write(O, Text), close(O)),
        Fs = [XF|Fs0], format(Out, "exported  ~w~n", [File])
    ;   Res = refused([problem(_, M)|_])
    ->  E = E0, R is R0 + 1, Fs = Fs0, reason_kind(M, K), Rs = [K|Rs0],
        format(Out, "refused   ~w  ~w~n", [File, M])
    ;   E = E0, R is R0 + 1, Fs = Fs0, Rs = ["does not load or no root"|Rs0],
        format(Out, "refused   ~w  ~q~n", [File, Res])
    ).

%   The first words of a refusal, to count the reasons.
reason_kind(M, K) :-
    split_string(M, ":", "", [K0|_]),
    ( sub_string(K0, 0, 60, _, K1) -> true ; K1 = K0 ),
    ( sub_string(K1, B, _, _, "`") -> sub_string(K1, 0, B, _, K2), string_concat(K2, "...", K) ; K = K1 ).

%   As le_kbs's own suite decides: the path in small letters holds one of
%   its fragments.
extension_dependent(F) :-
    downcase_atom(F, L),
    catch(le_kbs:extension_dependent_path_fragment(Frag), _, fail), sub_atom(L, _, _, _, Frag), !.

%   A rulemap whose expressions draw random numbers or read the clock: no
%   two evaluations need agree (§3.6.4, OP-05).
nondeterministic(File) :-
    read_file_to_string(File, S, []),
    ( sub_string(S, _, _, _, "$random(") ; sub_string(S, _, _, _, "$now(") ; sub_string(S, _, _, _, "$millis(") ), !.
