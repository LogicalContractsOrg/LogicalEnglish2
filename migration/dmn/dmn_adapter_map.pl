/** <module> The adapter's mapping of a DMN twin (<twin>.adapter_map.json)

    The DMN adapter (dmn_adapter.pl) answers the callers of a DMN engine
    (Kogito, KIE Server, Camunda 7 and 8) from the model's Logical English
    twin. It needs to know, for every name a caller sends or expects back,
    which sentence of the twin says it: the mapping file, in the common
    format of LE2's adapter kit (le_adapter.pl; LE2
    docs/user/integrations/adapters.md). The translator knows this when it
    writes the twin, so it writes the mapping beside it:

        adapter_map(+File, +Program, -Map)

    called right after dmn_twin:model_migration/3 on File, while the
    translator's symbols (dmn_twin:sym/2) and items (dmn_twin:out/1) are
    those of this model.

    One attribute per input and per decision of the model, named as the
    model names it:

      - a value (`the age is *a number*`): kind `value`;
      - a structure: kind `structure`, its components attributes of their
        own (`the points of the driver is *a number*`);
      - a list of values: kind `list`, the template `the X include *a
        text*` and the sentence `the X are listed`;
      - a list of structures: kind `records`, a template with a place per
        component, in order.

    A decision whose table's single output has a name of its own (Camunda's
    `desiredDish` for the decision Dish) has that name as an alias. The
    `dmn` part keeps what the engines' replies name: the model's namespace,
    each decision's id, its kind of logic, hit policy, outputs and rules.
*/

:- module(dmn_adapter_map, [adapter_map/3, write_adapter_map/3]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(http/json)).
:- use_module(dmn_reader).
:- use_module(dmn_twin).

%!  write_adapter_map(+File, +Dir, +Program) is det.
write_adapter_map(File, Dir, Program) :-
    adapter_map(File, Program, Map),
    atomic_list_concat([Dir, '/', Program, '.adapter_map.json'], Out),
    setup_call_cleanup(open(Out, write, S, [encoding(utf8)]),
                       json_write_dict(S, Map, [width(100)]),
                       close(S)).

%!  adapter_map(+File, +Program, -Map) is det.
adapter_map(File, Program, Map) :-
    dmn_read_file(File, model(Info, Items)),
    memberchk(name(MName), Info), memberchk(namespace(NS), Info),
    findall(A, input_attribute(Items, A), Inputs),
    findall(A, decision_attribute(Items, A), Decisions),
    implicit_inputs(Items, Inputs, Decisions, Implicit),
    append([Inputs, Implicit, Decisions], Attrs),
    findall(D, decision_info(Items, D), DInfos),
    findall(_{id: Id, name: N, typeRef: T}, member(input(Id, N, T, _), Items), InInfos),
    findall(_{id: Id, name: N, outputs: Os, encapsulated: Es},
            ( member(service(Id, N, Outs, Enc, _, _), Items),
              maplist(href_name(Items), Outs, Os), maplist(href_name(Items), Enc, Es) ), Services),
    file_base_name(File, Base),
    atom_string(Program, ProgS), atom_string(MName, MNameS),
    sort([MNameS, ProgS], Names),
    Map = _{format: "le-adapter-map/1",
            source: "DMN",
            title: MNameS,
            project: MNameS,
            deployments: Names,
            twin: ProgS,
            current_date_template: null,
            entities: [],
            attributes: Attrs,
            dmn: _{namespace: NS, name: MNameS, file: Base,
                   inputs: InInfos, decisions: DInfos, services: Services}}.

href_name(Items, H, N) :-
    dmn_href_id(H, Id),
    (   member(decision(Id, N, _, _, _, _), Items) -> true
    ;   member(input(Id, N, _, _), Items) -> true
    ;   N = Id
    ).

input_attribute(Items, A) :-
    member(input(_, N, _, _), Items),
    \+ dmn_twin:fixed_sym(N),
    dmn_twin:sym(N, S),
    attribute(N, S, A0), A = A0.put(_{role: "input", derived: false, goal: false, output: null}).

decision_attribute(Items, A) :-
    member(decision(Id, N, _, _, Logic, _), Items),
    dmn_twin:sym(N, S),
    attribute(N, S, A0),
    findall(AN, ( alias_of(Logic, N, S, AN0), atom_string(AN0, AN) ), Aliases),
    (   required_by_other(Items, Id) -> Goal = false ; Goal = true ),
    A1 = A0.put(_{role: "decision", derived: true, goal: Goal, output: "contract", aliases: Aliases}),
    %  a context's value is an object even when its entries are null; a
    %  table that matches nothing is null
    (   A1.kind == "structure", Logic \= table(_, _, _, _, _)
    ->  A = A1.put(null_when_empty, false)
    ;   A = A1
    ).

