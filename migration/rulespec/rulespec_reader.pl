/** <module> Reading Axiom RuleSpec modules

    A RuleSpec module (format `rulespec/v1`, Axiom Foundation; the format
    reference is the engine's docs/rulespec-format.md) is one YAML file: a
    `module` block (a summary of the provision, its citation), `imports` of
    other modules by durable identifier (`us:statutes/7/2014/e/6/A`, with an
    optional `#rule` fragment), and `rules`, each a parameter, a derived
    value, or a relation, with dated `versions` whose `formula` is written in
    a small expression language. This module reads the YAML (SWI-Prolog's
    library(yaml)), follows the imports, and parses the formulas after the
    format reference's grammar:

        expr    := 'if' expr ':' expr ('elif' expr ':' expr)* 'else' ':' expr
                 | 'match' expr ':' (pattern '=>' expr)+
                 | or
        or      := and ('or' and)*          and := cmp ('and' cmp)*
        cmp     := add (('<'|'<='|'>'|'>='|'=='|'!=') add)?
        add     := mul (('+'|'-') mul)*     mul := unary (('*'|'/') unary)*
        unary   := '-' unary | 'not' unary | primary
        primary := number | string | true | false | '(' expr ')'
                 | name '(' args ')' | name '[' expr ']' | name '.' name | name

    A formula's parse tree (parse_formula/2):

        num(N), str(S), bool(B), id(Name), call(F, Args), index(Table, E),
        field(Relation, Field), bin(Op, A, B) (+ - * /), neg(A), not(A),
        and(A, B), or(A, B), cmp(Op, A, B) (< =< > >= == \=),
        if(Cond, Then, Else), match(Subject, [Pattern-Value, ...], Default)

    lowered/3 turns a tree into the engine's own lowered form (the
    `kind:`-tagged expressions of a compiled artifact), so the gate can
    compare the two (gate.pl).
*/

:- module(rulespec_reader,
          [ corpus_root/1,          % -Dir: the normalised corpus (prepare_root.py)
            with_upload/3,          % +Files, +Roots, :Goal: modules from an upload first
            missing_import/1,       % ?Id: an import module_closure/2 did not find
            path_module_id/2,       % +File, -Id
            module_file/2,          % +Id, -File
            read_module/2,          % +Id, -Module
            module_closure/2,       % +Id, -Modules (imports first)
            parse_formula/2,        % +Text, -Tree
            formula_tokens/2,       % +Text, -Tokens
            lowered/3               % +Tree, +Kinds, -Dict
          ]).

