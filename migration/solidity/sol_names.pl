/** <module> Wording of the Solidity twins' templates

    The one creative step of a translation (§4.1): the English of each
    fluent (a state variable) and each action (a function). Two sources:

      - the REVIEWED wording of the reference models (E11): OpenZeppelin's
        ERC20, Ownable and Pausable, and the FiatToken subset — keyed by the
        state variable's or the function's name, the same across contracts
        that inherit them;
      - a mechanical fallback from the identifiers (`_totalSupply` -> `the
        total supply is *an amount*`, `mapping(address account => uint256)
        _balances` -> `the balance of *an account* is *an amount*`), which the
        ledger marks as wording to review.

    Templates must not contain a section keyword (contract, knowledge,
    templates, fluents, events, actions, ...) nor a reserved word (if, and,
    or, unless, either), and a type word must not be a template word next to
    it; the reviewed wording respects this, the fallback avoids the known
    ones.
*/

:- module(sol_names, [
    sv_functor/3,          % +Contract, +StateVarName, -Functor
    sv_wording/4,          % +Contract, +StateVarName, +Kind, -Text
    action_functor/3,      % +Contract, +FunctionName, -Functor
    action_order/4,        % +Contract, +FunctionName, +NParams, -Order
    action_wording/4,      % +Contract, +FunctionName, +Params, -Text
    may_wording/4,         % +Contract, +FunctionName, +Params, -Text
    gerund_wording/4,      % +Contract, +FunctionName, +Params, -Text
    wording_reviewed/2,    % +Contract, ?sv(Name) | fn(Name)
    constant_name/3        % +Function, +Constant, -Name
  ]).

:- use_module(library(lists)).
:- use_module(library(pcre)).
:- use_module(library(apply)).

		 /*******************************
		 *     REVIEWED (E11)           *
		 *******************************/

%   reviewed_sv(Name, Functor, Text)
reviewed_sv('_balances', balance, "the balance of *an account* is *an amount*").
reviewed_sv(balances, balance, "the balance of *an account* is *an amount*").
reviewed_sv('_allowances', allowance, "the allowance of *an owner* for *a spender* is *an amount*").
reviewed_sv(allowed, allowance, "the allowance of *an owner* for *a spender* is *an amount*").
reviewed_sv('_totalSupply', total_supply, "the total supply is *an amount*").
reviewed_sv(totalSupply_, total_supply, "the total supply is *an amount*").
reviewed_sv(totalSupply, total_supply, "the total supply is *an amount*").
reviewed_sv('_name', token_name, "the name of the token is *a text*").
reviewed_sv('_symbol', token_symbol, "the symbol of the token is *a text*").
reviewed_sv('_owner', owner, "the owner of the token is *an account*").
reviewed_sv('_paused', paused, "the token is paused").
reviewed_sv(paused, paused, "the token is paused").
reviewed_sv(pauser, pauser, "the pauser of the token is *an account*").
reviewed_sv(blacklister, blacklister, "the blacklister of the token is *an account*").
reviewed_sv(blacklisted, blacklisted, "*an account* is on the blacklist").
reviewed_sv(masterMinter, master_minter, "the master minter of the token is *an account*").
reviewed_sv(minters, minter, "*an account* is a minter of the token").
reviewed_sv(minterAllowed, minting_allowance, "the minting allowance of *a minter* is *an amount*").

%   reviewed_fn(Name, Arity, Functor, Action, May, Gerund)
%   The caller is the first place of each; the parameters follow in order.
reviewed_fn(transfer, 2, transfer,
            "*a sender* transfers *an amount* to *a recipient*",
            "*a sender* may transfer *an amount* to *a recipient*",
            "*a sender* transferring *an amount* to *a recipient*") :- true.
reviewed_fn(approve, 2, approve,
            "*an owner* approves *a spender* for *an amount*",
            "*an owner* may approve *a spender* for *an amount*",
            "*an owner* approving *a spender* for *an amount*").
reviewed_fn(transferFrom, 3, transfer_from,
            "*a spender* moves *an amount* from *an owner* to *a recipient*",
            "*a spender* may move *an amount* from *an owner* to *a recipient*",
            "*a spender* moving *an amount* from *an owner* to *a recipient*").
reviewed_fn(mint, 2, mint,
            "*a minter* mints *an amount* for *a recipient*",
            "*a minter* may mint *an amount* for *a recipient*",
            "*a minter* minting *an amount* for *a recipient*").
reviewed_fn(burn, 1, burn,
            "*a minter* burns *an amount*",
            "*a minter* may burn *an amount*",
            "*a minter* burning *an amount*").
