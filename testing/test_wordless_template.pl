/* test_wordless_template.pl — a template with no word outside its argument
   places matches every sentence of a program. It is an error and is dropped,
   so that the sentences it would take keep their own meaning. */

:- use_module(library(plunit)).
:- use_module('../le_kbs').

wordless_program("the target language is: prolog.

the templates are:
    *a person* is rich; undefined.
    *an exemption expressly covers a trustee service*; undefined.

the knowledge base k includes:
the text of the policy is at \"policy.md\".

a person is happy
    if the person is rich
    and 2026-01-01 is before or equal to 2027-03-31.

scenario s is:
    ann is rich.

query q is:
    which person is happy.
").

:- begin_tests(wordless_template).

test(reported_and_dropped) :-
    wordless_program(T),
    le_kbs:load_text(T, KB),
    once(KB:le_issue(error, wordless_template, Desc, _, _, _)),
    assertion(sub_string(Desc, _, _, _, "*an exemption expressly covers a trustee service*")),
    % the document statement and the date comparison keep their meaning
    assertion(KB:le_text_at('the policy', _)),
    \+ ( KB:le_source_info(R, _, _, _), catch(clause(KB:H, _, R), _, fail), functor(H, '', _) ),
    \+ ( KB:le_source_info(R2, _, _, _), catch(clause(KB:_, B, R2), _, fail),
         sub_term(G, B), compound(G), functor(G, '', _) ).

:- end_tests(wordless_template).
