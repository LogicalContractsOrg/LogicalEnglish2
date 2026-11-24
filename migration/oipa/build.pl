/*  Build the OIPA twins into LE2's examples/migration/oipa (twins_dir/2).

    From /work (the LE2 checkout):

        ./myswipl.sh -q migration/oipa/build.pl

    One twin per transaction of each plan of corpus/ (the synthetic annuity
    and term life plans); the expected values come from oipa_eval.py
    (Python 3) over each plan's cases.json.
*/

:- initialization(main, main).

:- prolog_load_context(directory, D), asserta(user:oipa_dir(D)).
:- use_module('../le2_paths').
:- twins_dir(oipa, Out), asserta(user:oipa_out_dir(Out)).

:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(oipa_twin).

main(_) :-
    user:oipa_out_dir(Out), user:oipa_dir(D),
    make_directory_path(Out),
    forall(member(P, [annuity, termlife]),
           ( atomic_list_concat([D, '/corpus/', P], PD),
             catch(build_plan(PD, Out), E, print_message(error, E)) )).
