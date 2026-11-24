/** <module> Solidity -> Logical English for LPS: the front end

    Phase 1e of the design notes roadmap.md (§6.0-6.1).
    Reads the compact typed AST that solcjs produces (solc_ast.js), and
    translates one contract — its linearised inheritance, modifiers inlined,
    internal calls inlined, `super` resolved — into the LPS internal term set
    of docs/dev/le-lps-interface.md, with a template dictionary, as the Migration
    IR (target lps) that le_writer.pl writes as Logical English.

    ## The method: one law per path

    Every public or external function that changes state is executed
    symbolically. A PATH is a sequence of branch decisions ending in success
    or in a revert; along it the executor collects the conditions of the
    branches taken (over the parameters, the caller and the state as it was
    before the call) and the storage writes, in order.

      - a revert path is an integrity constraint on the call:
            it must not be true that <the call> and <the path's conditions>
        (LPS refuses the whole event: the revert semantics, E13);
      - a success path gives, for each write, a causal law
            when <the call> and <the path's own branch conditions>
            then <the fluent> that is Old becomes <expression>
        — the conditions that only select against a revert (`require`) are
        not repeated: a call that would revert never happens.

    Storage is a set of fluents: `uint x` is `the x is *an amount*`,
    `mapping(address => uint) balances` is `the balance of *an account* is
    *an amount*`, a nested mapping has one argument per key, a `bool` (or a
    mapping to `bool`) is a proposition (`*an account* is blacklisted`), an
    `address` or a `string` holds one value.

    ## Solidity's zero default, and atomicity (E13)

    A mapping entry never written reads as zero. The twin says so once, on
    the fluent: `the balance of *an account* is *an amount*; 0 by default`
    (an address, the zero address by default) — the design notes roadmap.md
    Phase 1e (a). LPS2 then reads an entry with no stored fact as holding its
    default, and an update of it reads the default as its old value; LPS2
    applies each update of an action to the state produced so far (serial
    micro-states), so two writes of one call to one entry (a transfer to
    oneself) compose in order, as in the EVM. Every law of a path carries the
    same conditions, so a successful call fires all of them; a failing one is
    refused by a constraint before any fires. (See README.md, "E13".)
    Before defaults existed, each write was preceded by a law that
    materialised the default and each read split into a present and an
    absent variant: 86 of the ERC-20 twin's 181 lines.

    ## Loops over arrays (Phase 1e (d))

    A `for (uint i = 0; i < xs.length; i++)` over an array parameter is
    executed once, with `xs[i]` an element of the list (el(loop(P))), and
    summarised by pattern:
      - a `+=` / `-=` on an entry keyed by the element (a batch write): one
        law for each key in the list, by the total of its occurrences — `the
        balance of an account that is N becomes N + amount * the count of the
        account in the list` — so a key listed twice gets both;
      - a `+=` / `-=` on anything else, or on a local (a reduction): by the
        sum over the elements;
      - a `require` / `revert` inside it: a constraint that some element of
        the list would fail it;
      - `xs.length`: the count of the list's elements.
    Anything else inside a loop (a write that depends on the order, a branch,
    a second array indexed by `i`, a loop over storage) stays residue.

    ## Named constants

    `type(uint256).max` and `constant` state variables are named values
    (`the constants are:`, Phase 1e (e)): the name is read where the value
    is used, its wording from sol_names:constant_name/3.

    ## Wording

    Template wording comes from a naming table (sol_names.pl): the reviewed
    wording of the reference models (E11), and a mechanical fallback from the
    identifiers otherwise — recorded in the ledger as wording to review.
*/

:- module(sol_front, [
    sol_load/2,              % +JSONFile, -Model(Index module)
    sol_contract/3,          % +Model, +ContractName, -Contract
    sol_paths/3,             % +Contract, +FunctionName, -Paths
    sol_twin/4,              % +Contract, +Options, -IR, -Ledger
    sol_translate/5,         % +SolFiles, +ContractName, +Options, -IR, -Ledger
    sol_compile/2,           % +SolFiles, -JSONFile
    sol_mutation/1
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(option)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(utf8)).
:- use_module(sol_names).
:- use_module(sol_prune).

:- dynamic node/3.          % node(Model, Id, Dict)
:- dynamic sol_mutation/1.  % sol_mutation(no_default): a deliberately wrong twin, for the replay's negative control
:- dynamic contract_node/3. % contract_node(Model, Name, Dict)
:- dynamic source_text/3.   % source_text(Model, Index, Text)
:- dynamic constant_used/3. % constant_used(Functor, Name, Value): the named constants a twin reads
:- dynamic unchecked_site/3.% unchecked_site(Function, Src, Reason): an `unchecked` block and the comment in it

		 /*******************************
		 *          LOADING             *
		 *******************************/

:- dynamic sol_dir/1.
:- prolog_load_context(directory, D), retractall(sol_dir(_)), assertz(sol_dir(D)).

%!  sol_compile(+SolFiles, -JSONFile) is det.
%
%   Runs solc_ast.js (solcjs) over the sources; JSONFile holds its output.
sol_compile(Files, JSON) :-
    sol_dir(Dir),
    atomic_list_concat([Dir, '/solc_ast.js'], Script),
    tmp_file_stream(text, JSON, S0), close(S0),
    maplist([F, A]>>absolute_file_name(F, A), Files, Abs),
    setup_call_cleanup(
        open(JSON, write, Out),
        process_create(path(node), [Script|Abs],
                       [cwd(Dir), stdout(stream(Out)), stderr(pipe(Err)), process(Pid)]),
        close(Out)),
    read_string(Err, _, ErrText), close(Err),
    process_wait(Pid, Status),
    (   Status == exit(0) -> true
    ;   throw(error(solidity_compile_failed(ErrText), _))
    ).

%!  sol_load(+JSONFile, -Model) is det.
sol_load(File, Model) :-
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       json_read_dict(In, D, [value_string_as(atom)]),
                       close(In)),
    variant_sha1(File, H), sub_atom(H, 0, 10, _, H10),
    atom_concat(solm_, H10, Model),
    retractall(node(Model, _, _)), retractall(contract_node(Model, _, _)),
    retractall(source_text(Model, _, _)),
    retractall(unchecked_site(_, _, _)),
    (   get_dict(texts, D, Ts)
    ->  dict_pairs(Ts, _, TPs),
        forall(member(K-T, TPs), ( atom_number(K, I), atom_string(T, TS), assertz(source_text(Model, I, TS)) ))
    ;   true
    ),
    dict_pairs(D.sources, _, Srcs),
    forall(member(_-Ast, Srcs), index_nodes(Model, Ast)).

index_nodes(Model, D) :-
    (   is_dict(D)
    ->  (   get_dict(id, D, Id), integer(Id)
        ->  assertz(node(Model, Id, D)),
            (   get_dict(nodeType, D, 'ContractDefinition')
            ->  assertz(contract_node(Model, D.name, D))
            ;   true
            )
        ;   true
        ),
        dict_pairs(D, _, Ps),
        forall(member(_-V, Ps), index_nodes(Model, V))
    ;   is_list(D)
    ->  forall(member(X, D), index_nodes(Model, X))
    ;   true
    ).

		 /*******************************
		 *      THE CONTRACT MODEL      *
		 *******************************/

%   contract(Model, Name, Linearization, StateVars, Functions, Modifiers)
%     StateVars: sv(Id, Name, Kind, Init, DeclaringContract)
%       Kind: uint | bool | address | string | map(Keys, ValueKind)
%     Functions: fn(Id, Name, Kind, Visibility, Mutability, ContractId, Dict)
sol_contract(Model, Name, contract(Model, Name, Lin, SVs, Fns, Mods)) :-
    contract_node(Model, Name, C), !,
    Lin = C.linearizedBaseContracts,
    reverse(Lin, BaseFirst),
    findall(SV, ( member(CId, BaseFirst), node(Model, CId, CD),
                  member(N, CD.nodes), N.nodeType == 'VariableDeclaration',
                  N.get(stateVariable) == true,
                  \+ memberchk(N.get(mutability), [constant, immutable]),
                  state_var(N, CId, SV) ), SVs),
    findall(fn(Id, FName, Kind, Vis, Mut, CId, N),
            ( member(CId, Lin), node(Model, CId, CD),
              member(N, CD.nodes), N.nodeType == 'FunctionDefinition',
              Id = N.id, FName = N.name, Kind = N.kind,
              Vis = N.visibility, Mut = N.stateMutability ),
            Fns),
    findall(md(MId, MName, CId, N),
            ( member(CId, Lin), node(Model, CId, CD),
              member(N, CD.nodes), N.nodeType == 'ModifierDefinition',
              get_dict(id, N, MId), get_dict(name, N, MName) ),
            Mods).
sol_contract(_, Name, _) :-
    throw(error(existence_error(solidity_contract, Name), _)).

state_var(N, CId, sv(N.id, N.name, Kind, Init, CId)) :-
    type_kind(N.typeName, Kind),
    ( get_dict(value, N, V), V \== null -> Init = V ; Init = none ).

type_kind(T, Kind) :-
    (   T.nodeType == 'Mapping'
    ->  key_info(T.keyType, T.get(keyName, ''), K),
        type_kind(T.valueType, VK0),
        (   VK0 = map(Ks, VK) -> Kind = map([K|Ks], VK) ; Kind = map([K], VK0) )
    ;   T.nodeType == 'ElementaryTypeName'
    ->  elementary_kind(T.name, Kind)
    ;   T.nodeType == 'UserDefinedTypeName',
        get_dict(typeDescriptions, T, TD), get_dict(typeString, TD, TS),
        ( sub_atom(TS, 0, _, _, 'contract ') ; sub_atom(TS, 0, _, _, 'interface ') )
    ->  Kind = address                       % a contract is held by its address
    ;   Kind = other(T.nodeType)
    ).

key_info(KT, KeyName, key(Name, Kind)) :-
    ( KT.nodeType == 'ElementaryTypeName' -> elementary_kind(KT.name, Kind) ; Kind = other ),
    ( KeyName == '' -> Name = none ; Name = KeyName ).

elementary_kind(N, uint) :- sub_atom(N, 0, _, _, uint), !.
elementary_kind(N, uint) :- sub_atom(N, 0, _, _, int), !.
elementary_kind(bool, bool) :- !.
elementary_kind(address, address) :- !.
elementary_kind('address payable', address) :- !.
elementary_kind(string, string) :- !.
elementary_kind(N, other(N)).

sv_by_id(contract(_, _, _, SVs, _, _), Id, SV) :-
    member(SV, SVs), SV = sv(Id, _, _, _, _), !.

		 /*******************************
		 *     FUNCTION RESOLUTION      *
		 *******************************/

