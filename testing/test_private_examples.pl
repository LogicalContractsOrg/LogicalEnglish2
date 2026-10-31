/** <module> The unlisted examples (le_kbs:le_private_examples_dir/2)

    A program under lpsPlus's examples/private/ opens for whoever knows its
    exact name (private/...), and a landing page ?dir=private/<folder> shows
    that folder. Nothing lists the tree: not the landing page's full list,
    not list_examples, not the examples' search, not the bare ?dir=private —
    and not for a licensed visitor either, who sees lpsPlus's examples/
    through the link examples/moreExamples/lpsPlus.

    The tests make a folder of their own in the private tree, with one
    program, and remove it afterwards. Without lpsPlus (or without its
    examples/private/) there is no private tree, and the tests are skipped.

    Run with:  swipl -q -g run_tests -t halt testing/test_private_examples.pl
*/

:- module(test_private_examples, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../le_kbs').
:- use_module('../le_api').
:- use_module('../le_examples_search').
:- use_module('../classic_web_api').
:- use_module('../wasm/pack').
:- use_module('../le_assistant_light').

%   The temporary folder (under examples/private/) and the program's word,
%   unlikely in any other example.
sub_folder(Sub) :-
    current_prolog_flag(pid, Pid),
    format(atom(Sub), 'zz_unlisted_test_~w', [Pid]).
program_word(quuxunlistedzork).

%   Every capability a restricted tree asks for: a licensed visitor.
all_roles(Roles) :-
    findall(R, ( restricted_paths:restricted_access_for(_, Rs), member(R, Rs) ), Roles0),
    sort(Roles0, Roles).

have_private_tree :- le_private_examples_dir(private, _).

example_dir(Dir) :-
    le_private_examples_dir(private, Root),
    sub_folder(Sub),
    atomic_list_concat([Root, '/', Sub], Dir).

make_private_example :-
    example_dir(Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/contract.le'], File),
    program_word(W),
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]),
                       format(Out, "% The ~w contract, for a test.~nthe templates are:~n*a person* is a ~w.~n~nthe knowledge base ~w includes:~nalice is a ~w.~n~nquery one is:~nwhich person is a ~w.~n",
                              [W, W, W, W, W]),
                       close(Out)).

remove_private_example :-
    example_dir(Dir),
    catch(delete_directory_and_contents(Dir), _, true).

private_name(Name) :-
    sub_folder(Sub),
    atomic_list_concat([private, Sub, contract], '/', Name).

term_mentions(Term, Text) :-
    with_output_to(string(S), print(Term)),
    sub_string(S, _, _, _, Text).

:- begin_tests(private_examples, [condition(have_private_tree),
                                  setup(make_private_example), cleanup(remove_private_example)]).

test(resolves_by_name) :-
    private_name(Name),
    le_example_relpath(Name, Path),
    example_dir(Dir),
    atom_concat(Dir, '/contract', Expected),
    assertion(Path == Expected).

test(loads_by_name_without_login) :-
    private_name(Name), atom_string(Name, NameS),
    le_api:handle_examples(_{file: NameS}, R),
    assertion(\+ get_dict(error, R, _)),
    program_word(W),
    assertion(sub_string(R.document, _, _, _, W)).

test(mcp_path_by_name) :-
    private_name(Name),
    le_tools:example_path_for(Name, [], Path),
    assertion(exists_file(Path)).

test(absent_from_list_examples) :-
    le_api:handle_list_examples(_{}, R),
    sub_folder(Sub),
    assertion(\+ ( member(E, R.examples), sub_atom(E, 0, _, _, 'private/') )),
    assertion(\+ term_mentions(R, Sub)).

%   A licensed visitor lists examples/moreExamples/lpsPlus, a link to
%   lpsPlus's examples/: its private/ is not listed there either.
test(absent_from_licensed_listing) :-
    all_roles(Roles),
    le_examples_dir(Dir), atom_concat(Dir, '/', DirSlash),
    le_api:list_examples_in_dir(DirSlash, '', Roles, Es),
    sub_folder(Sub),
    assertion(\+ ( member(E, Es), sub_atom(E, _, _, _, Sub) )),
    assertion(\+ ( member(E, Es), sub_atom(E, _, _, _, 'lpsPlus/private/') )).

%   What the search indexes: every example, whatever the visitor's rights.
test(absent_from_every_example) :-
    sub_folder(Sub),
    assertion(\+ ( le_api:every_example(N, _), sub_atom(N, _, _, _, Sub) )),
    assertion(\+ ( le_api:every_example(N, _), sub_atom(N, _, _, _, 'lpsPlus/private/') )).

test(absent_from_examples_search) :-
    program_word(W), atom_string(W, WS),
    examples_search(WS, [], Hits),
    assertion(Hits == []),
    all_roles(Roles),
    examples_search(WS, [roles(Roles)], LicensedHits),
    assertion(LicensedHits == []).

test(absent_from_landing_tree) :-
    le_examples_dir(Dir),
    classic_web_api:landing_focus('', Dir, [], Items, _),
    sub_folder(Sub),
    assertion(\+ term_mentions(Items, Sub)),
    assertion(\+ term_mentions(Items, 'private/')),
    all_roles(Roles),
    classic_web_api:landing_focus('', Dir, Roles, LicensedItems, _),
    assertion(\+ term_mentions(LicensedItems, Sub)),
    assertion(\+ term_mentions(LicensedItems, 'lpsPlus/private/')).

%   The assistant's list and the MCP tool's walk the trees the same way.
test(absent_from_assistant_list) :-
    all_roles(Roles),
    le_examples_dir(Dir), atom_concat(Dir, '/', DirSlash),
    get_time(T), Deadline is T - 1,      % past: no program is loaded for its summary
    le_assistant_light:list_examples_with_summaries(DirSlash, '', Roles, Deadline, Es),
    sub_folder(Sub),
    assertion(\+ term_mentions(Es, Sub)).

%   The example suite does not go into the private tree, even through a
%   link to it (as examples/moreExamples/lpsPlus/private is one): a folder
%   holding only such a link runs no test.
test(absent_from_example_suite) :-
    le_private_examples_dir(private, Root),
    tmp_file(suite, Tmp), make_directory(Tmp),
    atom_concat(Tmp, '/private', Link),
    setup_call_cleanup(link_file(Root, Link, symbolic),
                       le_kbs:runTestsInDir(Tmp, Results),
                       ( delete_file(Link), delete_directory(Tmp) )),
    assertion(Results == []).

test(not_in_the_browser_build) :-
    assertion(le_wasm_pack:never('examples/moreExamples/lpsPlus/private/README.md')).

:- end_tests(private_examples).