:- use_module(library(yaml)).
:- use_module(library(dcg/basics)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- dynamic here_/1, module_cache/2, module_override/2, search_root/1, missing_import/1.
:- meta_predicate with_upload(+, +, 0).
:- prolog_load_context(directory, D), retractall(here_(_)), assertz(here_(D)).

%!  corpus_root(-Dir) is det.
corpus_root(Dir) :-
    here_(H), atomic_list_concat([H, '/.cache/root/rulespec-us'], Dir).

%!  module_file(+Id, -File) is det.
%
%   `us-co:regulations/10-ccr-2506-1/4.207.3` is
%   <root>/us-co/regulations/10-ccr-2506-1/4.207.3.yaml.
module_file(Id0, File) :-
    strip_fragment(Id0, Id),
    module_override(Id, File), !.
module_file(Id0, File) :-
    strip_fragment(Id0, Id),
    search_root(Root),
    sub_atom(Id, B, 1, A, ':'), !,
    sub_atom(Id, 0, B, _, Juris),
    sub_atom(Id, _, A, 0, Rest),
    atomic_list_concat([Root, '/', Juris, '/', Rest, '.yaml'], File),
    exists_file(File), !.
module_file(Id0, File) :-
    strip_fragment(Id0, Id),
    corpus_root(Root),
    sub_atom(Id, B, 1, A, ':'), !,
    sub_atom(Id, 0, B, _, Juris),
    sub_atom(Id, _, A, 0, Rest),
    atomic_list_concat([Root, '/', Juris, '/', Rest, '.yaml'], File).

strip_fragment(Id0, Id) :-
    atom_string(Id1, Id0),
    (   sub_atom(Id1, B, 1, _, '#') -> sub_atom(Id1, 0, B, _, Id) ; Id = Id1 ).

%!  read_module(+Id, -Module) is det.
%
%   Module = module(Id, Dict), Dict the YAML document as library(yaml) reads
%   it. Cached.
read_module(Id0, Module) :-
    strip_fragment(Id0, Id),
    (   module_cache(Id, Module) -> true
    ;   module_file(Id, File),
        (   exists_file(File) -> true
        ;   throw(error(existence_error(rulespec_module, Id), File))
        ),
        yaml_read(File, Dict),
        Module = module(Id, Dict),
        assertz(module_cache(Id, Module))
    ).

%!  module_closure(+Id, -Modules) is det.
%
%   The module and every module it imports, directly or not, each once,
%   an imported module before the modules that import it.
module_closure(Id, Modules) :-
    closure([Id], [], [], Rev),
    reverse(Rev, Modules).

closure([], _, Acc, Acc).
closure([Id0|Ids], Seen, Acc0, Acc) :-
    strip_fragment(Id0, Id),
    (   memberchk(Id, Seen)
    ->  closure(Ids, Seen, Acc0, Acc)
    ;   Seen \== [], \+ catch(read_module(Id, _), error(existence_error(rulespec_module, _), _), fail)
    ->  ( missing_import(Id) -> true ; assertz(missing_import(Id)) ),
        closure(Ids, [Id|Seen], Acc0, Acc)
    ;   read_module(Id, M),
        imports(M, Imps),
        closure(Imps, [Id|Seen], Acc0, Acc1),
        findall(I, member(I, Acc1), _),
        (   member(module(Id, _), Acc1) -> Acc2 = Acc1 ; Acc2 = [M|Acc1] ),
        module_ids(Acc2, Seen2),
        closure(Ids, [Id|Seen2], Acc2, Acc)
    ).

module_ids(Ms, Ids) :- findall(I, member(module(I, _), Ms), Ids).

%!  with_upload(+Files, +Roots, :Goal) is semidet.
%
%   Run Goal with the modules of an upload in front of the corpus: Files
%   (Id-File pairs, for files whose identifier is not their path) and Roots
%   (folders laid out as a country checkout, `us/statutes/...`). The cache of
%   read modules and the list of missing imports start empty and are emptied
%   again after.
with_upload(Files, Roots, Goal) :-
    setup_call_cleanup(
        ( retractall(module_cache(_, _)), retractall(missing_import(_)),
          forall(member(I-F, Files), assertz(module_override(I, F))),
          forall(member(R, Roots), assertz(search_root(R))) ),
        Goal,
        ( retractall(module_override(_, _)), retractall(search_root(_)),
          retractall(module_cache(_, _)) )).

%!  path_module_id(+File, -Id) is semidet.
%
%   The durable identifier a file's path gives it: .../us/statutes/7/2017/a.yaml
%   is us:statutes/7/2017/a (a jurisdiction folder, then one of the four
%   roots RuleSpec loads modules from).
path_module_id(File, Id) :-
    atomic_list_concat(Parts, '/', File),
    append(_, [J, Root|Rest], Parts),
    ( J == us ; sub_atom(J, 0, 3, _, 'us-') ; atom_length(J, 2) ),
    memberchk(Root, [statutes, regulations, policies, legislation]),
    Rest \== [], !,
    append(Dirs, [Last], Rest),
    file_name_extension(Stem, yaml, Last),
    append([Root|Dirs], [Stem], Ps),
    atomic_list_concat(Ps, '/', R),
    atomic_list_concat([J, ':', R], Id).

imports(module(_, D), Imps) :-
    (   get_dict(imports, D, L), is_list(L) -> Imps = L ; Imps = [] ).


		 /*******************************
		 *            TOKENS            *
		 *******************************/

%!  formula_tokens(+Text, -Tokens) is det.
formula_tokens(Text, Tokens) :-
    (   string(Text) -> string_codes(Text, Cs)
    ;   number(Text) -> number_codes(Text, Cs)
    ;   atom_codes(Text, Cs)
    ),
    (   phrase(tokens(Tokens), Cs) -> true
    ;   throw(error(syntax_error(rulespec_tokens), Text))
    ).

tokens(Ts) --> blanks_or_comments, ( eos -> { Ts = [] } ; token(T), { Ts = [T|Ts1] }, tokens(Ts1) ).

blanks_or_comments --> blank, !, blanks_or_comments.
blanks_or_comments --> "#", !, skip_line, blanks_or_comments.
blanks_or_comments --> [].

skip_line --> "\n", !.
skip_line --> [_], !, skip_line.
skip_line --> [].

token(T) --> number_token(T), !.
token(str(S)) --> "\"", !, string_without("\"", Cs), "\"", { string_codes(S, Cs) }.
token(str(S)) --> "'", !, string_without("'", Cs), "'", { string_codes(S, Cs) }.
token(T) --> name_start(C), !, name_rest(Cs), { atom_codes(A, [C|Cs]), word_token(A, T) }.
token(p(P)) --> punct(P).

number_token(num(N)) -->
    digits1(I), ( ".", digits1(F) -> { append(I, [0'.|F], Cs) } ; { Cs = I } ),
    { number_codes(N, Cs) }.
number_token(num(N)) -->
    ".", digits1(F), { number_codes(N, [0'0, 0'.|F]) }.

digits1([D|Ds]) --> digit(D), digits(Ds).

%   A name's letters: any letter of any alphabet, a digit after the first
%   character, and the underscore. (`csym` and `csymf` are not used: SWI-Prolog
%   10 stopped counting an accented letter among them, which would cut a
%   French name — `résidence` — in two.)
name_start(C) --> [C], { name_code(C) }.
name_rest([C|Cs]) --> [C], { name_code(C) -> true ; code_type(C, digit) }, !, name_rest(Cs).
name_rest([]) --> [].

name_code(C) :- C =:= 0'_, !.
name_code(C) :- code_type(C, alpha), \+ code_type(C, digit).

word_token(true, bool(true)) :- !.
word_token(false, bool(false)) :- !.
word_token(W, kw(W)) :- memberchk(W, [if, elif, else, match, and, or, not]), !.
word_token(A, id(A)).

punct('=>') --> "=>", !.
punct('<=') --> "<=", !.
punct('>=') --> ">=", !.
punct('==') --> "==", !.
punct('!=') --> "!=", !.
punct(P) --> [C], { memberchk(C, `()[],:.+-*/<>_`), atom_codes(P, [C]) }.


		 /*******************************
		 *            PARSER            *
		 *******************************/

%!  parse_formula(+Text, -Tree) is det.
%
%   Throws error(syntax_error(rulespec_formula(Rest)), Text) when the text
%   is not a formula.
parse_formula(N, num(N)) :- number(N), !.        % `formula: 150000`, a YAML number
parse_formula(Text, Tree) :-
    formula_tokens(Text, Ts),
    (   phrase(expr(Tree), Ts, Rest), Rest == []
    ->  true
    ;   phrase(expr(_), Ts, Rest1)
    ->  throw(error(syntax_error(rulespec_formula(Rest1)), Text))
    ;   throw(error(syntax_error(rulespec_formula(Ts)), Text))
    ).

expr(if(C, T, E)) --> [kw(if)], !, expr(C), [p(:)], expr(T), elifs(E).
expr(match(S, Arms, D)) --> [kw(match)], !, expr(S), [p(:)], arms(Arms, D).
expr(E) --> or(E).

elifs(if(C, T, E)) --> [kw(elif)], !, expr(C), [p(:)], expr(T), elifs(E).
elifs(E) --> [kw(else), p(:)], !, expr(E).
elifs(nomatch) --> [].          % (no else: no value in the other cases; Catala's lowering writes it)

arms([], D) --> [id('_'), p('=>')], !, expr(D).
arms([P-V|As], D) --> pattern(P), [p('=>')], expr(V), ( arms_follow -> arms(As, D) ; { As = [], D = none } ).

arms_follow, [T, p('=>')] --> [T, p('=>')], !.
arms_follow, [p(-), T, p('=>')] --> [p(-), T, p('=>')].

pattern(num(N)) --> [num(N)], !.
pattern(num(N)) --> [p(-), num(N0)], !, { N is -N0 }.
pattern(str(S)) --> [str(S)], !.
pattern(bool(B)) --> [bool(B)], !.
pattern(id(A)) --> [id(A)].

or(E) --> and(A), or_rest(A, E).
or_rest(A, E) --> [kw(or)], !, and(B), or_rest(or(A, B), E).
or_rest(E, E) --> [].

and(E) --> cmp(A), and_rest(A, E).
and_rest(A, E) --> [kw(and)], !, cmp(B), and_rest(and(A, B), E).
and_rest(E, E) --> [].

cmp(E) --> add(A), ( [p(Op0)], { cmp_op(Op0, Op) } -> add(B), { E = cmp(Op, A, B) } ; { E = A } ).

cmp_op(<, <).
cmp_op('<=', =<).
cmp_op(>, >).
cmp_op('>=', >=).
cmp_op('==', ==).
cmp_op('!=', \=).

add(E) --> mul(A), add_rest(A, E).
add_rest(A, E) --> [p(Op)], { memberchk(Op, [+, -]) }, !, mul(B), add_rest(bin(Op, A, B), E).
add_rest(E, E) --> [].

mul(E) --> unary(A), mul_rest(A, E).
mul_rest(A, E) --> [p(Op)], { memberchk(Op, [*, /]) }, !, unary(B), mul_rest(bin(Op, A, B), E).
mul_rest(E, E) --> [].

unary(neg(E)) --> [p(-)], !, unary(E).
unary(not(E)) --> [kw(not)], !, unary(E).
unary(E) --> primary(E).

primary(num(N)) --> [num(N)], !.
primary(str(S)) --> [str(S)], !.
primary(bool(B)) --> [bool(B)], !.
primary(E) --> [p('(')], !, expr(E), [p(')')].
primary(E) --> [kw(K)], { memberchk(K, [if, match]) }, !, expr(E).
primary(E) --> [id(F)], ( [p('(')] -> args(As), [p(')')], { E = call(F, As) }
                        ; [p('[')] -> expr(I), [p(']')], { E = index(F, I) }
                          %  a value read through a relation, and one read
                          %  through a relation at a period: the OpenFisca
                          %  reader writes `member_of_foyer_fiscal.at_period(
                          %  rev_coll, years_before(period, 2))` for the
                          %  collective income of a member's tax household
                          %  two years before, and this grammar could read
                          %  only the first form
                        ; [p('.'), id(G)] -> ( [p('(')] -> args(As2), [p(')')],
                                               { E = field(F, call(G, As2)) }
                                             ; { E = field(F, G) } )
                        ; { E = id(F) } ).

args([A|As]) --> expr(A), !, args_rest(As).
args([]) --> [].
args_rest([A|As]) --> [p(',')], !, expr(A), args_rest(As).
args_rest([]) --> [].


		 /*******************************
		 *     THE ENGINE'S LOWERING    *
		 *******************************/

%!  lowered(+Tree, +Kinds, -Dict) is det.
%
%   The engine's lowered expression (docs/rulespec-format.md, "The lowered
%   expression vocabulary") for a parse tree, as a dict shaped like the
%   compiled artifact's JSON, so gate.pl can compare them. Kinds tells how a
%   name resolves: kind(Name, K), K one of parameter, derived, judgment
%   (a derived judgment), relation, input.
%
%   Position (scalar or judgment) decides how a bare name lowers, as the
%   loader does: in judgment position a name that is not a derived judgment
%   is a Boolean input compared with `true`.
lowered(Tree, Kinds, D) :- low(scalar, Tree, Kinds, D).

low(judgment, and(A, B), K, _{kind:"and", items:[LA, LB]}) :- !, low(judgment, A, K, LA), low(judgment, B, K, LB).
low(judgment, or(A, B), K, _{kind:"or", items:[LA, LB]}) :- !, low(judgment, A, K, LA), low(judgment, B, K, LB).
low(judgment, not(A), K, _{kind:"not", expr:LA}) :- !, low(judgment, A, K, LA).
low(_, cmp(Op, A, B), K, _{kind:"comparison", op:O, left:LA, right:LB}) :- !,
    op_name(Op, O), low(scalar, A, K, LA), low(scalar, B, K, LB).
low(judgment, id(N), K, D) :- !,
    (   memberchk(kind(N, judgment), K)
    ->  D = _{kind:"derived", name:N}
    ;   D = _{kind:"comparison", op:"eq", left:_{kind:"input", name:N},
              right:_{kind:"literal", value:_{kind:"bool", value:true}}}
    ).
low(judgment, call(exactly_one, As), K, _{kind:"exactly_one", items:Ls}) :- !,
    lows(judgment, As, K, Ls).
low(scalar, num(N), _, _{kind:"literal", value:V}) :- !,
    ( integer(N) -> V = _{kind:"integer", value:N} ; V = _{kind:"decimal", value:N} ).
low(scalar, str(S), _, _{kind:"literal", value:_{kind:"text", value:S}}) :- !.
low(scalar, bool(B), _, _{kind:"literal", value:_{kind:"bool", value:B}}) :- !.
low(scalar, id(period_start), _, _{kind:"period_start"}) :- !.
low(scalar, id(period_end), _, _{kind:"period_end"}) :- !.
low(scalar, id(N), K, D) :- !,
    (   memberchk(kind(N, parameter), K) -> D = _{kind:"parameter_lookup", name:N}
    ;   ( memberchk(kind(N, derived), K) ; memberchk(kind(N, judgment), K) ) -> D = _{kind:"derived", name:N}
    ;   D = _{kind:"input", name:N}
    ).
low(scalar, index(T, I), K, _{kind:"parameter_lookup", name:T, index:LI}) :- !, low(scalar, I, K, LI).
low(scalar, bin(Op, A, B), K, _{kind:Kd, left:LA, right:LB}) :- !,
    bin_name(Op, Kd), low(scalar, A, K, LA), low(scalar, B, K, LB).
low(scalar, neg(A), K, _{kind:"sub", left:_{kind:"literal", value:_{kind:"integer", value:0}}, right:LA}) :- !,
    low(scalar, A, K, LA).
low(scalar, if(C, T, E), K, _{kind:"if", condition:LC, then_expr:LT, else_expr:LE}) :- !,
    low(judgment, C, K, LC), low(scalar, T, K, LT), low(scalar, E, K, LE).
low(scalar, match(S, Arms, Def), K, D) :- !,
    match_to_if(S, Arms, Def, If), low(scalar, If, K, D).
low(scalar, call(F, As), K, D) :- !,
    lows(scalar, As, K, Ls),
    D = _{kind:F, items:Ls}.
low(scalar, field(R, F), _, _{kind:"field", relation:R, field:F}) :- !.
low(P, T, _, _{kind:"unknown", position:P, tree:S}) :- term_string(T, S).

lows(_, [], _, []).
lows(P, [A|As], K, [L|Ls]) :- low(P, A, K, L), lows(P, As, K, Ls).

match_to_if(_, [], none, call(no_match, [])) :- !.
match_to_if(_, [], D, D) :- !.
match_to_if(S, [P-V|As], D, if(cmp(==, S, P), V, E)) :- match_to_if(S, As, D, E).

op_name(<, "lt").
op_name(=<, "lte").
op_name(>, "gt").
op_name(>=, "gte").
op_name(==, "eq").
op_name(\=, "ne").

bin_name(+, "add").
bin_name(-, "sub").
bin_name(*, "mul").
bin_name(/, "div").