%   The most derived function of this name and parameter types, from the
%   position After in the linearisation onwards (`super` starts after the
%   calling function's contract).
resolve_fn(Contract, DeclId, From, Fn) :-
    Contract = contract(Model, _, Lin, _, Fns, _),
    node(Model, DeclId, D),
    D.nodeType == 'FunctionDefinition',
    fn_signature(D, Sig),
    Name = D.name,
    (   From == top -> Lin1 = Lin
    ;   append(_, [From|Lin1], Lin) -> true
    ;   Lin1 = Lin
    ),
    member(CId, Lin1),
    member(Fn, Fns), Fn = fn(_, Name, _, _, _, CId, FD),
    fn_signature(FD, Sig), !.

param_ids(D, Ids) :-
    get_dict(parameters, D, PL), get_dict(parameters, PL, Ps),
    findall(Id, ( member(P, Ps), get_dict(id, P, Id) ), Ids).

fn_signature(D, Sig) :-
    findall(T, ( member(P, D.parameters.parameters),
                 T = P.typeDescriptions.typeString ), Sig).

resolve_modifier(Contract, DeclId, Md) :-
    Contract = contract(Model, _, Lin, _, _, Mods),
    node(Model, DeclId, D), Name = D.name,
    member(CId, Lin), member(Md, Mods), Md = md(_, Name, CId, _), !.

public_functions(contract(_, _, _, _, Fns, _), Pub) :-
    findall(Name-Fn, ( member(Fn, Fns), Fn = fn(_, Name, function, Vis, Mut, _, D),
                       memberchk(Vis, [public, external]),
                       get_dict(body, D, B), B \== null,
                       Mut \== view, Mut \== pure ), All),
    %  the most derived definition of each name (Fns is most derived first)
    findall(Fn, ( member(Name-Fn, All), \+ ( member(Name-F2, All), F2 \== Fn, before(F2, Fn, All) ) ), Pub0),
    list_to_set(Pub0, Pub).

before(X, Y, L) :- nth1(I, L, _-X), nth1(J, L, _-Y), I < J.

view_functions(contract(_, _, _, _, Fns, _), Views) :-
    findall(Fn, ( member(Fn, Fns), Fn = fn(_, _, function, Vis, Mut, _, _),
                  memberchk(Vis, [public, external]), memberchk(Mut, [view, pure]) ), Views).

		 /*******************************
		 *    SYMBOLIC EXECUTION        *
		 *******************************/

%   Values are ground terms:
%     p(Id)            a parameter of the entry function (by declaration id)
%     caller           msg.sender
%     c(Const)         a constant: an integer, true, false, zero, a string
%     rd(SVId, Keys)   a read of storage as it was before the call
%     bin(Op, A, B)    arithmetic (+ - * / %)
%     cmp(Op, A, B)    a comparison (== != < <= > >=)
%     not(A), and(A, B), or(A, B)
%     max(Bits)        type(uintN).max
%
%   The execution state: s(Env, Conds, Writes, Emits)
%     Env    Id-Value for parameters and locals
%     Conds  [cond(Value, Kind)] with Kind branch | guard, most recent first
%     Writes [w(SVId, Keys, Value)] in execution order, most recent first
%     Emits  [emit(EventName, Args)]
%
%   exec(+Stmts, +Ctx, +S0, -Outcome): Outcome is
%     next(S) | return(V, S) | revert(Reason, S)
%   eval(+Expr, +Ctx, +S0, -R): R is v(V, S) | revert(Reason, S)
%   Both are nondeterministic: one solution per path.
%   Ctx: ctx(Contract, CurrentContractId, Placeholder) — Placeholder is the
%   continuation a modifier's `_` runs.

%!  sol_paths(+Contract, +FunctionName, -Paths) is det.
%
%   Paths: path(Conds, Writes, Outcome, Emits), Outcome ok | revert(R).
sol_paths(Contract, Name, Fn-Paths) :-
    public_functions(Contract, Pub),
    member(Fn, Pub), Fn = fn(_, Name, _, _, _, _, _), !,
    fn_paths(Contract, Fn, Paths).

fn_paths(Contract, fn(_, Name, _, _, _, CId, D), Paths) :-
    %  the `unchecked` blocks met while running this call, whichever internal
    %  function they are written in, belong to the call in the ledger
    b_setval(sol_public_fn, Name),
    findall(p(Id), ( member(P, D.parameters.parameters), Id = P.id ), ArgVals),
    findall(Path,
            ( call_function(Contract, CId, D, ArgVals, s([], [], [], []), R),
              outcome_path(R, Path) ),
            Paths0),
    list_to_set(Paths0, Paths).

outcome_path(return(_, S), P) :- !, final_path(S, ok, P).
outcome_path(next(S), P) :- !, final_path(S, ok, P).
outcome_path(revert(R, S), P) :- final_path(S, revert(R), P).

final_path(s(_, Cs, Ws, Es), Out, path(Conds, Writes, Out, Emits)) :-
    reverse(Cs, Conds), reverse(Ws, Writes), reverse(Es, Emits).

%   A call: bind the parameters, run the modifiers around the body.
call_function(Contract, CId, D, ArgVals, s(Env0, Cs, Ws, Es), R) :-
    param_ids(D, PIds),
    pairs_keys_values(Bind, PIds, ArgVals),
    append(Bind, Env0, Env1),
    Mods = D.modifiers,
    %  the function being executed, for the wording of the constants it reads
    ( nb_current(sol_fn, Outer) -> true ; Outer = none ),
    ( get_dict(name, D, FnName) -> b_setval(sol_fn, FnName) ; true ),
    %  Solidity's `unchecked` is lexical: a function called from inside one is
    %  checked again.
    ( nb_current(sol_unchecked, OuterU) -> true ; OuterU = checked ),
    b_setval(sol_unchecked, checked),
    run_modifiers(Mods, Contract, CId, D, s(Env1, Cs, Ws, Es), R0),
    b_setval(sol_unchecked, OuterU),
    b_setval(sol_fn, Outer),
    restore_env(R0, Env0, R).

%   A call does not leak its locals into the caller.
restore_env(next(s(_, C, W, E)), Env, next(s(Env, C, W, E))).
restore_env(return(V, s(_, C, W, E)), Env, return(V, s(Env, C, W, E))).
restore_env(revert(X, s(_, C, W, E)), Env, revert(X, s(Env, C, W, E))).

run_modifiers([], Contract, CId, D, S, R) :- !,
    (   get_dict(body, D, B), B \== null
    ->  exec(B.statements, ctx(Contract, CId, none), S, R)
    ;   R = revert(unimplemented(D.name), S)
    ).
run_modifiers([M|Ms], Contract, CId, D, S0, R) :-
    M.nodeType == 'ModifierInvocation',
    Ref = M.modifierName.referencedDeclaration,
    Contract = contract(Model, _, _, _, _, _),
    node(Model, Ref, RD),
    (   RD.nodeType == 'ModifierDefinition'
    ->  resolve_modifier(Contract, Ref, md(_, _, MCId, MD)),
        ( get_dict(arguments, M, Args0), Args0 \== null -> Args = Args0 ; Args = [] ),
        eval_list(Args, ctx(Contract, CId, none), S0, R1),
        (   R1 = revert(X, S1) -> R = revert(X, S1)
        ;   R1 = vs(Vals, S1),
            S1 = s(Env1, C1, W1, E1),
            param_ids(MD, PIds),
            pairs_keys_values(Bind, PIds, Vals),
            append(Bind, Env1, Env2),
            Cont = run_modifiers(Ms, Contract, CId, D),
            exec(MD.body.statements, ctx(Contract, MCId, Cont), s(Env2, C1, W1, E1), R)
        )
    ;   % a base constructor invocation (Ownable(initialOwner)) in a
        % constructor's modifier list: run the base constructor
        RD.nodeType == 'ContractDefinition'
    ->  ( get_dict(arguments, M, Args0), Args0 \== null -> Args = Args0 ; Args = [] ),
        eval_list(Args, ctx(Contract, CId, none), S0, R1),
        base_call(R1, Contract, Ref, R2),
        (   R2 = revert(X2, S3) -> R = revert(X2, S3)
        ;   R2 = next(S2) -> run_modifiers(Ms, Contract, CId, D, S2, R)
        ;   R2 = return(_, S2), run_modifiers(Ms, Contract, CId, D, S2, R)
        )
    ).

base_call(revert(X, S), _, _, revert(X, S)).
base_call(vs(Vals, S1), Contract, Ref, R) :-
    (   base_constructor(Contract, Ref, BD)
    ->  call_function(Contract, Ref, BD, Vals, S1, R)
    ;   R = next(S1)
    ).

base_constructor(contract(Model, _, _, _, Fns, _), CId, D) :-
    member(fn(_, _, constructor, _, _, CId, D), Fns), !,
    Model = Model.

%   Statements.
exec([], _, S, next(S)).
exec([St|Sts], Ctx, S0, R) :-
    exec_stmt(St, Ctx, S0, R1),
    (   R1 = next(S1) -> exec(Sts, Ctx, S1, R)
    ;   R = R1
    ).

exec_stmt(St, Ctx, S0, R) :-
    T = St.nodeType,
    exec_stmt(T, St, Ctx, S0, R).

exec_stmt('Block', St, Ctx, S0, R) :- !, exec(St.statements, Ctx, S0, R).
%   `unchecked { … }`: inside it the EVM wraps instead of reverting, so there
%   is no Panic path to take here — and, where the block says why (every one
%   of OpenZeppelin's does), no wrap either: the author's comment is the
%   invariant that makes it impossible, and the twin writes the plain
%   arithmetic with a ledger row saying what it assumes (E3.4). Where the
%   block gives no reason the wrap is real and unexplained, and the
%   arithmetic is written as `mod 2^N`, which is what the machine does.
%
%   `unchecked` does not reach into a function the block calls; call_function/6
%   puts the flag back for the callee.
exec_stmt('UncheckedBlock', St, Ctx, S0, R) :- !,
    unchecked_reason(St, Ctx, Why),
    ( get_dict(src, St, Src) -> true ; Src = '' ),
    b_setval(sol_unchecked_src, Src),
    b_setval(sol_unchecked, unchecked(Why)),
    exec(St.statements, Ctx, S0, R0),
    b_setval(sol_unchecked, checked),
    R = R0.
exec_stmt('PlaceholderStatement', _, ctx(_, _, Cont), S0, R) :- !,
    (   Cont == none -> R = next(S0)
    ;   call(Cont, S0, R0),
        %  after the function body, the rest of the modifier runs (a
        %  `return` in the body ends the whole call)
        ( R0 = return(_, S1) -> R = next(S1) ; R = R0 )
    ).
exec_stmt('ExpressionStatement', St, Ctx, S0, R) :- !,
    eval(St.expression, Ctx, S0, R0),
    ( R0 = v(_, S1) -> R = next(S1) ; R = R0 ).
exec_stmt('VariableDeclarationStatement', St, Ctx, S0, R) :- !,
    (   get_dict(initialValue, St, IV), IV \== null
    ->  eval(IV, Ctx, S0, R0)
    ;   R0 = v(c(0), S0)
    ),
    (   R0 = v(V, s(Env, C, W, E))
    ->  St.declarations = [Decl|_],
        R = next(s([Decl.id-V|Env], C, W, E))
    ;   R = R0
    ).
exec_stmt('Return', St, Ctx, S0, R) :- !,
    (   get_dict(expression, St, E), E \== null
    ->  eval(E, Ctx, S0, R0),
        ( R0 = v(V, S1) -> R = return(V, S1) ; R = R0 )
    ;   R = return(c(true), S0)
    ).
exec_stmt('RevertStatement', St, Ctx, S0, R) :- !,
    Call = St.errorCall,
    error_reason(Call, Ctx, Reason),
    R = revert(Reason, S0).
exec_stmt('EmitStatement', St, Ctx, S0, R) :- !,
    Call = St.eventCall,
    eval_list(Call.arguments, Ctx, S0, R0),
    (   R0 = vs(Vals, s(Env, C, W, E))
    ->  Name = Call.expression.name,
        R = next(s(Env, C, W, [emit(Name, Vals)|E]))
    ;   R0 = revert(X, S1), R = revert(X, S1)
    ).
exec_stmt('IfStatement', St, Ctx, S0, R) :- !,
    eval(St.condition, Ctx, S0, RC),
    (   RC = revert(X, S1) -> R = revert(X, S1)
    ;   RC = v(Cond0, S1),
        simplify(Cond0, Cond),
        TrueBody = St.trueBody,
        ( get_dict(falseBody, St, FB), FB \== null -> FalseBody = FB ; FalseBody = none ),
        (   Cond == c(true) -> exec_branch(TrueBody, Ctx, S1, R)
        ;   Cond == c(false) -> exec_branch(FalseBody, Ctx, S1, R)
        ;   branch_kinds(TrueBody, FalseBody, Ctx, Cond, S1, KT, KF),
            (   add_cond(Cond, KT, S1, S2), exec_branch(TrueBody, Ctx, S2, R)
            ;   negate(Cond, NCond),
                add_cond(NCond, KF, S1, S3), exec_branch(FalseBody, Ctx, S3, R)
            )
        )
    ).
exec_stmt('ForStatement', St, Ctx, S0, R) :-
    array_loop(St, S0, IId, PId, Body), !,
    loop_body(Body, Ctx, S0, IId, PId, St, R).
exec_stmt(T, St, _, S0, revert(unsupported(T, Src), S0)) :-
    ( get_dict(src, St, Src) -> true ; Src = '' ).

%   `for (uint i = 0; i < xs.length; i++) Body` with xs a parameter.
array_loop(St, s(Env, _, _, _), IId, PId, Body) :-
    Init = St.get(initializationExpression), Init \== null,
    Init.nodeType == 'VariableDeclarationStatement',
    Init.declarations = [D], IId = D.id,
    IV = Init.get(initialValue), IV \== null, IV.nodeType == 'Literal', IV.value == '0',
    C = St.get(condition), C \== null, C.nodeType == 'BinaryOperation', C.operator == '<',
    C.leftExpression.nodeType == 'Identifier', C.leftExpression.referencedDeclaration == IId,
    C.rightExpression.nodeType == 'MemberAccess', C.rightExpression.memberName == length,
    Arr = C.rightExpression.expression, Arr.nodeType == 'Identifier',
    memberchk(Arr.referencedDeclaration-p(PId), Env),
    LE = St.get(loopExpression), LE \== null,
    increments(LE.expression, IId),
    Body = St.body.

increments(E, IId) :-
    (   E.nodeType == 'UnaryOperation', E.operator == '++'
    ->  E.subExpression.get(referencedDeclaration) == IId
    ;   E.nodeType == 'Assignment', E.operator == '+=',
        E.leftHandSide.get(referencedDeclaration) == IId,
        E.rightHandSide.nodeType == 'Literal', E.rightHandSide.value == '1'
    ).

%   The body, run once with `i` the position of an element of the list: its
%   writes become summaries, its reverts constraints over the elements.
loop_body(Body, Ctx, s(Env, Cs, Ws, Es), IId, PId, St, R) :-
    L = loop(PId),
    ( Body.nodeType == 'Block' -> Stmts = Body.statements ; Stmts = [Body] ),
    exec(Stmts, Ctx, s([IId-idx(L)|Env], Cs, [], Es), R0),
    (   R0 = revert(unsupported(W, Src), S1)
    ->  R = revert(unsupported(W, Src), S1)
    ;   R0 = revert(Reason, s(_, Cs1, _, Es1))
    ->  R = revert(Reason, s(Env, Cs1, Ws, Es1))
    ;   R0 = next(s(EnvB, Cs1, LWs, Es1)),
        \+ ( member(cond(C, branch), Cs1), \+ memberchk(cond(C, branch), Cs) ),
        reverse(LWs, LWsInOrder),
        foldl(loop_write(L), LWsInOrder, Ws, Ws1),
        loop_locals(L, Env, EnvB, Env1)
    ->  R = next(s(Env1, Cs1, Ws1, Es1))
    ;   ( get_dict(src, St, Src) -> true ; Src = '' ),
        R = revert(unsupported(loop, Src), s(Env, Cs, Ws, Es))
    ).

%   A relative write made in the loop, summarised over the list.
loop_write(L, w(SVId, Keys, rel(Op, D)), Ws0, [w(SVId, Keys, rel(Op, Total))|Ws0]) :-
    memberchk(Op, ['+', '-']),
    \+ sub_term(rd(_, _), D),
    (   sub_term(el(L), Keys)
    ->  Total = loop_total(L, keys(Keys), D)
    ;   Total = loop_total(L, all, D)
    ),
    \+ ( member(w(SVId, K2, _), Ws0), sub_term(el(L), K2) ).

%   A local the body changed: `s += xs[i]` (a sum over the list).
loop_locals(L, Env0, EnvB, Env) :-
    findall(Id-V, ( member(Id-V0, Env0), memberchk(Id-VB, EnvB), VB \== V0,
                    local_sum(L, V0, VB, V) ), Changed),
    \+ ( member(Id-V0, Env0), memberchk(Id-VB, EnvB), VB \== V0, \+ memberchk(Id-_, Changed) ),
    foldl([Id-V, E0, E1]>>( E1 = [Id-V|E0] ), Changed, Env0, Env).

local_sum(L, V0, bin('+', V0b, X), V) :- V0b == V0, !,
    ( V0 == c(0) -> V = loop_total(L, all, X) ; V = bin('+', V0, loop_total(L, all, X)) ).
local_sum(L, V0, bin('-', V0b, X), bin('-', V0, loop_total(L, all, X))) :- V0b == V0.

exec_branch(none, _, S, next(S)) :- !.
exec_branch(B, Ctx, S, R) :-
    (   B.nodeType == 'Block' -> exec(B.statements, Ctx, S, R)
    ;   exec_stmt(B, Ctx, S, R)
    ).

%   A branch condition is a GUARD of the other branch when every path
%   through this one reverts: the law for the other branch need not repeat
%   it (a call that would take this branch is refused by a constraint).
branch_kinds(TrueBody, FalseBody, Ctx, Cond, S, KT, KF) :-
    ( all_revert(TrueBody, Ctx, Cond, S) -> KF = guard ; KF = branch ),
    negate(Cond, NC),
    ( all_revert(FalseBody, Ctx, NC, S) -> KT = guard ; KT = branch ).

all_revert(none, _, _, _) :- !, fail.
all_revert(Body, Ctx, Cond, S) :-
    add_cond(Cond, branch, S, S1),
    findall(R, exec_branch(Body, Ctx, S1, R), Rs),
    Rs \== [],
    forall(member(R, Rs), R = revert(_, _)).

%   Adding a condition to a path: a path whose conditions contradict each
%   other is infeasible and dropped (fails); a condition already on the path
%   is not repeated.
add_cond(C, K, s(Env, Cs, Ws, Es), S) :-
    \+ contradicts(C, Cs),
    (   memberchk(cond(C, _), Cs) -> S = s(Env, Cs, Ws, Es)
    ;   S = s(Env, [cond(C, K)|Cs], Ws, Es)
    ).

contradicts(C, Cs) :-
    negate(C, NC), simplify(NC, NC1),
    ( memberchk(cond(NC, _), Cs) ; memberchk(cond(NC1, _), Cs) ), !.
contradicts(cmp('==', X, c(A)), Cs) :-
    member(cond(cmp('==', Y, c(B)), _), Cs), X == Y, A \== B, !.
contradicts(cmp('==', c(A), X), Cs) :- contradicts(cmp('==', X, c(A)), Cs).

negate(not(C), C) :- !.
negate(cmp(Op, A, B), cmp(NOp, A, B)) :- neg_op(Op, NOp), !.
negate(and(A, B), or(NA, NB)) :- !, negate(A, NA), negate(B, NB).
negate(or(A, B), and(NA, NB)) :- !, negate(A, NA), negate(B, NB).
negate(C, not(C)).

neg_op('==', '!='). neg_op('!=', '=='). neg_op('<', '>=').
neg_op('>=', '<'). neg_op('>', '<='). neg_op('<=', '>').

error_reason(Call, Ctx, Reason) :-
    (   get_dict(expression, Call, E), get_dict(name, E, Name)
    ->  length(Call.arguments, N),
        Reason = error(Name, N)
    ;   Reason = revert
    ),
    Ctx = Ctx.

%   Expressions.
eval_list([], _, S, vs([], S)).
eval_list([E|Es], Ctx, S0, R) :-
    eval(E, Ctx, S0, R1),
    (   R1 = v(V, S1)
    ->  eval_list(Es, Ctx, S1, R2),
        ( R2 = vs(Vs, S2) -> R = vs([V|Vs], S2) ; R = R2 )
    ;   R1 = revert(X, S1), R = revert(X, S1)
    ).

eval(E, Ctx, S0, R) :-
    T = E.nodeType,
    eval(T, E, Ctx, S0, R).

eval('Literal', E, _, S, v(c(V), S)) :- !, literal_value(E, V).
eval('Identifier', E, Ctx, S, v(V, S)) :- !, identifier_value(E, Ctx, S, V).
eval('TupleExpression', E, Ctx, S, R) :- !,
    E.components = [X], eval(X, Ctx, S, R).
eval('UnaryOperation', E, Ctx, S0, R) :- !,
    eval(E.subExpression, Ctx, S0, R0),
    (   R0 = v(V, S1)
    ->  ( E.operator == '!' -> negate(V, NV), R = v(NV, S1)
        ; E.operator == '-' -> R = v(bin('-', c(0), V), S1)
        ; R = revert(unsupported(unary(E.operator), E.src), S1) )
    ;   R = R0
    ).
eval('BinaryOperation', E, Ctx, S0, R) :- !,
    eval(E.leftExpression, Ctx, S0, R1),
    (   R1 = v(A, S1)
    ->  eval(E.rightExpression, Ctx, S1, R2),
        (   R2 = v(B, S2)
        ->  binary(E.operator, A, B, V0), simplify(V0, V),
            arith_paths(E.operator, A, B, V, S2, R)
        ;   R = R2
        )
    ;   R = R1
    ).
eval('IndexAccess', E, Ctx, S0, R) :- !,
    index_chain(E, Base, Idxs),
    eval_list(Idxs, Ctx, S0, R0),
    (   R0 = vs(Keys, S1)
    ->  Base.nodeType == 'Identifier',
        (   %  xs[i] in a loop over xs: an element of the list
            Keys = [idx(loop(PId))], S1 = s(Env, _, _, _),
            memberchk(Base.referencedDeclaration-p(PId), Env)
        ->  R = v(el(loop(PId)), S1)
        ;   Keys = [idx(_)]
        ->  R = revert(unsupported(parallel_arrays, E.src), S1)
        ;   state_ref(Base, Ctx, SVId),
            read_storage(SVId, Keys, S1, V),
            R = v(V, S1)
        )
    ;   R = R0
    ).
eval('MemberAccess', E, Ctx, S, R) :- !, member_value(E, Ctx, S, R).
eval('Assignment', E, Ctx, S0, R) :- !, assignment(E, Ctx, S0, R).
eval('FunctionCall', E, Ctx, S0, R) :- !, function_call(E, Ctx, S0, R).
eval(T, E, _, S, revert(unsupported(T, Src), S)) :-
    ( get_dict(src, E, Src) -> true ; Src = '' ).

literal_value(E, V) :-
    (   E.kind == number
    ->  atom_number(E.value, V0),
        ( get_dict(subdenomination, E, Sub), Sub \== null -> subdenomination(Sub, M), V is V0 * M ; V = V0 )
    ;   E.kind == bool
    ->  V = E.value
    ;   E.kind == string
    ->  atom_string(E.value, V)
    ;   V = E.value
    ).

subdenomination(wei, 1). subdenomination(gwei, 1000000000).
subdenomination(ether, 1000000000000000000).
subdenomination(seconds, 1). subdenomination(minutes, 60). subdenomination(hours, 3600).
subdenomination(days, 86400). subdenomination(weeks, 604800).

		 /*******************************
		 *   ARITHMETIC THAT CAN REVERT *
		 *******************************/

/*  E3.3 of the design notes ExtendingLanguagesCoverage.md §2.1.5.

    Since 0.8 every `+ - *` outside an `unchecked` block reverts on overflow
    (Panic 0x11) and every `/ %` reverts on a zero divisor (Panic 0x12).
    Those are revert paths of the function like any other, and until now this
    front end walked straight past them: the twin it wrote accepted calls the
    contract refuses, and nothing said so.

    So an arithmetic operation is a branch — it overflows, or it does not —
    and the overflow branch ends in a revert whose reason is the panic. Two
    things keep that from burying the twin:

      * **most of those branches cannot happen**, because the function has
        already refused the call that would reach them. `sol_prune.pl` asks
        whether the path's own conditions leave any room for the overflow;
        where they do not, neither branch is recorded and the arithmetic is
        written plainly — §2.1.2 step 3, and the reason the OpenZeppelin
        twins read as they did before this existed;
      * **`unchecked` says the author already knows**. Inside one there is no
        Panic to take, and where the block carries its reason — every one of
        OpenZeppelin's does — the twin writes the plain arithmetic and the
        ledger carries the assumption (E3.4). With no reason given the wrap is
        written as it happens: `mod 2^256`.
*/

%!  arith_outcome(+Operator, +A, +B, +State, -Outcome) is nondet.
%
%   What one arithmetic operation does to the path it is on:
%     plain(S)             nothing to say — it cannot overflow here, or it is
%                          inside an `unchecked` block that says why not
%     wrapped(S)           an `unchecked` block with no reason: the value
%                          wraps, and the twin says so
%     revert(panic(P), S)  it can overflow, and this is the path where it does
%
%   Split from arith_paths/6 because a compound assignment (`x += d`) never
%   reaches eval/5 with the whole sum: the write stays relative so that LPS
%   composes it, and only the conditions are at stake.
arith_outcome(Op, A, B, S, Out) :-
    panic_op(Op, PanicCond, Panic), !,
    call(PanicCond, A, B, C0), simplify(C0, C),
    S = s(Env, Cs, Ws, Es),
    (   \+ value_satisfiable(C, Cs)
    ->  %  the path has already made it impossible — an `if` that reverted
	%  first, most often. No constraint, no branch, and inside an
	%  `unchecked` block no wrap either: this is the case OpenZeppelin's
	%  blocks are for, whether or not they say so.
	unchecked_row(impossible),
	Out = plain(S)
    ;   unchecked_now(Why)
    ->  unchecked_row(Why),
	( Why \== none -> Out = plain(S) ; Out = wrapped(S) )
    ;   %  the overflow's own condition is the constraint's reason, so it is
	%  a `branch`; the surviving path's negation is a `guard`, which the
	%  laws leave out — exactly as for a `require` (constraint_item/5)
	(   Out = revert(panic(Panic), s(Env, [cond(C, branch)|Cs], Ws, Es))
	;   negate(C, NC0), simplify(NC0, NC),
	    Out = plain(s(Env, [cond(NC, guard)|Cs], Ws, Es))
	)
    ).
arith_outcome(_, _, _, S, plain(S)).

%!  arith_paths(+Operator, +A, +B, +Value, +State, -Result) is nondet.
arith_paths(Op, A, B, V, S, R) :-
    arith_outcome(Op, A, B, S, Out),
    (   Out = plain(S1)   -> R = v(V, S1)
    ;   Out = wrapped(S1) -> wrapped_value(Op, V, VW), R = v(VW, S1)
    ;   Out = revert(P, S1), R = revert(P, S1)
    ).

%   `+ - *` overflow with Panic 0x11 (17); `/ %` divide by zero with Panic
%   0x12 (18). Each names the condition under which the EVM reverts.
panic_op('+', over_cond('+'), 17).
panic_op('*', over_cond('*'), 17).
panic_op('-', under_cond, 17).
panic_op('/', zero_cond, 18).
panic_op('%', zero_cond, 18).

%   The ceiling is written as the named constant the twin already uses for
%   `type(uint256).max` — `the largest amount` — so that the constraint reads
%   as a sentence and not as a 78-digit literal. The per-function reviewed
%   wording is deliberately not asked for here: this is not the unlimited
%   allowance, it is the width of the word.
over_cond(Op, A, B, cmp('>', bin(Op, A, B), c(const(Name, V)))) :-
    constant_name(none, max(256), Name), V is 2^256 - 1.
under_cond(A, B, cmp('<', A, B)).
zero_cond(_, B, cmp('==', B, c(0))).

unchecked_now(Why) :- nb_current(sol_unchecked, unchecked(Why)).

%   Inside an `unchecked` block with a stated reason, the arithmetic is
%   written as it reads: the reason is the invariant that makes the wrap
%   impossible, and it goes in the ledger rather than into the program. With
%   no reason, `mod 2^256` — the machine's own answer, and unreadable enough
%   to be worth reading.
wrapped_value(Op, V, VU) :-
    (   memberchk(Op, ['+', '-', '*'])
    ->  W is 2^256, VU = bin('%', V, c(W))
    ;   VU = V
    ).

%   What the ledger says about this `unchecked` (E3.4): the invariant the
%   block states, or the fact that the path itself forbids the wrap, or that
%   neither is true and the twin therefore wraps as the machine does.
unchecked_row(What) :-
    (   nb_current(sol_unchecked, unchecked(_))
    ->  ( nb_current(sol_public_fn, Fn) -> true ; Fn = none ),
	( nb_current(sol_unchecked_src, Src) -> true ; Src = '' ),
	( retract(unchecked_site(Fn, Src, _)) -> true ; true ),
	assertz(unchecked_site(Fn, Src, What))
    ;   true
    ).

%   The comment inside (or just above) the block, which is where a reader of
%   the contract is told why the wrap cannot happen. Recorded for the ledger
%   whether or not it is found.
unchecked_reason(St, ctx(contract(Model, _, _, _, _, _), _, _), Why) :- !,
    (   get_dict(src, St, Src) -> true ; Src = '' ),
    (   src_text(Model, Src, Text), block_comment(Text, Why0)
    ->  Why = Why0
    ;   Why = none
    ),
    ( nb_current(sol_public_fn, Fn) -> true ; Fn = none ),
    (   unchecked_site(Fn, Src, _) -> true
    ;   assertz(unchecked_site(Fn, Src, Why))
    ).
unchecked_reason(_, _, none).

%   The first `//` line of the block, without its slashes: OpenZeppelin's
%   convention, and the only place the invariant is written down.
block_comment(Text, Why) :-
    split_string(Text, "\n", "", Lines),
    member(L, Lines),
    split_string(L, "", " \t", [L1]),
    string_concat("//", Rest, L1),
    split_string(Rest, "", " \t", [Why0]),
    Why0 \== "", !,
    atom_string(Why, Why0).

binary(Op, A, B, cmp(Op, A, B)) :- memberchk(Op, ['==', '!=', '<', '<=', '>', '>=']), !.
binary('&&', A, B, and(A, B)) :- !.
binary('||', A, B, or(A, B)) :- !.
binary(Op, A, B, bin(Op, A, B)).

index_chain(E, Base, Idxs) :-
    (   E.nodeType == 'IndexAccess'
    ->  index_chain(E.baseExpression, Base, I0), append(I0, [E.indexExpression], Idxs)
    ;   Base = E, Idxs = []
    ).

state_ref(Id, ctx(Contract, _, _), SVId) :-
    Ref = Id.referencedDeclaration,
    sv_by_id(Contract, Ref, _), SVId = Ref.

identifier_value(E, Ctx, s(Env, _, Ws, _), V) :-
    Ref = E.referencedDeclaration,
    (   memberchk(Ref-V0, Env) -> V = V0
    ;   Ctx = ctx(Contract, _, _), sv_by_id(Contract, Ref, _)
    ->  read_storage_(Ref, [], Ws, V)
    ;   Ctx = ctx(contract(Model, _, _, _, _, _), _, _),
        node(Model, Ref, CD), CD.nodeType == 'VariableDeclaration',
        CD.get(mutability) == constant, get_dict(value, CD, Init), Init \== null,
        Init.nodeType == 'Literal', literal_value(Init, CV), number(CV)
    ->  ( nb_current(sol_fn, Fn) -> true ; Fn = none ),
        constant_name(Fn, sv(CD.name), Name),
        V = c(const(Name, CV))
    ;   E.name == this -> V = c(this)
    ;   V = c(unknown(E.name))
    ).

read_storage(SVId, Keys, s(_, _, Ws, _), V) :- read_storage_(SVId, Keys, Ws, V).

%   Storage as the path has left it: the value of an earlier write of the
%   same slot with the same keys, else the state before the call.
read_storage_(SVId, Keys, Ws, V) :-
    (   member(w(SVId, Keys, V0), Ws) -> resolved_value(V0, SVId, Keys, Ws, V)
    ;   V = rd(SVId, Keys)
    ).

%   A relative write rel(Op, Delta) read back: Old Op Delta.
resolved_value(rel(Op, D), SVId, Keys, Ws, bin(Op, Old, D)) :- !,
    Ws = [_|_],
    (   append(_, [w(SVId, Keys, _)|Earlier], Ws) -> true ; Earlier = [] ),
    read_storage_(SVId, Keys, Earlier, Old).
resolved_value(V, _, _, _, V).

member_value(E, Ctx, S, R) :-
    M = E.memberName, X = E.expression,
    (   X.nodeType == 'Identifier', X.name == msg, M == sender -> R = v(caller, S)
    ;   X.nodeType == 'Identifier', X.name == msg, M == value -> R = v(msg_value, S)
    ;   X.nodeType == 'Identifier', X.name == block, M == timestamp -> R = v(now, S)
    ;   X.nodeType == 'FunctionCall', X.expression.get(name) == type, M == max
    ->  X.arguments = [TA|_], type_bits(TA, Bits), V is 2^Bits - 1,
        ( nb_current(sol_fn, Fn) -> true ; Fn = none ),
        constant_name(Fn, max(Bits), Name),
        R = v(c(const(Name, V)), S)
    ;   M == length, X.nodeType == 'Identifier', S = s(Env, _, _, _),
        memberchk(X.referencedDeclaration-p(PId), Env)
    ->  R = v(len(PId), S)                   % the number of a list's elements
    ;   X.nodeType == 'Identifier', sv_by_id_ctx(Ctx, X, SVId)
    ->  R = v(rd(SVId, [member(M)]), S)
    ;   R = revert(unsupported(member(M), E.src), S)
    ).

sv_by_id_ctx(ctx(Contract, _, _), X, Ref) :-
    Ref = X.referencedDeclaration, sv_by_id(Contract, Ref, _).

type_bits(TA, Bits) :-
    (   get_dict(typeName, TA, TN), get_dict(name, TN, N) -> true ; N = uint256 ),
    (   atom_concat(uint, BA, N), BA \== '' -> atom_number(BA, Bits)
    ;   Bits = 256
    ).

%   x = e, x += e, x -= e (also on mapping entries).
assignment(E, Ctx, S0, R) :-
    L = E.leftHandSide, Op = E.operator,
    eval(E.rightHandSide, Ctx, S0, R1),
    (   R1 = revert(X, S1) -> R = revert(X, S1)
    ;   R1 = v(RV, S1),
        lvalue(L, Ctx, S1, LR),
        (   LR = revert(X, S2) -> R = revert(X, S2)
        ;   LR = lv(Where, S2),
            (   Op == '=', same_slot_rhs(L, E.rightHandSide, BOp, DeltaE)
            ->  %  `x[k] = x[k] + d`, in one expression: relative too
                eval(DeltaE, Ctx, S2, RD),
                (   RD = v(DV, S2b)
                ->  NewV = rel(BOp, DV), Arith = arith(BOp, DV)
                ;   RD = revert(_, S2b), NewV = RV, Arith = none
                )
            ;   assign_value(Op, Where, RV, S2, NewV), S2b = S2,
                %  `x += d`, `x -= d`, …: the operation is the assignment, and
                %  the value written is relative or already built, so eval/5
                %  never sees the sum. Its branch is taken in store_arith/5.
                (   atom_concat(BOp, '=', Op), memberchk(BOp, ['+', '-', '*', '/', '%'])
                ->  Arith = arith(BOp, RV)
                ;   Arith = none
                )
            ),
            store_arith(Arith, Where, NewV, S2b, R)
        )
    ).

%   A write that is its own arithmetic — `x[k] += d`, or `x[k] = x[k] + d`,
%   which the executor keeps relative so that LPS composes it. The sum is
%   never built, so arith_paths/6 never sees it; the branch it can make is
%   taken here instead, over the slot's value as the path left it.
store_arith(none, Where, NewV, S, v(NewV, S1)) :- !, store(Where, NewV, S, S1).
store_arith(arith(BOp, DV), Where, NewV, S, R) :-
    current_value(Where, S, Cur),
    arith_outcome(BOp, Cur, DV, S, Out),
    (   Out = revert(P, S1)
    ->  R = revert(P, S1)
    ;   Out = plain(S1)
    ->  store(Where, NewV, S1, S2), R = v(NewV, S2)
    ;   Out = wrapped(S1),
        W is 2^256, Abs = bin('%', bin(BOp, Cur, DV), c(W)),
        store(Where, Abs, S1, S2), R = v(Abs, S2)
    ).

same_slot_rhs(L, RHS, BOp, Delta) :-
    L.nodeType == 'IndexAccess',
    RHS.nodeType == 'BinaryOperation',
    BOp = RHS.operator, memberchk(BOp, ['+', '-']),
    same_ast(L, RHS.leftExpression),
    Delta = RHS.rightExpression.

%   Two expressions written alike (ids and positions aside).
same_ast(A, B) :-
    (   is_dict(A), is_dict(B)
    ->  A.nodeType == B.nodeType,
        (   A.nodeType == 'Identifier' -> A.referencedDeclaration == B.referencedDeclaration
        ;   A.nodeType == 'IndexAccess'
        ->  same_ast(A.baseExpression, B.baseExpression), same_ast(A.indexExpression, B.indexExpression)
        ;   A.nodeType == 'MemberAccess'
        ->  A.memberName == B.memberName, same_ast(A.expression, B.expression)
        ;   A.nodeType == 'Literal' -> A.value == B.value
        ;   fail
        )
    ;   A == B
    ).

lvalue(L, Ctx, S0, R) :-
    (   L.nodeType == 'Identifier'
    ->  Ref = L.referencedDeclaration,
        (   S0 = s(Env, _, _, _), memberchk(Ref-_, Env) -> R = lv(local(Ref), S0)
        ;   Ctx = ctx(C, _, _), sv_by_id(C, Ref, _) -> R = lv(storage(Ref, []), S0)
        ;   R = revert(unsupported(lvalue(L.name), L.src), S0)
        )
    ;   L.nodeType == 'IndexAccess'
    ->  index_chain(L, Base, Idxs),
        eval_list(Idxs, Ctx, S0, R0),
        (   R0 = vs(Keys, S1), Base.nodeType == 'Identifier', state_ref(Base, Ctx, SVId)
        ->  R = lv(storage(SVId, Keys), S1)
        ;   R0 = revert(X, S1) -> R = revert(X, S1)
        ;   R = revert(unsupported(lvalue_index, L.src), S0)
        )
    ;   R = revert(unsupported(lvalue(L.nodeType), L.src), S0)
    ).

assign_value('=', _, RV, _, RV) :- !.
assign_value(Op, storage(_, _), RV, _, rel(BOp, RV)) :-
    %  `x[k] += d`: read and written at the same moment, so a relative write
    atom_concat(BOp, '=', Op), memberchk(BOp, ['+', '-']), !.
assign_value(Op, Where, RV, S, V) :-
    atom_concat(BOp, '=', Op),
    current_value(Where, S, Cur),
    V0 = bin(BOp, Cur, RV), simplify(V0, V).

current_value(local(Id), s(Env, _, _, _), V) :- memberchk(Id-V, Env), !.
current_value(storage(SVId, Keys), S, V) :- read_storage(SVId, Keys, S, V).

store(local(Id), V, s(Env, C, W, E), s([Id-V|Env], C, W, E)).
store(storage(SVId, Keys), V0, s(Env, C, W, E), s(Env, C, [w(SVId, Keys, V)|W], E)) :-
    ( V0 = rel(_, _) -> V = V0 ; relative(SVId, Keys, V0, W, V) ).

%   `x[k] = x[k] + d` (or `-`), read before any other write of that slot:
%   a relative write, which LPS applies to the state as the call has left
%   it — so two writes of one entry compose in order.
relative(SVId, Keys, bin(Op, rd(SVId, Keys), D), W, rel(Op, D)) :-
    memberchk(Op, ['+', '-']),
    \+ member(w(SVId, _, _), W), !.
relative(SVId, Keys, bin(Op, Cur, D), W, rel(Op, D)) :-
    memberchk(Op, ['+', '-']),
    member(w(SVId, Keys, _), W),
    read_storage_(SVId, Keys, W, Cur), !.
relative(_, _, V, _, V).

%   Calls: internal functions (inlined), super, require/assert, type
%   conversions, errors in `require(cond, Error())`.
function_call(E, Ctx, S0, R) :-
    Callee = E.expression,
    Args = E.arguments,
    (   E.kind == typeConversion
    ->  Args = [A], eval(A, Ctx, S0, R0),
        ( R0 = v(V, S1), V == c(0), address_type(E) -> R = v(c(zero), S1) ; R = R0 )
    ;   Callee.nodeType == 'Identifier', memberchk(Callee.name, [require, assert])
    ->  Args = [CondE|Rest],
        eval(CondE, Ctx, S0, RC),
        (   RC = v(C0, S1)
        ->  simplify(C0, C),
            require_reason(Rest, Reason),
            (   C == c(true) -> R = v(c(true), S1)
            ;   C == c(false) -> R = revert(Reason, S1)
            ;   (   add_cond(C, guard, S1, S2), R = v(c(true), S2)
                ;   negate(C, NC), add_cond(NC, branch, S1, S3), R = revert(Reason, S3)
                )
            )
        ;   R = RC
        )
    ;   Callee.nodeType == 'Identifier', Callee.name == '_msgSender'
    ->  R = v(caller, S0)
    ;   Callee.nodeType == 'Identifier', Callee.name == '_msgData'
    ->  R = v(c(msg_data), S0)
    ;   Callee.nodeType == 'Identifier'
    ->  Ref = Callee.referencedDeclaration,
        Ctx = ctx(Contract, _, _),
        (   resolve_fn(Contract, Ref, top, fn(_, _, _, _, _, FCId, FD))
        ->  internal_call(Contract, FCId, FD, Args, Ctx, S0, R)
        ;   R = revert(unsupported(call(Callee.name), E.src), S0)
        )
    ;   Callee.nodeType == 'MemberAccess', Callee.expression.nodeType == 'Identifier',
        Callee.expression.name == super
    ->  Ctx = ctx(Contract, CurC, _),
        Ref = Callee.referencedDeclaration,
        (   resolve_fn(Contract, Ref, CurC, fn(_, _, _, _, _, FCId, FD))
        ->  internal_call(Contract, FCId, FD, Args, Ctx, S0, R)
        ;   R = revert(unsupported(super(Callee.memberName), E.src), S0)
        )
    ;   R = revert(unsupported(external_call, E.src), S0)
    ).

address_type(E) :-
    (   get_dict(typeDescriptions, E, TD), get_dict(typeString, TD, TS) -> sub_atom(TS, 0, _, _, address)
    ;   true
    ).

require_reason([], revert).
require_reason([M|_], Reason) :-
    (   M.nodeType == 'Literal' -> atom_string(M.value, S), Reason = message(S)
    ;   M.nodeType == 'FunctionCall', get_dict(name, M.expression, N) -> Reason = error(N, 0)
    ;   Reason = revert
    ).

internal_call(Contract, FCId, FD, Args, Ctx, S0, R) :-
    eval_list(Args, Ctx, S0, R0),
    (   R0 = vs(Vals, S1)
    ->  call_function(Contract, FCId, FD, Vals, S1, R1),
        (   R1 = return(V, S2) -> R = v(V, S2)
        ;   R1 = next(S2) -> R = v(c(void), S2)
        ;   R1 = revert(X, S2), R = revert(X, S2)
        )
    ;   R = R0
    ).

%   Constant folding.
simplify(V, V) :- var(V), !.
simplify(cmp(Op, A0, B0), R) :- !,
    simplify(A0, A), simplify(B0, B),
    (   A = c(X0), B = c(Y0), const_number(X0, X), const_number(Y0, Y),
        ground(X-Y), fold_cmp(Op, X, Y, T) -> R = c(T)
    ;   %  msg.sender is never the zero address
        memberchk(A-B, [caller-c(zero), c(zero)-caller]), memberchk(Op-T, ['=='-false, '!='-true])
    ->  R = c(T)
    ;   A == B, memberchk(Op, ['==', '<=', '>=']) -> R = c(true)
    ;   A == B, memberchk(Op, ['!=', '<', '>']) -> R = c(false)
    ;   R = cmp(Op, A, B)
    ).
simplify(not(A0), R) :- !,
    simplify(A0, A),
    ( A == c(true) -> R = c(false) ; A == c(false) -> R = c(true)
    ; A = not(X) -> R = X ; negate(A, R0), R0 \= not(_) -> R = R0 ; R = not(A) ).
simplify(and(A0, B0), R) :- !,
    simplify(A0, A), simplify(B0, B),
    ( A == c(false) ; B == c(false) -> R = c(false)
    ; A == c(true) -> R = B ; B == c(true) -> R = A ; R = and(A, B) ).
simplify(or(A0, B0), R) :- !,
    simplify(A0, A), simplify(B0, B),
    ( A == c(true) ; B == c(true) -> R = c(true)
    ; A == c(false) -> R = B ; B == c(false) -> R = A ; R = or(A, B) ).
simplify(bin(Op, A0, B0), R) :- !,
    simplify(A0, A), simplify(B0, B),
    (   A = c(X), B = c(Y), integer(X), integer(Y), fold_bin(Op, X, Y, Z) -> R = c(Z)
    ;   Op == '+', B == c(0) -> R = A
    ;   Op == '-', B == c(0) -> R = A
    ;   R = bin(Op, A, B)
    ).
simplify(V, V).

%   A named constant's value, for constant folding.
const_number(const(_, V), V) :- !.
const_number(V, V).

fold_cmp('==', X, Y, T) :- ( X == Y -> T = true ; ( number(X), number(Y) ) -> ( X =:= Y -> T = true ; T = false ) ; atomic(X), atomic(Y) -> T = false ).
fold_cmp('!=', X, Y, T) :- fold_cmp('==', X, Y, T0), ( T0 == true -> T = false ; T = true ).
fold_cmp(Op, X, Y, T) :- number(X), number(Y), memberchk(Op-G, ['<'-(<), '<='-(=<), '>'-(>), '>='-(>=)]),
    C =.. [G, X, Y], ( call(C) -> T = true ; T = false ).

fold_bin('+', X, Y, Z) :- Z is X + Y.
fold_bin('-', X, Y, Z) :- Z is X - Y.
fold_bin('*', X, Y, Z) :- Z is X * Y.
fold_bin('/', X, Y, Z) :- Y =\= 0, Z is X // Y.
fold_bin('%', X, Y, Z) :- Y =\= 0, Z is X mod Y.

		 /*******************************
		 *     PATHS -> LPS TERMS       *
		 *******************************/

%   The twin: templates, laws and constraints for every state-changing
%   public function; `initially` from the constructor when the instance
%   binding supplies its arguments.
sol_twin(Contract, Options, program(Header, Items), Ledger) :-
    retractall(constant_used(_, _, _)),
    Contract = contract(_, CName, _, SVs, _, _),
    option(kb(KB), Options, CName),
    Header = [kb(KB), target(lps), setting(max_time, 20)|Extra],
    ( option(comment(Cm), Options) -> Extra = [comment(Cm)] ; Extra = [] ),
    public_functions(Contract, Pub),
    maplist(fn_entry(Contract), Pub, Entries),
    %  the fluents the laws and constraints mention, and the actions
    findall(FT, ( member(sv(Id, N, K, _, _), SVs), fluent_template(CName, Id, N, K, FT) ), FTs),
    findall(AT, ( member(e(Fn, _, _), Entries), action_template(Contract, Fn, AT) ), ATs),
    append(FTs, ATs, Templates),
    maplist(entry_items(Contract), Entries, ItemLists),
    append(ItemLists, LawItems),
    instance_items(Contract, Options, InitItems, InitLedger),
    view_ledger(Contract, ViewLedger),
    findall(constant(F, Name, V), constant_used(F, Name, V), Constants),
    append([Templates, Constants, InitItems, LawItems], Items),
    findall(L, ( member(e(Fn, Paths, _), Entries), fn_ledger(Contract, Fn, Paths, L) ), FnLedger0),
    append(FnLedger0, FnLedger),
    findall(L, ( member(sv(Id, N, K, _, _), SVs), sv_ledger(CName, N, K, L) ), SVLedger),
    append([SVLedger, FnLedger, ViewLedger, InitLedger], Ledger).

fn_entry(Contract, Fn, e(Fn, Paths, Fn)) :-
    fn_paths(Contract, Fn, Paths).

%   The LPS items of one function: a constraint per revert path, laws per
%   success path.
entry_items(Contract, e(Fn, Paths, _), Items) :-
    Fn = fn(_, Name, _, _, _, _, D),
    param_ids(D, PIds),
    Contract = contract(_, CName, _, _, _, _),
    action_functor(CName, Name, AF),
    length(PIds, NP),
    length(PVars, NP),
    action_order(CName, Name, NP, Order),
    maplist(nth1_of(PVars), Order, Slots),
    Act =.. [AF, Caller|Slots],
    pairs_keys_values(ParamMap0, PIds, PVars),
    %  an element of each parameter a loop may run over (Phase 1e (d))
    findall(loop(Id)-_, member(Id, PIds), ElemMap),
    append(ParamMap0, ElemMap, ParamMap),
    Base = b(Act, Caller, ParamMap, _T1, _T2),
    %  a path through code the executor does not read is not a revert: the
    %  function (or that path of it) is RESIDUE, its source kept for the
    %  assistant
    findall(What-Src, member(path(_, _, revert(unsupported(What, Src)), _), Paths), Unsup0),
    list_to_set(Unsup0, Unsup),
    exclude(unsupported_path, Paths, Paths1),
    findall(I, ( member(path(Cs, _, revert(R), _), Paths1),
                 constraint_item(Contract, Base, Cs, R, I0), with_elements(Base, I0, I) ), Cons0),
    dedupe_variants(Cons0, Cons1),
    %  each constraint headed by the error it stands for
    findall(X, ( member(constraint(RC, T), Cons1), constraint_comment(RC, Cm),
                 member(X, [comment(Cm), T]) ), Cons),
    findall(I, ( member(path(Cs, Ws, ok, Es), Paths1),
                 law_items(Contract, Base, Cs, Ws, Es, I0), maplist(with_elements(Base), I0, I) ), Laws0),
    append(Laws0, Laws1),
    dedupe_variants(Laws1, Laws),
    format(atom(Head), "~w", [Name]),
    residue_items(Contract, Name, D, Unsup, Res),
    append([[comment(Head)], Res, Cons, Laws], Items).

unsupported_path(path(_, _, revert(unsupported(_, _)), _)).

%   A law or constraint about an element of a list (a loop's key, or a
%   `require` in a loop) says first that it is one: `and an account is in the
%   list`.
%   (foldl/4, not findall/3: findall copies, and the goal must hold the
%   item's own variables.)
with_elements(b(_, _, PM, _, _), Item0, Item) :-
    foldl(element_goal(PM, Item0), PM, [], Ms0), reverse(Ms0, Ms),
    (   Ms == [] -> Item = Item0
    ;   add_conditions(Item0, Ms, Item)
    ).

element_goal(PM, Item, loop(PId)-E, Ms0, Ms) :-
    (   var(E), memberchk(PId-LV, PM), sub_term(X, Item), X == E
    ->  Ms = [member(E, LV)|Ms0]
    ;   Ms = Ms0
    ).
element_goal(_, _, P, Ms, Ms) :- P \= loop(_)-_.

add_conditions(constraint(RC, lps(d_pre([H|Gs]))), Ms, constraint(RC, lps(d_pre([H|Gs1])))) :- !,
    append(Ms, Gs, Gs1).
add_conditions(lps(T0), Ms, lps(T)) :-
    T0 =.. [K|Args0], memberchk(K, [initiated, terminated, updated]), !,
    last(Args0, Cs0), append(Front, [Cs0], Args0), append(Ms, Cs0, Cs),
    append(Front, [Cs], Args), T =.. [K|Args].
add_conditions(I, _, I).

%   The residue block of a function with untranslated paths: what was not
%   read, where, and the function's source.
residue_items(_, _, _, [], []) :- !.
residue_items(contract(Model, CName, _, _, _, _), Name, D, Unsup, [residue(Id, Opts)]) :-
    format(atom(Id), '~w_~w', [CName, Name]),
    findall(W, ( member(What-_, Unsup), format(atom(W), '~w', [What]) ), Ws0), list_to_set(Ws0, Ws),
    atomic_list_concat(Ws, ', ', WT),
    format(atom(Title), 'paths of ~w through ~w', [Name, WT]),
    (   get_dict(src, D, Src), src_text(Model, Src, Text) -> Code = Text ; Code = '(source not available)' ),
    ( get_dict(src, D, S0) -> format(atom(Loc), 'function ~w, src ~w', [Name, S0]) ; Loc = Name ),
    Opts = [title(Title), locator(Loc), source(solidity, Code),
            note("The other paths of this function are translated below; these are for the assistant (residue mode) or a person.")].

src_text(Model, Src, Text) :-
    atomic_list_concat([S, L, I], ':', Src),
    atom_number(S, Start), atom_number(L, Len), atom_number(I, Idx),
    source_text(Model, Idx, All),
    %  offsets count UTF-8 bytes
    string_codes(All, Cs), phrase(utf8_codes(Cs), Bytes),
    length(Pre, Start), append(Pre, Rest, Bytes),
    length(Mid, Len), append(Mid, _, Rest),
    phrase(utf8_codes(TCs), Mid), string_codes(Text, TCs).

nth1_of(List, I, X) :- nth1(I, List, X).

dedupe_variants([], []).
dedupe_variants([X|Xs], [X|Ys]) :-
    exclude(=@=(X), Xs, Xs1),
    dedupe_variants(Xs1, Ys).

%   One constraint per revert path and per read variant.
%   The guards of the path are left out: each guard's failure is a revert
%   path of its own, so the union of the constraints is the same (and each
%   reads as the one reason it states).
constraint_item(Contract, B, Conds, Reason, constraint(RC, lps(d_pre([happens(Act, T1, T2)|Gs])))) :-
    B = b(Act, _, _, T1, T2),
    findall(C, member(cond(C, branch), Conds), Cs),
    lower_conds(Contract, Cs, B, Gs),
    reason_comment(Reason, RC).

constraint_comment(RC, Cm) :- format(atom(Cm), 'reverts: ~w', [RC]).

reason_comment(error(N, _), N) :- !.
reason_comment(message(M), M) :- !.
%   The two the compiler raises rather than the contract: since 0.8 every
%   checked `+ - *` reverts with Panic 0x11 on overflow and every `/ %` with
%   Panic 0x12 on a zero divisor. Named here as a reader of the chain would
%   see them.
reason_comment(panic(17), 'Panic 0x11 (arithmetic overflow or underflow)') :- !.
reason_comment(panic(18), 'Panic 0x12 (division or remainder by zero)') :- !.
reason_comment(R, R).

%   Laws of one success path: its own branch conditions (the guards are the
%   constraints' business), then for each write its law(s).
law_items(Contract, B, Conds, Writes, _Emits, Items) :-
    findall(C, member(cond(C, branch), Conds), Cs),
    findall(I, ( member(W, Writes), write_law(Contract, B, Cs, W, I) ), Items0),
    append(Items0, Items).

write_law(Contract, B, Cs, w(SVId, Keys, V), Items) :-
    sv_by_id(Contract, SVId, sv(_, _, Kind, _, _)),
    B = b(Act, Caller, PM, T1, T2),
    fluent_functor(Contract, SVId, FF),
    value_kind(Kind, VK),
    findall(Items1,
            ( lower_conds(Contract, Cs, B, Gs),
              maplist(lower_value(Contract, B), Keys, KVs, KGs), append(KGs, KeyGoals),
              write_law_(VK, FF, KVs, V, Contract, B, Gs, KeyGoals, Items0),
              maplist(with_elements(B), Items0, Items1) ),
            Alts),
    append(Alts, Items),
    Act = Act, Caller = Caller, PM = PM, T1 = T1, T2 = T2.

value_kind(map(_, VK), VK) :- !.
value_kind(K, K).

write_law_(uint, FF, KVs, V, Contract, B, Gs, KeyGoals, Items) :- !,
    B = b(Act, _, _, T1, T2),
    Trigger = happens(Act, T1, T2),
    append(KVs, [Old], FA), Fl =.. [FF|FA],
    append(KVs, [_], FA0), Fl0 =.. [FF|FA0],
    append(KVs, [0], FAz), Flz =.. [FF|FAz],
    append([KeyGoals, Gs], Conds0),
    (   V = rel(Op, D)
    ->  lower_value(Contract, B, D, DV, DGs),
        arith(Op, Old, DV, Expr)
    ;   lower_value(Contract, B, V, Expr, DGs)
    ),
    append(Conds0, DGs, Conds1),
    append(Conds1, [New is Expr], Conds),
    %  The fluent's default (`; 0 by default`) is its old value when no
    %  entry is stored: no law materialises it (Phase 1e (a)).
    Items = [lps(updated(Trigger, Fl, Old-New, Conds))],
    Fl0 = Fl0, Flz = Flz, T1 = T1.

write_law_(bool, FF, KVs, V, Contract, B, Gs, KeyGoals, Items) :- !,
    B = b(Act, _, _, T1, T2),
    Fl =.. [FF|KVs],
    append(KeyGoals, Gs, Conds0),
    simplify(V, V1),
    (   V1 == c(true) -> Items = [lps(initiated(happens(Act, T1, T2), Fl, Conds0))]
    ;   V1 == c(false) -> Items = [lps(terminated(happens(Act, T1, T2), Fl, Conds0))]
    ;   lower_cond(Contract, B, V1, G1), negate(V1, NV), lower_cond(Contract, B, NV, G2),
        append(Conds0, G1, C1), append(Conds0, G2, C2),
        Items = [lps(initiated(happens(Act, T1, T2), Fl, C1)),
                 lps(terminated(happens(Act, T1, T2), Fl, C2))]
    ).
write_law_(_, FF, KVs, V, Contract, B, Gs, KeyGoals, Items) :-
    %  an address or a string: the old value ends, the new one starts; the
    %  zero address is the absence of a value
    B = b(Act, _, _, T1, T2),
    append(KVs, [_Old], FA), FlOld =.. [FF|FA],
    append(KeyGoals, Gs, Conds0),
    lower_value(Contract, B, V, NV, VGs),
    append(Conds0, VGs, Conds1),
    Term = lps(terminated(happens(Act, T1, T2), FlOld, [holds(FlOld, T1)|Conds0])),
    (   NV == 'the zero address'
    ->  Items = [Term]
    ;   append(KVs, [NV], FN), FlNew =.. [FF|FN],
        Items = [Term, lps(initiated(happens(Act, T1, T2), FlNew, Conds1))]
    ).

%   Two fluent terms of one slot: same functor, same keys (all arguments but
%   the value).
same_slot(G, F) :-
    compound(G), compound(F),
    G =.. [N|GA], F =.. [N|FA],
    append(GK, [_], GA), append(FK, [_], FA),
    GK == FK.

arith(Op, A, B, E) :- op_prolog(Op, POp), E =.. [POp, A, B].

op_prolog('+', +). op_prolog('-', -). op_prolog('*', *).
op_prolog('/', //). op_prolog('%', mod).

%   Conditions to LPS goals at the call's start time. Each read of storage
%   becomes a fluent condition with a new variable — or, when the entry is
%   absent, its default value (the second solution).
lower_conds(Contract, Cs, B, Gs) :-
    reads_in(Cs, Reads),
    read_variants(Contract, B, Reads, Bindings, RGs),
    maplist(subst_reads(Bindings), Cs, Cs1),
    maplist(simplify, Cs1, Cs2),
    \+ memberchk(c(false), Cs2),
    exclude(==(c(true)), Cs2, Cs3),
    maplist(lower_cond(Contract, B), Cs3, CGss), append(CGss, CGs),
    append(RGs, CGs, Gs).

reads_in(T, Reads) :- findall(R, sub_read(T, R), Rs0), list_to_set(Rs0, Reads).

sub_read(T, T) :- compound(T), T = rd(_, _).
sub_read(T, R) :- compound(T), T \= rd(_, _), arg(_, T, A), sub_read(A, R).
sub_read(rd(_, Keys), R) :- member(K, Keys), sub_read(K, R).

%   For each read, present (a fluent goal binding a variable) or absent
%   (its default).
read_variants(_, _, [], [], []).
read_variants(Contract, B, [rd(SVId, Keys)|Rs], [rd(SVId, Keys)-Val|Bs], Gs) :-
    sv_by_id(Contract, SVId, sv(_, _, Kind, _, _)),
    value_kind(Kind, VK),
    fluent_functor(Contract, SVId, FF),
    B = b(_, _, _, T1, _),
    maplist(lower_value(Contract, B), Keys, KVs, KGs0), append(KGs0, KGs),
    (   VK == bool
    ->  Fl =.. [FF|KVs],
        (   Val = c(true), G = [holds(Fl, T1)]
        ;   Val = c(false), G = [holds(not(Fl), T1)]
        )
    ;   append(KVs, [V], FA), Fl =.. [FF|FA],
        append(KVs, [_], FA0), Fl0 =.. [FF|FA0],
        default_value(VK, Def),
        (   Val = lv(V), G = [holds(Fl, T1)]
        ;   %  absent: only for a fluent with no default (a default is read
            %  by the fluent itself)
            \+ fluent_default(Contract, SVId, _),
            Val = c(Def), G = [holds(not(Fl0), T1)]
        )
    ),
    read_variants(Contract, B, Rs, Bs, Gs1),
    append([KGs, G, Gs1], Gs).

%!  fluent_default(+Contract, +SVId, -Default) is semidet.
%
%   The `; <value> by default` of a state variable's fluent: Solidity's zero
%   of a number (0) or an address (the zero address). Not for the replay's
%   deliberately wrong twin (sol_mutation(no_default)).
fluent_default(Contract, SVId, Def) :-
    \+ sol_mutation(no_default),
    sv_by_id(Contract, SVId, sv(_, _, Kind, _, _)),
    value_kind(Kind, VK),
    memberchk(VK-Def, [uint-0, address-'the zero address']).

default_value(uint, 0) :- !.
default_value(address, zero) :- !.
default_value(string, "") :- !.
default_value(_, 0).

subst_reads(Bs, T0, T) :-
    (   T0 = rd(_, _), memberchk(T0-V, Bs) -> T = V
    ;   compound(T0), T0 \= lv(_), T0 \= c(_)
    ->  T0 =.. [F|As], maplist(subst_reads(Bs), As, As1), T =.. [F|As1]
    ;   T = T0
    ).

lower_cond(Contract, B, C, Gs) :-
    (   C = cmp(Op, X, Y)
    ->  lower_value(Contract, B, X, XV, G1), lower_value(Contract, B, Y, YV, G2),
        cmp_goal(Op, XV, YV, G),
        append([G1, G2, [G]], Gs)
    ;   C = and(X, Y)
    ->  lower_cond(Contract, B, X, G1), lower_cond(Contract, B, Y, G2), append(G1, G2, Gs)
    ;   C = not(X), X = lv(V) -> Gs = [V == false]
    ;   C = lv(V) -> Gs = [V == true]
    ;   C = c(true) -> Gs = []
    ;   Gs = [unsupported_condition(C)]
    ).

cmp_goal('==', X, Y, X = Y).
cmp_goal('!=', X, Y, X \= Y).
cmp_goal('<', X, Y, X < Y).
cmp_goal('<=', X, Y, X =< Y).
cmp_goal('>', X, Y, X > Y).
cmp_goal('>=', X, Y, X >= Y).

%   A value as an LPS term (with goals needed to compute it).
lower_value(_, b(_, Caller, _, _, _), caller, Caller, []) :- !.
lower_value(_, b(_, _, PM, _, _), p(Id), V, []) :- !, memberchk(Id-V, PM).
lower_value(_, _, c(zero), 'the zero address', []) :- !.
%   A named constant: the goal of its template binds its value, and the
%   writer writes its name there (`the constants are:`).
lower_value(_, _, c(const(Name, V)), X, [G]) :- !,
    constant_functor(Name, F),
    ( constant_used(F, Name, V) -> true ; assertz(constant_used(F, Name, V)) ),
    G =.. [F, X].
lower_value(_, _, c(X), X, []) :- !.
lower_value(_, _, lv(V), V, []) :- !.
%   Lists (Phase 1e (d)): an element of the list a loop runs over, the
%   number of its elements, and a loop's total.
lower_value(_, b(_, _, PM, _, _), el(loop(PId)), E, []) :- !,
    memberchk(loop(PId)-E, PM).
lower_value(_, b(_, _, PM, T1, _), len(PId), N, [holds(findall(X, [member(X, LV)], Xs), T1), length(Xs, N)]) :- !,
    memberchk(PId-LV, PM).
lower_value(C, B, loop_total(loop(PId), Filter, D), Total, Gs) :- !,
    B = b(Act, Caller, PM, T1, T2),
    memberchk(PId-LV, PM),
    %  the element, fresh inside the aggregate
    select(loop(PId)-E0, PM, PM1), PMx = [loop(PId)-X|PM1],
    Bx = b(Act, Caller, PMx, T1, T2),
    (   Filter = keys(Keys)
    ->  maplist(lower_value(C, B), Keys, KVs, KG0), maplist(lower_value(C, Bx), Keys, KXs, KG1),
        append(KG0, KG1, KGs0), append(KGs0, KGs),
        maplist([A, Bv, (A = Bv)]>>true, KXs, KVs, Eqs0),
        exclude([(A = Bv)]>>(A == Bv), Eqs0, Eqs)
    ;   KGs = [], Eqs = []
    ),
    E0 = E0,
    (   \+ sub_term(el(_), D)
    ->  %  the same amount for each occurrence: the amount times their count
        lower_value(C, B, D, DV, DGs),
        append([member(X, LV)|KGs], Eqs, Inner),
        append(DGs, [holds(findall(X, Inner, Xs), T1), length(Xs, N)], Gs0),
        (   DV == 1 -> Total = N, Gs = Gs0
        ;   Total = DV * N, Gs = Gs0
        )
    ;   lower_value(C, Bx, D, DX, DGs),
        (   var(DX), DX == X
        ->  append([member(X, LV)|KGs], Eqs, Inner), Elem = X
        ;   append([[member(X, LV)|KGs], Eqs, DGs, [V is DX]], Inner), Elem = V
        ),
        Gs = [holds(findall(Elem, Inner, Vs), T1), sum_list(Vs, Total)]
    ).
lower_value(C, B, bin(Op, X, Y), E, Gs) :- !,
    lower_value(C, B, X, XV, G1), lower_value(C, B, Y, YV, G2),
    arith(Op, XV, YV, E), append(G1, G2, Gs).
lower_value(Contract, B, rd(SVId, Keys), V, Gs) :- !,
    %  a read inside a value (not a condition): its present variant
    fluent_functor(Contract, SVId, FF),
    B = b(_, _, _, T1, _),
    maplist(lower_value(Contract, B), Keys, KVs, KGs0), append(KGs0, KGs),
    append(KVs, [V], FA), Fl =.. [FF|FA],
    append(KGs, [holds(Fl, T1)], Gs).
lower_value(_, _, V, unsupported_value(V), []).

		 /*******************************
		 *          TEMPLATES           *
		 *******************************/

%   The functor LE derives from the constant's template `the value of <name>
%   is *a number*` (le_writer:constant_template_text/3).
constant_functor(Name, F) :-
    atomic_list_concat(Ws, ' ', Name),
    append([[the, value, of], Ws, [is]], All),
    atomic_list_concat(All, '_', F).

fluent_functor(contract(_, CName, _, SVs, _, _), SVId, FF) :-
    member(sv(SVId, N, _, _, _), SVs), !,
    sv_functor(CName, N, FF).

fluent_template(CName, _Id, N, Kind, fluent(FF, Text, [known_as(FF)|Def])) :-
    sv_functor(CName, N, FF),
    sv_wording(CName, N, Kind, Text),
    value_kind(Kind, VK),
    (   \+ sol_mutation(no_default), memberchk(VK-D, [uint-0, address-'the zero address'])
    ->  Def = [default(D)]
    ;   Def = []
    ).

action_template(contract(_, CName, _, _, _, _), fn(_, Name, _, _, _, _, D), action(AF, Text, [known_as(AF)|Arity])) :-
    param_ids(D, PIds), length(PIds, NP), NA is NP + 1, Arity = [arity(NA)],
    action_functor(CName, Name, AF),
    findall(PN-PT, ( member(P, D.parameters.parameters), PN = P.name,
                     PT = P.typeDescriptions.typeString ), Params),
    action_wording(CName, Name, Params, Text).

		 /*******************************
		 *      INSTANCE BINDING        *
		 *******************************/

%   `initially` facts: the constructor run on the binding's arguments
%   (option constructor_args([...])), and option initially([Fluent, ...])
%   for state read from the chain.
instance_items(Contract, Options, Items, Ledger) :-
    (   option(constructor_args(Args), Options)
    ->  constructor_state(Contract, Args, Facts0, Ledger)
    ;   Facts0 = [], Ledger = []
    ),
    option(initially(Extra), Options, []),
    append(Facts0, Extra, Facts),
    (   Facts == [] -> Items = []
    ;   Items = [lps(initial_state(Facts))]
    ).

constructor_state(Contract, Args, Facts, [entry(constructor, constructor, encoded, 'run on the instance''s arguments -> initially', initially, none)]) :-
    Contract = contract(_, _, Lin, SVs, Fns, _),
    %  the state variables' own initial values, base first
    findall(w(Id, [], V), ( member(sv(Id, _, _, Init, _), SVs), Init \== none,
                            literal_init(Init, V) ), Ws0),
    reverse(Ws0, Ws0r),
    S0 = s([], [], Ws0r, []),
    Lin = [Top|_],
    (   member(fn(_, _, constructor, _, _, Top, D), Fns)
    ->  maplist(arg_value, Args, Vals),
        once(( call_function(Contract, Top, D, Vals, S0, R), R \= revert(_, _) )),
        ( R = next(s(_, _, Ws, _)) ; R = return(_, s(_, _, Ws, _)) )
    ;   Ws = Ws0r
    ),
    reverse(Ws, InOrder),
    findall(K-V, ( member(w(Id, Keys, V), InOrder), K = Id-Keys ), KVs),
    last_values(KVs, Final),
    findall(F, ( member((Id-Keys)-V, Final), state_fact(Contract, Id, Keys, V, F) ), Facts).

literal_init(Init, c(V)) :-
    Init.nodeType == 'Literal', literal_value(Init, V).

arg_value(A, c(A)).

%   The value each slot is left with: its writes applied in order, a
%   relative write to the value before it (zero when there is none).
last_values(KVs, Final) :-
    findall(K, member(K-_, KVs), Ks0), list_to_set(Ks0, Ks),
    findall(K-V, ( member(K, Ks), last_value(K, KVs, V) ), Final).
last_value(K, KVs, V) :-
    findall(V0, member(K-V0, KVs), Vs),
    foldl(apply_write, Vs, c(0), V).

apply_write(rel(Op, D), Cur, V) :- !, V0 = bin(Op, Cur, D), simplify(V0, V).
apply_write(W, _, W).

state_fact(Contract, Id, Keys, V0, F) :-
    sv_by_id(Contract, Id, sv(_, _, Kind, _, _)),
    value_kind(Kind, VK),
    fluent_functor(Contract, Id, FF),
    maplist([c(K), K]>>true, Keys, KVs),
    simplify(V0, c(V)),
    (   VK == bool -> V == true, F =.. [FF|KVs]
    ;   V == zero -> fail
    ;   append(KVs, [V], FA), F =.. [FF|FA]
    ).

		 /*******************************
		 *           LEDGER             *
		 *******************************/

sv_ledger(CName, N, K, entry(N, 'state variable', encoded, M, In, Note)) :-
    sv_functor(CName, N, FF),
    format(atom(M), '~w -> fluent', [K]),
    format(atom(In), 'fluent ~w', [FF]),
    ( wording_reviewed(CName, sv(N)) -> Note = none ; Note = 'wording generated from the identifier: to review' ).

fn_ledger(Contract, fn(_, Name, _, _, _, _, D), Paths, Entries) :-
    Contract = contract(_, CName, _, _, _, _),
    action_functor(CName, Name, AF),
    include([path(_, _, revert(_), _)]>>true, Paths, Rev),
    include([path(_, _, ok, _)]>>true, Paths, Ok),
    length(Rev, NR), length(Ok, NO),
    findall(U, ( member(path(_, _, revert(unsupported(U0, Src)), _), Paths),
                 format(atom(U), '~w at ~w', [U0, Src]) ), Unsupported0),
    list_to_set(Unsupported0, Unsupported),
    findall(E, ( member(path(_, _, _, Es), Paths), member(emit(E, _), Es) ), Ev0),
    list_to_set(Ev0, Events),
    (   Unsupported == []
    ->  Verdict = encoded, Note0 = none
    ;   Verdict = residue, atomic_list_concat(Unsupported, '; ', Note0)
    ),
    format(atom(M), '~w success path(s) -> laws, ~w revert path(s) -> constraints; modifiers and internal calls inlined', [NO, NR]),
    format(atom(In), 'action ~w', [AF]),
    ( wording_reviewed(CName, fn(Name)) -> WN = [] ; WN = ['wording generated from the identifiers: to review'] ),
    ( Note0 == none -> NL = WN ; NL = [Note0|WN] ),
    ( NL == [] -> Note = none ; atomic_list_concat(NL, '; ', Note) ),
    E1 = entry(Name, function, Verdict, M, In, Note),
    (   Events == [] -> Entries0 = [E1]
    ;   atomic_list_concat(Events, ', ', EvT),
        format(atom(EM), 'events ~w: recorded by the call itself (the action), not as separate LPS events', [EvT]),
        Entries0 = [E1, entry(Name, events, approximated, EM, In, 'replayable from the chain''s logs')]
    ),
    unchecked_entries(Name, In, UEs),
    append(Entries0, UEs, Entries),
    D = D.

%   E3.4: one row per `unchecked` block the call runs through, saying what the
%   twin did with it. The distinction that matters to a reader is whether the
%   wrap is *impossible* — which the path's own conditions can settle, and
%   usually do — or merely *assumed* impossible by a comment the contract's
%   author wrote, which nothing here checks and the replay against chain data
%   is the test of.
unchecked_entries(Name, In, Entries) :-
    findall(entry(Name, 'unchecked block', Verdict, M, In, Note),
            ( unchecked_site(Name, Src, What),
              unchecked_words(What, Src, Verdict, M, Note) ),
            Entries).

unchecked_words(impossible, Src, encoded, M, none) :- !,
    format(atom(M), 'unchecked at ~w: the call''s own conditions already forbid the wrap, so the plain arithmetic is exact', [Src]).
unchecked_words(none, Src, approximated, M, Note) :- !,
    format(atom(M), 'unchecked at ~w: no reason given, so the twin wraps as the EVM does (mod 2^256)', [Src]),
    Note = 'a wrap the contract does not explain: worth a look before trusting either'.
unchecked_words(Why, Src, approximated, M, Note) :-
    format(atom(M), 'unchecked at ~w: assumes ~w', [Src, Why]),
    Note = 'the assumption is the contract''s and is not checked here; the replay against chain data is what tests it'.

view_ledger(Contract, Entries) :-
    view_functions(Contract, Views),
    findall(entry(N, 'view function', encoded, 'reads a fluent: the fluent itself answers it', none, none),
            member(fn(_, N, _, _, _, _, _), Views), Entries0),
    list_to_set(Entries0, Entries).

		 /*******************************
		 *         CONVENIENCE          *
		 *******************************/

%!  sol_translate(+SolFiles, +ContractName, +Options, -IR, -Ledger) is det.
sol_translate(Files, Name, Options, IR, Ledger) :-
    sol_compile(Files, JSON),
    sol_load(JSON, Model),
    sol_contract(Model, Name, Contract),
    sol_twin(Contract, Options, IR, Ledger).