%   The output's name of a table of one output, when the twin reads it as
%   the decision (dmn_twin:declare_implicit/1).
alias_of(table(_, _, _, [out(ON, _, _, _)], _), N, S, ON) :-
    ON \== '', ON \== N, dmn_twin:sym(ON, S2), S2 == S.

required_by_other(Items, Id) :-
    member(decision(_, _, _, reqs(Ds, _, _), _, _), Items),
    member(H, Ds), dmn_href_id(H, Id), !.

%   The names the tables read that the model does not declare (Camunda's
%   process variables): inputs too.
implicit_inputs(_Items, Inputs, Decisions, Implicit) :-
    findall(N, ( member(A, Inputs) ; member(A, Decisions) ), _),
    findall(NS, ( member(A, Inputs), NS = A.name ), INs),
    findall(NS, ( member(A, Decisions), ( NS = A.name ; member(NS, A.aliases) ) ), DNs),
    findall(A, ( dmn_twin:sym(N, S), atom(N), \+ sub_atom(N, 0, _, _, '$'),
                 S \= bkm(_, _), \+ dmn_twin:fixed_sym(N),
                 atom_string(N, NStr), \+ memberchk(NStr, INs), \+ memberchk(NStr, DNs),
                 \+ ( member(A0, Decisions), sym_of_attr(A0, S) ),
                 attribute(N, S, A1),
                 A = A1.put(_{role: "input", derived: false, goal: false, output: null}) ), Implicit0),
    sort(name, @<, Implicit0, Implicit).

sym_of_attr(A, S) :- dmn_twin:sym(N, S), atom_string(N, A.name), !.

%   The attribute of a name of the model, by the shape of its symbol.
attribute(N, val(F, Noun), _{name: NS, key: NS, text: NS, kind: "value", type: T,
                            display: Tmpl, template: Tmpl, opposite: null, entity: "global"}) :- !,
    atom_string(N, NS), noun_type(Noun, T), function_text(F, Tmpl).
attribute(N, struct(Comps), _{name: NS, key: NS, text: NS, kind: "structure", type: "structure",
                              components: Cs, entity: "global"}) :- !,
    atom_string(N, NS),
    findall(C, ( member(CN, Comps), CN = CN0-CS, attribute(CN0, CS, C) ), Cs).
attribute(N, rel(F, [Noun]), _{name: NS, key: NS, text: NS, kind: "list", type: T,
                               template: Tmpl, listed: Listed, entity: "global"}) :- !,
    atom_string(N, NS), noun_type(Noun, T), template_text(F, Tmpl), listed_text(F, Listed).
attribute(N, rel(F, Nouns, Names), _{name: NS, key: NS, text: NS, kind: "records", type: "records",
                                     template: Tmpl, listed: Listed, components: Cs, entity: "global"}) :- !,
    atom_string(N, NS), template_text(F, Tmpl), listed_text(F, Listed),
    findall(_{name: CS, type: CT}, ( nth1(I, Names, CN), nth1(I, Nouns, CNoun),
                                     atom_string(CN, CS), noun_type(CNoun, CT) ), Cs).

noun_type(number, "number") :- !.
noun_type(text, "string") :- !.
noun_type('truth value', "boolean") :- !.
noun_type(date, "date") :- !.
noun_type(_, "any").

function_text(F, T) :- once(( dmn_twin:out(I), sub_term(function(F, T0), I) )), atom_string(T0, T).
template_text(F, T) :- once(( dmn_twin:out(I), sub_term(template(F, T0, _), I) )), atom_string(T0, T).
listed_text(F, T) :- dmn_twin:rel_listed(F, LF), template_text(LF, T), !.
listed_text(_, null).

decision_info(Items, D) :-
    member(decision(Id, N, _, reqs(Rs, _, _), Logic, _), Items),
    maplist(href_name(Items), Rs, Req),
    logic_info(Logic, Kind, Extra),
    D = _{id: Id, name: N, logic: Kind, required: Req}.put(Extra).

logic_info(table(Hit, Agg, Ins, Outs, Rules), "DECISION_TABLE",
           _{hitPolicy: HP, aggregation: AG, inputs: IJs, outputs: OJs, rules: RJs}) :- !,
    upcase_atom(Hit, HP), upcase_atom(Agg, AG),
    findall(_{index: I, text: X}, nth1(I, Ins, in(X, _, _)), IJs),
    findall(_{index: I, name: ON}, nth1(I, Outs, out(ON, _, _, _)), OJs),
    findall(_{index: I, id: RId, inputs: ITs, outputs: OTs},
            nth1(I, Rules, rule(RId, ITs, OTs, _)), RJs).
logic_info(literal(_), "LITERAL_EXPRESSION", _{}) :- !.
logic_info(Logic, K, _{}) :- functor(Logic, F, _), upcase_atom(F, K).
