/** <module> One twin of a Ponens pack, from the command line

    Called by ponens_gate.py and by the build of the published twins:

        swipl -g "use_module('migration/ponens/ponens_build'), \
                  build_twin(GalleryDir, Pack, TracesJson, OutLe, OutLedger), halt."

    TracesJson is a list of {"name": ..., "file": ..., "verdicts": ...}: each
    trace, the scenario name it gets, and the file of Ponens's verdicts on it
    (`ponens trace check --policy-file … --json`), or null. OutLedger gets
    the ledger as JSON (counts and entries, the format of the other
    migrations' ledgers) and, beside it, as Markdown.
*/

:- module(ponens_build, [build_twin/5, write_policy_file/3]).

:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(ponens_twin).

build_twin(Gallery, Pack0, TracesJson, OutLe, OutLedger) :-
    atom_string(Pack, Pack0),
    load_policies(Gallery, All),
    once(pack_policies(All, Pack, Policies)),
    pack_atoms(Policies, Atoms),
    read_json(TracesJson, Specs),
    maplist(trace_of(Atoms), Specs, Traces),
    twin_text(Pack, Policies, Traces, twin(Text, Ledger)),
    write_text(OutLe, Text),
    ledger_files(Ledger, OutLedger).

trace_of(Atoms, Spec, trace(Name, File, Reading, Verdicts)) :-
    atom_string(Name, Spec.name), atom_string(File, Spec.file),
    trace_reading(File, Atoms, Reading),
    (   V = Spec.get(verdicts), V \== null, atom_string(VF, V), exists_file(VF)
    ->  read_json(VF, Verdicts0), ( is_list(Verdicts0) -> Verdicts = Verdicts0 ; Verdicts = [] )
    ;   Verdicts = []
    ).

%!  write_policy_file(+Gallery, +Pack, +File) is det.
%   The pack's policies as one JSON list (what `ponens trace check
%   --policy-file` reads).
write_policy_file(Gallery, Pack0, File) :-
    atom_string(Pack, Pack0),
    load_policies(Gallery, All),
    once(pack_policies(All, Pack, Policies)),
    maplist(trace_policy, Policies, TPs),
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, TPs, [width(0)]),
                       close(Out)).

%   A gallery policy as a trace's policy (Ponens POLICY_SPEC: policy_id, and
%   the name its structural policies are known by, which is the id).
trace_policy(P, TP) :-
    TP0 = _{policy_id: P.id, name: P.id, severity: P.get(severity, "error"),
            scope: "trace", kind: "trace_invariant", formula: P.get(formula, ""),
            description: P.get(description, "")},
    (   get_dict(oracle, P, O) -> TP1 = TP0.put(oracle, O) ; TP1 = TP0 ),
    (   get_dict(reasoner, P, R) -> TP = TP1.put(reasoner, R) ; TP = TP1 ).


read_json(File, Dict) :-
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       json_read_dict(In, Dict, [default_tag(json)]),
                       close(In)).

write_text(File, Text) :-
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]), write(Out, Text), close(Out)).

ledger_files(Entries, JsonFile) :-
    foldl(count_verdict, Entries, _{encoded: 0, approximated: 0, residue: 0}, Counts),
    setup_call_cleanup(open(JsonFile, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, _{counts: Counts, entries: Entries}, [width(100)]),
                       close(Out)),
    file_name_extension(Base, json, JsonFile),
    file_name_extension(Base, md, MdFile),
    setup_call_cleanup(open(MdFile, write, Md, [encoding(utf8)]),
                       ( format(Md, "# Ledger~n~nOne row per policy of the pack: how the twin encodes it.~n~n", []),
                         format(Md, "Encoded: ~w · approximated: ~w · residue: ~w~n~n", [Counts.encoded, Counts.approximated, Counts.residue]),
                         format(Md, "| Policy | Severity | Verdict | How | Note |~n|---|---|---|---|---|~n", []),
                         forall(member(E, Entries),
                                format(Md, "| `~w` | ~w | ~w | ~w | ~w |~n", [E.element, E.kind, E.verdict, E.mapping, E.note])) ),
                       close(Md)).

count_verdict(E, C0, C) :-
    V = E.verdict, N0 = C0.get(V, 0), N is N0 + 1, C = C0.put(V, N).
