:- module(ai_demo, [
    demo/0,
    demo_move/0,
    demo_comparison/0,
    demo_match/0
]).

:- use_module('../src/ai').
:- use_module('../src/ai_stats').
:- use_module('../src/engine').
:- use_module('../src/mesalog').
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').

% Runnable AI demo for MesaLog (Phase 4, Subphase 4).
%
% It demonstrates three deliverables of Phase 4:
% - AI move selection on known Nim and Tic-Tac-Toe positions.
% - Minimax vs alpha-beta search statistics on the same position.
% - A complete match driven by an AI controller through the engine.
%
% Run with:
%   swipl -q -g "consult('examples/ai_demo.pl'), demo, halt."

demo :-
    demo_move,
    demo_comparison,
    demo_match.

demo_move :-
    format('AI move selection~n', []),
    ai:choose_best_move_alpha_beta(nim, nim_state([3,4,5], player1),
                                   player1, NimMove, NimScore),
    format('  Nim [3,4,5]: ~w (score ~w)~n', [NimMove, NimScore]),
    TttState = ttt_state([[x,x,e],[o,o,x],[o,e,o]], x),
    ai:choose_best_move_alpha_beta(tic_tac_toe, TttState, x,
                                   TttMove, TttScore),
    format('  Tic-Tac-Toe immediate win: ~w (score ~w)~n',
           [TttMove, TttScore]).

demo_comparison :-
    ai_stats:print_comparison('Search comparison: Nim [2,3], depth 3',
                              nim, nim_state([2,3], player1), player1, 3).

demo_match :-
    format('AI vs first_legal Tic-Tac-Toe match (depth 2)~n', []),
    engine:init_match(tic_tac_toe, [x-ai(alpha_beta, 2), o-first_legal], Match),
    play_demo(Match, 0).

play_demo(Match, Turn) :-
    (   engine:match_status(Match, finished(Result))
    ->  format('  result: ~w~n', [Result])
    ;   Turn < 9,
        mesalog:try_step(Match, Outcome),
        (   Outcome = ok(Move, NextMatch)
        ->  format('  move ~w: ~w~n', [Turn, Move]),
            NextTurn is Turn + 1,
            play_demo(NextMatch, NextTurn)
        ;   format('  step outcome: ~w~n', [Outcome])
        )
    ).