reviewed_fn(airdrop, 2, airdrop,
            "*a sender* airdrops *an amount* to *a list*",
            "*a sender* may airdrop *an amount* to *a list*",
            "*a sender* airdropping *an amount* to *a list*").
reviewed_fn(burnEach, 1, burn_each,
            "*a holder* burns the amounts in *a list*",
            "*a holder* may burn the amounts in *a list*",
            "*a holder* burning the amounts in *a list*").
reviewed_fn(pause, 0, pause,
            "*a pauser* pauses the token",
            "*a pauser* may pause the token",
            "*a pauser* pausing the token").
reviewed_fn(unpause, 0, unpause,
            "*a pauser* unpauses the token",
            "*a pauser* may unpause the token",
            "*a pauser* unpausing the token").
reviewed_fn(transferOwnership, 1, transfer_ownership,
            "*an owner* hands the ownership to *a new owner*",
            "*an owner* may hand the ownership to *a new owner*",
            "*an owner* handing the ownership to *a new owner*").
reviewed_fn(renounceOwnership, 0, renounce_ownership,
            "*an owner* renounces the ownership",
            "*an owner* may renounce the ownership",
            "*an owner* renouncing the ownership").
reviewed_fn(blacklist, 1, blacklist,
            "*a blacklister* blacklists *an account*",
            "*a blacklister* may blacklist *an account*",
            "*a blacklister* blacklisting *an account*").
reviewed_fn(unBlacklist, 1, unblacklist,
            "*a blacklister* clears *an account* from the blacklist",
            "*a blacklister* may clear *an account* from the blacklist",
            "*a blacklister* clearing *an account* from the blacklist").
reviewed_fn(configureMinter, 2, configure_minter,
            "*a master minter* allows *a minter* to mint up to *an amount*",
            "*a master minter* may allow *a minter* to mint up to *an amount*",
            "*a master minter* allowing *a minter* to mint up to *an amount*").
reviewed_fn(removeMinter, 1, remove_minter,
            "*a master minter* removes the minter *a minter*",
            "*a master minter* may remove the minter *a minter*",
            "*a master minter* removing the minter *a minter*").
reviewed_fn(updateMasterMinter, 1, update_master_minter,
            "*an owner* appoints *an account* master minter",
            "*an owner* may appoint *an account* master minter",
            "*an owner* appointing *an account* master minter").
reviewed_fn(updatePauser, 1, update_pauser,
            "*an owner* appoints *an account* pauser",
            "*an owner* may appoint *an account* pauser",
            "*an owner* appointing *an account* pauser").
reviewed_fn(updateBlacklister, 1, update_blacklister,
            "*an owner* appoints *an account* blacklister",
            "*an owner* may appoint *an account* blacklister",
            "*an owner* appointing *an account* blacklister").

%   The order in which the reviewed wording places the parameters (after the
%   caller): `transfer(to, value)` reads `*a sender* transfers *an amount*
%   to *a recipient*`, the value first.
reviewed_order(transfer, [2, 1]).
reviewed_order(transferFrom, [3, 1, 2]).
reviewed_order(mint, [2, 1]).
reviewed_order(airdrop, [2, 1]).

action_order(_, N, NP, Order) :-
    (   reviewed_order(N, Order), length(Order, NP) -> true
    ;   numlist(1, NP, Order0) -> Order = Order0
    ;   Order = []
    ).

wording_reviewed(_, sv(N)) :- reviewed_sv(N, _, _), !.
wording_reviewed(_, fn(N)) :- reviewed_fn(N, _, _, _, _, _), !.

		 /*******************************
		 *         STATE                *
		 *******************************/

sv_functor(_, N, F) :- reviewed_sv(N, F, _), !.
sv_functor(_, N, F) :- identifier_words(N, Ws), atomic_list_concat(Ws, '_', F).

sv_wording(_, N, _, T) :- reviewed_sv(N, _, T), !.
sv_wording(C, N, Kind, T) :-
    identifier_words(N, Ws0),
    singular_words(Ws0, Ws1),
    %  `balanceOf` is the balance of an account: the preposition is the
    %  sentence's, not the name's
    ( append(Ws, [P], Ws1), Ws \== [], memberchk(P, [of, for, to, by]) -> true ; Ws = Ws1 ),
    atomic_list_concat(Ws, ' ', Name),
    holder_noun(C, H),
    kind_wording(Kind, H, Name, T).

%   What the state belongs to: "the token" in the reviewed token models, "the
%   contract" in any other — a contract the translator does not know may be no
%   token at all.
holder_noun(C, token) :- reviewed_contract(C), !.
holder_noun(_, contract).

reviewed_contract(C) :- memberchk(C, ['RefERC20', 'RefOwnable', 'RefPausable', 'MyToken', 'FiatTokenSubset', 'Airdrop']).

