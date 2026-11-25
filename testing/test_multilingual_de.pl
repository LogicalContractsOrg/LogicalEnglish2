/* test_multilingual_de.pl — Logisches Deutsch.

   German needs four things that the other languages do not (languages.csv:
   `word_order`, `inflection_endings`, `noun_endings`, `clause_commas`,
   `value_contractions`), and these tests check each one on small programs:

   - the verb of a template stands last after `wenn` and `dass`, and first
     after a word that takes the first place of the sentence;
   - an adjective that tells two variables apart changes its ending with the
     article and the case ("ein erster", "der erste", "dem ersten"), and a
     noun may add an ending in another case ("der Kunde", "dem Kunden");
   - a comma separates the clauses of a rule;
   - `am`, `im`, `zum` are `an dem`, `in dem`, `zu dem`, and before a date or
     a number only `an`, `in`, `zu`.

   The example programs of examples/de/ run with the example suite.
*/
:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_i18n').
:- use_module('../tokenizer').

:- begin_tests(multilingual_de).

test(detect_de) :-
    tokenizer:tokenize("die Zielsprache ist: prolog.", Ts),
    le_i18n:detect_language_tokens(Ts, de).

test(de_keywords, [nondet]) :-
    le_i18n:with_le_language(de, (
        le_i18n:kw_synonym_words(if, [wenn]),
        le_i18n:kw_synonym_words(if, [falls]),
        le_i18n:class_member(article, einem),
        le_i18n:class_member(definite_article, dem),
        le_i18n:kw_synonym_words(not_the_case, [es, ist, nicht, der, 'Fall', dass]),
        le_i18n:kw_synonym_words(lps_time_noun, ['Zeitpunkt'])
    )).

test(de_number_locale) :-
    tokenizer:tokenize("das Gehalt ist 1.250.000 und der Bonus ist 10.000,5", ',', '.', Ts),
    memberchk(number(1250000, _), Ts),
    memberchk(number(10000.5, _), Ts).

%   am, im, zum: two words, except before a date or a number.
test(de_contractions) :-
    tokenizer:tokenize("John wurde am 2021-10-09 im Vereinigten Königreich zum Bürger", ',', '.', de, Ts),
    findall(W, member(word(W, _), Ts), Ws),
    Ws == ['John', wurde, an, in, dem, 'Vereinigten', 'Königreich', zu, dem, 'Bürger'].

%   A comma before wenn, dass, und is no part of the sentence; a comma in a
%   list stays.
test(de_clause_commas) :-
    tokenizer:tokenize("A ist glücklich, wenn A reich ist, und [1, 5]", ',', '.', de, Ts),
    findall(P, member(punctuation(P, _), Ts), Ps),
    msort(Ps, Sorted),
    Sorted == [',', '[', ']'].

test(de_qualifier_endings) :-
    le_i18n:with_le_language(de, (
        le_grammar:normalize_var_name('erster Zeitpunkt', N1),
        le_grammar:normalize_var_name('ersten Zeitpunkt', N2),
        le_grammar:normalize_var_name('erste Zeitpunkt', N3),
        le_grammar:normalize_var_name('andere Person', N4),
        le_grammar:normalize_var_name('anderen Person', N5)
    )),
    N1 == N2, N2 == N3, N4 == N5, N1 \== N4.

%   In English nothing is cut off a variable's name.
test(en_names_unchanged) :-
    le_i18n:with_le_language(en, le_grammar:normalize_var_name('other person', N)),
    N == 'other person'.

test(de_noun_endings) :-
    le_i18n:with_le_language(de, (
        le_grammar:vm_member('Kunden', V1, ['Kunde'-x]),
        le_grammar:vm_member('Betrags', V2, ['Betrag'-y]),
        \+ le_grammar:vm_member('Kundin', _, ['Kunde'-x])
    )),
    V1 == x, V2 == y.

test(en_no_noun_endings, [fail]) :-
    le_i18n:with_le_language(en, le_grammar:vm_member(persons, _, [person-x])).

:- end_tests(multilingual_de).

%   Whole programs, with the sentences as German writes them. Each program
%   carries its own expected answers (`erwartet die Antworten`), and passes
%   when every one of them is given.
:- begin_tests(multilingual_de_programs).

