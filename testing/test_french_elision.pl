/*  French elision and contraction (languages.csv: elisions, contractions):
    the tokenizer reads "l'autre" as "le autre" and "au" as "à le", a
    dictionary cell may be written with short forms, the writer writes them,
    and a test's expected answer may use either form. Also: an apostrophe
    after a letter never opens a string, and a template beginning with
    "le" does not take the `le_` prefix the system reserves.
*/
:- use_module('../le_kbs').
:- use_module('../tokenizer').
:- use_module('../le_i18n').
:- use_module('../le_writer').

:- begin_tests(french_elision).

words(Ts, Ws) :- findall(W, member(word(W, _), Ts), Ws).

test(elision_split) :-
    tokenizer:tokenize("la mère d'Émile et l'autre personne", ',', '.', fr, Ts),
    words(Ts, Ws),
    Ws == [la, mère, de, 'Émile', et, le, autre, personne].

test(contraction_split) :-
    tokenizer:tokenize("Au marché du village s'il pleut", ',', '.', fr, Ts),
    words(Ts, Ws),
    Ws == ['À', le, marché, de, le, village, si, il, pleut].

test(apostrophe_never_opens_a_string) :-
    tokenizer:tokenize("the employers' fund is 'Bob'", Ts),
    memberchk(quoteString("Bob", _), Ts),
    memberchk(word('employers\'', _), Ts).

test(cell_with_short_forms) :-
    le_i18n:with_le_language(fr,
        findall(W, le_i18n:kw_synonym_words(provenance_required, W), Ws)),
    memberchk([les, faits, de, le, 'scénario', exigent, une, provenance], Ws).

test(writer_elides) :-
    le_writer:elide_text(fr, "la mère de une autre personne va à le marché si il pleut \"de une\"", T),
    T == "la mère d'une autre personne va au marché s'il pleut \"de une\"".

%   A variable named like a word that elides (NE, LE) is left as it is.
test(writer_keeps_variables) :-
    le_writer:elide_text(fr, "le maximum de 0 et NE est un nombre et LE est A", T),
    T == "le maximum de 0 et NE est un nombre et LE est A".

%   The first word of a line elides too (a rule's conclusion).
test(writer_elides_at_line_start) :-
    le_i18n:with_le_language(fr, le_writer:elide_text(fr, "règle r:\nla aide de une famille est un montant si\n    la autre est A", T)),
    T == "règle r:\nl'aide d'une famille est un montant si\n    l'autre est A".

test(writer_leaves_h_alone) :-
    le_writer:elide_text(fr, "à le hôtel", T),
    T == "à le hôtel".

test(expected_answer_with_elision) :-
    le_i18n:with_le_language(fr,
        ( le_kbs:normalize_string("Alice est la mère d'Émile", A),
          le_kbs:normalize_string("Alice est la mère de Émile", B) )),
    A == B.

%   An answer shown with the decimal comma ("500,0") is the number an
%   expectation writes without decimals ("500").
test(expected_answer_with_decimal_comma) :-
    le_i18n:with_le_language(fr,
        ( le_kbs:normalize_string("le montant de a est 500,0", A),
          le_kbs:normalize_string("le montant de a est 500", B),
          le_kbs:normalize_string("le montant de a est 27,5", C),
          le_kbs:normalize_string("le montant de a est 27", D) )),
    A == B, C \== D.

%   Tokenizing leaves nothing to backtrack into: a choice point per word
%   kept a long French program's whole text alive and ran it out of stack.
test(tokenize_is_deterministic) :-
    tokenizer:tokenize("l'autre va au marché d'une ville s'il pleut, 1,5 fois.", ',', '.', fr, Ts),
    memberchk(word(le, _), Ts), memberchk(word(autre, _), Ts).

test(template_beginning_with_le) :-
    le_grammar:template_functor([le, taux, de, est], F),
    F == t_le_taux_de_est.

:- end_tests(french_elision).