kind_wording(Kind, token, Name, T) :- !, kind_wording(Kind, Name, T).
kind_wording(bool, H, Name, T) :- !, format(string(T), "the ~w is ~w", [H, Name]).
kind_wording(VK, H, Name, T) :- VK \= map(_, _), !,
    value_slot(VK, V),
    format(string(T), "the ~w of the ~w is ~w", [Name, H, V]).
kind_wording(Kind, _, Name, T) :- kind_wording(Kind, Name, T).

kind_wording(bool, Name, T) :- !, format(string(T), "the token is ~w", [Name]).
kind_wording(map(Keys, bool), Name, T) :- !,
    key_slots(Keys, Slots), atomic_list_concat(Slots, ' for ', S),
    format(string(T), "~w is ~w", [S, Name]).
kind_wording(map(Keys, VK), Name, T) :- !,
    key_slots(Keys, Slots), atomic_list_concat(Slots, ' for ', S),
    value_slot(VK, V),
    format(string(T), "the ~w of ~w is ~w", [Name, S, V]).
kind_wording(VK, Name, T) :-
    value_slot(VK, V),
    format(string(T), "the ~w of the token is ~w", [Name, V]).

key_slots(Keys, Slots) :-
    foldl(key_slot, Keys, []-[], _-Rev), reverse(Rev, Slots).

key_slot(key(Name, Kind), Seen-Acc, [T|Seen]-[S|Acc]) :-
    (   Name \== none, identifier_words(Name, Ws), Ws \== [] -> atomic_list_concat(Ws, ' ', T0)
    ;   kind_noun(Kind, T0)
    ),
    ( memberchk(T0, Seen) -> format(atom(T), 'second ~w', [T0]) ; T = T0 ),
    slot(T, S).

kind_noun(address, account) :- !.
kind_noun(uint, number) :- !.
kind_noun(_, key).

value_slot(uint, S) :- !, slot(amount, S).
value_slot(address, S) :- !, slot(account, S).
value_slot(string, S) :- !, slot(text, S).
value_slot(_, S) :- slot(value, S).

slot(Noun, S) :-
    sub_atom(Noun, 0, 1, _, C),
    ( memberchk(C, [a, e, i, o, u]) -> Art = an ; Art = a ),
    format(atom(S), '*~w ~w*', [Art, Noun]).

		 /*******************************
		 *    NAMED CONSTANTS (e)       *
		 *******************************/

%!  constant_name(+Function, +Constant, -Name) is det.
%
%   The name a literal gets in `the constants are:` (MiggratingFromOtherSystems
%   Phase 1e (e)): Constant is max(Bits) for `type(uintN).max`, or sv(Id) for
%   a `constant` state variable; Function is the function it is read in.
%   Reviewed: OpenZeppelin's `_spendAllowance` reads `type(uint256).max` as the
%   unlimited allowance. Otherwise the identifier's words, or the largest
%   amount.
constant_name(Fn, C, Name) :- reviewed_constant(Fn, C, Name), !.
constant_name(_, sv(Id), Name) :- !,
    atom_codes(Id, Cs),
    (   \+ ( member(X, Cs), code_type(X, lower) )       % MAX_SUPPLY
    ->  atomic_list_concat(Ws0, '_', Id), exclude(==(''), Ws0, Ws1), maplist(downcase_atom, Ws1, Ws2),
        exclude(reserved_word, Ws2, Ws3), maplist(spell_number, Ws3, Wss), append(Wss, Ws)
    ;   identifier_words(Id, Ws)
    ),
    atomic_list_concat([the|Ws], ' ', Name).
constant_name(_, max(_), 'the largest amount').

reviewed_constant('_spendAllowance', max(256), 'the unlimited allowance').

		 /*******************************
		 *         ACTIONS              *
		 *******************************/

action_functor(_, N, F) :- reviewed_fn(N, _, F, _, _, _), !.
action_functor(_, N, F) :- identifier_words(N, Ws), atomic_list_concat([call|Ws], '_', F).