%   The program Text passes all its own tests, and there is at least one.
passes(Text) :-
    tmp_file_stream(text, File0, S0), close(S0),
    atom_concat(File0, '.le', File),
    setup_call_cleanup(
        ( open(File, write, S, [encoding(utf8)]), write(S, Text), close(S) ),
        le_kbs:runTestsFor(File, test_file(_, Results)),
        %  (loading a program leaves its language the active one of this
        %  thread: the next test file expects none)
        ( catch(delete_file(File), _, true), catch(delete_file(File0), _, true),
          le_i18n:set_le_language(default) )),
    Results \== [],
    forall(member(R, Results), R = pass(_, _)).

%   The verb last after `wenn` and `dass`; the negation inside a `wenn`
%   clause ("es nicht der Fall ist, dass"); commas between the clauses; a
%   variable in another case ("ein Kunde", "den Kunden", "welcher Kunde").
test(verb_last_negation_and_cases) :-
    passes("die Zielsprache ist: prolog.

die Vorlagen sind:
*eine Person* ist glücklich.
*eine Person* ist reich.
*eine Person* mag *ein Ding*.
*eine Person* zahlt *einen Betrag* an *einen Kunden*.
*ein Kunde* hat *einen Betrag* erhalten.

die Wissensbasis Test enthält:

eine Person ist glücklich,
    wenn die Person reich ist
    und es nicht der Fall ist, dass die Person Brokkoli mag.

ein Kunde hat einen Betrag erhalten,
    wenn eine Person den Betrag an den Kunden zahlt.

Szenario s ist:
    alice ist reich.
    bob ist reich.
    bob mag Brokkoli.
    alice zahlt 5 an carl.
    gluecklich erwartet die Antworten [\"alice ist glücklich\"].
    erhalten erwartet die Antworten [\"carl hat 5 erhalten\"].

Abfrage gluecklich ist:
    welche Person ist glücklich.

Abfrage erhalten ist:
    welcher Kunde hat welchen Betrag erhalten.
").

%   Two variables of one type, told apart by an adjective whose ending
%   changes ("eine andere Person", "der anderen Person", "die andere
%   Person"); a sentence after `dass` with its verb last; the short forms
%   `am` and `vom` before a date and before a noun.
test(adjective_endings_inner_sentence_and_dates) :-
    passes("die Zielsprache ist: prolog.

die Vorlagen sind:
*eine Person* ist die Mutter von *einer Person*.
*eine Person* ist ein Kind von *einer Person*.
*eine Person* erklärt, dass *ein Satz*.
*eine Person* ist an *einem Datum* volljährig.
*eine Person* wurde an *einem Datum* geboren.

die Wissensbasis Test enthält:

eine Person ist ein Kind von einer anderen Person,
    wenn die andere Person die Mutter von der Person ist.

eine Person ist ein Kind von einer anderen Person,
    wenn eine dritte Person erklärt, dass die andere Person die Mutter von der Person ist.

eine Person ist an einem Datum volljährig,
    wenn die Person an einem anderen Datum geboren wurde
    und das Datum nach dem anderen Datum liegt.

Szenario s ist:
    anna ist die Mutter von ben.
    carl erklärt, dass anna die Mutter von dora ist.
    ben wurde am 2000-01-01 geboren.
    kinder erwartet die Antworten [\"ben ist ein Kind von anna\", \"dora ist ein Kind von anna\"].
    volljaehrig erwartet die Antworten [\"ben ist am 2026-11-25 volljährig\"].

Abfrage kinder ist:
    welches Kind ist ein Kind von welcher Person.

Abfrage volljaehrig ist:
    welche Person ist am 2026-11-25 volljährig.
").

%   The same programs with `falls` and with the verb in the second place
%   (the order of the template) are read as well.
test(falls_and_template_order) :-
    passes("die Zielsprache ist: prolog.

die Vorlagen sind:
*eine Person* ist glücklich.
*eine Person* ist reich.

die Wissensbasis Test enthält:

eine Person ist glücklich
    falls die Person ist reich.

Szenario s ist:
    alice ist reich.
    q erwartet die Antworten [\"alice ist glücklich\"].

Abfrage q ist:
    welche Person ist glücklich.
").

:- end_tests(multilingual_de_programs).
