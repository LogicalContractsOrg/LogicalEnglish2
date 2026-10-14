/*  Portuguese contractions (languages.csv, `contractions`): the tokenizer
    reads "do" as "de o", "na" as "em a", "ao" as "a o", "pela" as "por a",
    so that a template written "o rendimento de *uma pessoa*" matches "o
    rendimento do joão"; and the writer, Portuguese having no elisions,
    always contracts them back ("de o requerente" is "do requerente"),
    leaving text in quotes as it is. Until 14 October 2026 Portuguese had no
    contractions declared, and a sentence written as Portuguese is written
    silently failed to match its template.
*/
:- use_module('../le_kbs').
:- use_module('../tokenizer').
:- use_module('../le_i18n').
:- use_module('../le_writer').

:- begin_tests(portuguese_contraction).

words(Ts, Ws) :- findall(W, member(word(W, _), Ts), Ws).

test(contraction_split) :-
    tokenizer:tokenize("o rendimento do joão na data pela lei ao requerente", ',', '.', pt, Ts),
    words(Ts, Ws),
    Ws == [o, rendimento, de, o, 'joão', em, a, data, por, a, lei, a, o, requerente].

test(writer_contracts_always) :-
    le_writer:elide_text(pt, "o rendimento de o joão é de a ordem de os 400 e por a lei em o artigo a o requerente \"de o texto\"", T),
    T == "o rendimento do joão é da ordem dos 400 e pela lei no artigo ao requerente \"de o texto\"".

test(writer_leaves_a_variable_alone) :-
    le_writer:elide_text(pt, "e o máximo de A e J é um M", T),
    T == "e o máximo de A e J é um M".

test(template_matches_through_a_contraction, [nondet]) :-
    load_text("a linguagem alvo é: prolog.

os modelos são:
    o rendimento de *uma pessoa* é *um montante*.
    *uma pessoa* tem direito ao apoio.

a base de conhecimento pt inclui:

uma pessoa tem direito ao apoio
    se o rendimento da pessoa é um montante
    e o montante < 500.

cenário um é:
    o rendimento do joão é 400.
    o rendimento da maria é 900.

consulta q é:
    quem tem direito ao apoio.
", KB),
    createSession(KB, SM), setScenarion(SM, um),
    KB:query_info(q, G, _),
    findall(G, reasoner:i(G, SM, _, _), Gs),
    destroySession(SM),
    length(Gs, 1).

:- end_tests(portuguese_contraction).
