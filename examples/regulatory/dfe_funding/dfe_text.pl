/*  dfe_text.pl — the two text operations of the DfE 16 to 19 funding rules

    The rulebase uses ToUpper() (pages 37-89) and "contains" (pages 55 and
    87). These are the templates of dfe_16_19_funding.le that answer them,
    under the names LE gives the templates:

        the upper case of *a text* is *an upper case text*.
        *a text* contains *a part*.

    Loaded as a Prolog resource (docs/user/reference/language.md §14.1).
    No cuts: LE's reasoner runs a resource's clauses itself.
*/

le_dfe_text_string(T, S) :- string(T), S = T.
le_dfe_text_string(T, S) :- atom(T), atom_string(T, S).
le_dfe_text_string(T, S) :- number(T), number_string(T, S).

the_upper_case_of_is(T, U) :-
    le_dfe_text_string(T, S),
    string_upper(S, U).

contains(T, P) :-
    le_dfe_text_string(T, S),
    le_dfe_text_string(P, Q),
    sub_string(S, _, _, _, Q).