%   The reviewed wording names the caller by its role ("a minter mints"):
%   right in the reviewed models, and for the ERC-20 functions everywhere (a
%   sender transfers); in another contract the role is not known, so the
%   caller is "a caller" and the object "the contract" ("a caller mints an
%   amount for a recipient").
action_wording(C, N, Ps, T) :- length(Ps, A), reviewed_fn(N, A, _, T0, _, _), !, role_neutral(C, N, T0, T).
action_wording(_, N, Ps, T) :- generic(N, Ps, calls, T).

may_wording(C, N, Ps, T) :- length(Ps, A), reviewed_fn(N, A, _, _, T0, _), !, role_neutral(C, N, T0, T).
may_wording(_, N, Ps, T) :- generic(N, Ps, 'may call', T).

gerund_wording(C, N, Ps, T) :- length(Ps, A), reviewed_fn(N, A, _, _, _, T0), !, role_neutral(C, N, T0, T).
gerund_wording(_, N, Ps, T) :- generic(N, Ps, calling, T).

role_neutral(C, N, T0, T) :-
    (   ( var(C) ; reviewed_contract(C) ; memberchk(N, [transfer, approve, transferFrom]) )
    ->  T = T0
    ;   atom_string(T0, S0),
        ( sub_string(S0, 0, B, _, "*"), sub_string(S0, B, _, 0, R0),
          sub_string(R0, 1, _, 0, R1), sub_string(R1, E, 1, _, "*"), !,
          E1 is E + 2, sub_string(R0, E1, _, 0, Rest)
        ->  format(string(S1), "*a caller*~w", [Rest])
        ;   S1 = S0 ),
        re_replace("the token"/g, "the contract", S1, S2),
        atom_string(T, S2)
    ).

%   `*a caller* calls set fee with fee *an amount* with to *an account*`
generic(N, Ps, Verb, T) :-
    identifier_words(N, Ws), atomic_list_concat(Ws, ' ', FnWords),
    findall(P, ( member(PN-PT, Ps), param_phrase(PN, PT, P) ), Parts),
    atomic_list_concat(Parts, ' ', Tail),
    (   Parts == [] -> format(string(T), "*a caller* ~w ~w", [Verb, FnWords])
    ;   format(string(T), "*a caller* ~w ~w ~w", [Verb, FnWords, Tail])
    ).

param_phrase(PN, PT, P) :-
    identifier_words(PN, Ws0),
    ( Ws0 == [] -> Ws = [value] ; Ws = Ws0 ),
    atomic_list_concat(Ws, ' ', Words),
    type_noun(PT, Noun),
    slot(Noun, S),
    format(atom(P), 'with ~w ~w', [Words, S]).

type_noun(T, list) :- sub_atom(T, _, _, 0, '[]'), !.       % an array: a list
type_noun(T, account) :- sub_atom(T, 0, _, _, address), !.
type_noun(T, amount) :- sub_atom(T, 0, _, _, uint), !.
type_noun(bool, flag) :- !.
type_noun(T, text) :- sub_atom(T, 0, _, _, string), !.
type_noun(_, value).

		 /*******************************
		 *        IDENTIFIERS           *
		 *******************************/

%   `_totalSupply` -> [total, supply]; `minterAllowed` -> [minter, allowed];
%   `totalSupply_` -> [total, supply]; `ERC20` -> [erc, twenty]
identifier_words(Id, Words) :-
    atom_codes(Id, Cs),
    phrase(id_words(Ws0), Cs),
    exclude(==(''), Ws0, Ws1),
    maplist(downcase_atom, Ws1, Ws2),
    exclude(reserved_word, Ws2, Ws3),
    maplist(spell_number, Ws3, Wss), append(Wss, Words).

id_words([W|Ws]) --> sep, !, id_words([W|Ws]).
id_words([W|Ws]) --> word(Cs), { Cs \== [], atom_codes(W, Cs) }, !, id_words(Ws).
id_words([]) --> [].

sep --> [C], { memberchk(C, `_$`) }.

word([C|Cs]) --> [C], { code_type(C, upper) }, lower_run(Cs).
word([C|Cs]) --> [C], { code_type(C, lower) }, lower_run(Cs).
word([C|Cs]) --> [C], { code_type(C, digit) }, digit_run(Cs).

lower_run([C|Cs]) --> [C], { code_type(C, lower) }, !, lower_run(Cs).
lower_run([]) --> [].
digit_run([C|Cs]) --> [C], { code_type(C, digit) }, !, digit_run(Cs).
digit_run([]) --> [].

reserved_word(W) :- memberchk(W, [if, and, or, unless, either, contract, knowledge,
                                  templates, fluents, events, actions, predicates, ontology, target]).

spell_number(W, Ws) :-
    (   atom_number(W, N), integer(N), N >= 0, N =< 9999
    ->  format(atom(A), '~w', [N]), atom_chars(A, Ds),
        maplist([D, S]>>( atom_number(D, K), nth0(K, [zero,one,two,three,four,five,six,seven,eight,nine], S) ), Ds, Ws)
    ;   Ws = [W]
    ).

singular_words(Ws0, Ws) :-
    (   append(Front, [Last], Ws0), atom_concat(Stem, s, Last), atom_length(Stem, L), L > 2,
        \+ atom_concat(_, ss, Last)
    ->  append(Front, [Stem], Ws)
    ;   Ws = Ws0
    ).
