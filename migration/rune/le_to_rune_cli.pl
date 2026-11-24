/*  The command line of le_to_rune.pl (back.sh):

    ./myswipl.sh -q migration/rune/le_to_rune_cli.pl -- <LE file> <scenario> <template prefix> <Rune name> <out.rosetta>
*/
:- use_module(le_to_rune).
:- initialization(le_to_rune:main, main).
