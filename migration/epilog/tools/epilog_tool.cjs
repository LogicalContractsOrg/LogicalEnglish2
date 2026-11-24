#!/usr/bin/env node
/*  EpilogJS (Stanford's Epilog interpreter) as a command line: the reader's
    parser and the translator's oracle. It loads epilog.js from ../.cache
    (fetched by fetch_sources.sh; its licence does not allow redistribution,
    so it is not in this repository) and answers JSON:

      parse <file>                      the sentences, as EpilogJS reads them
      query <data> <rules> <goal>...    each goal's answers (compfinds goal goal)
      game <library> [move ...]         a game: roles, the initial state (init,
                                        or the facts of $EPILOG_DATA), and
                                        after each move (compexecute on the
                                        state) the state and the legal moves;
                                        with no moves, it plays the first legal
                                        move until terminal or 12 moves
*/
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const lib = process.env.EPILOG_JS || path.join(__dirname, '..', '.cache', 'epilog.js');
vm.runInThisContext(fs.readFileSync(lib, 'utf8'), { filename: 'epilog.js' });
//  as the Epilog game pages set them: facts in plain arrays, rules indexed
vm.runInThisContext("indexing = false; dataindexing = false; ruleindexing = true;");
function copy(obj) { return obj.slice(0); }

const file = (f) => fs.readFileSync(f, 'utf8');
const out = (x) => process.stdout.write(JSON.stringify(x) + '\n');
const sorted = (xs) => xs.map((x) => grind(x)).sort();

function main() {
    const [cmd, ...args] = process.argv.slice(2);
    if (cmd === 'parse') {
        out(readdata(file(args[0])));
    } else if (cmd === 'query') {
        const facts = []; definefacts(facts, readdata(file(args[0])));
        const rules = []; definerules(rules, readdata(file(args[1])));
        const answers = args.slice(2).map((g) => {
            const q = read(g);
            try {
                const as = compfinds(q, q, facts, rules);
                return { goal: g, answers: sorted(as), terms: as };
            } catch (e) {
                //  an open query over an infinite relation (lists, sets)
                //  runs out of stack: no answers to compare with
                return { goal: g, error: String(e) };
            }
        });
        out(answers);
    } else if (cmd === 'game') {
        const library = []; definerules(library, readdata(file(args[0])));
        const roles = compfinds('R', seq('role', 'R'), seq(), library);
        //  a program with no game rules starts from a data sheet
        let state;
        if (process.env.EPILOG_DATA) { state = []; definefacts(state, readdata(file(process.env.EPILOG_DATA))); }
        else state = compfinds('P', seq('init', 'P'), seq(), library);
        const steps = [{ move: null, state: sorted(state), terms: state.slice(0), legal: sorted(legals(state, library)), terminal: terminalp(state, library) }];
        //  moves: given, or chosen among the legal ones by a fixed rule
        //  (the k-th move takes legal[(7k + seed) mod n]), reproducibly
        const seed = Number(process.env.EPILOG_SEED || 0);
        const moves = args.slice(1).map((m) => read(m));
        const max = Number(process.env.EPILOG_MOVES || 12);
        for (let i = 0; i < (moves.length || max); i++) {
            if (!moves.length && steps[steps.length - 1].terminal) break;
            const legal = legals(state, library);
            const ordered = legal.sort((a, b) => grind(a) < grind(b) ? -1 : 1);
            const move = moves.length ? moves[i] : ordered[(7 * i + seed) % Math.max(1, ordered.length)];
            if (move === undefined) break;
            state = copy(state);
            compexecute(move, state, library);
            steps.push({ move: grind(move), moveterm: move, state: sorted(state), terms: state.slice(0), legal: sorted(legals(state, library)), terminal: terminalp(state, library),
                         goals: roles.map((r) => [r, compfindx('R', seq('goal', r, 'R'), state, library) || 0]) });
        }
        out({ roles, steps });
    } else {
        process.stderr.write('usage: epilog_tool.cjs parse <file> | query <data> <rules> <goal>... | game <library> [move...]\n');
        process.exit(2);
    }
}
function legals(state, library) { return compfinds('X', seq('legal', 'X'), state, library); }
function terminalp(state, library) { return compfindp('terminal', state, library); }
main();
