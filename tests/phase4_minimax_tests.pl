:- module(phase4_minimax_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/ai').
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').

% Phase 4, Subphase 1: plain minimax validation.
%
% A tiny deterministic game is used to observe maximizing/minimizing roles and
% perspective-relative terminal evaluation without a large search tree. Real
% Nim and Tic-Tac-Toe positions then confirm the same behavior through the
% generic game contract.

:- multifile
    game:initial_state/2,
    game:initial_player/2,
    game:current_player/3,
    game:legal_moves/3,
    game:valid_move/3,
    game:apply_move/4,
    game:terminal_state/3.

game:initial_state(minimax_test_game, s(root, p1)).
game:initial_player(minimax_test_game, p1).
game:current_player(minimax_test_game, s(_Node, Player), Player).

game:legal_moves(minimax_test_game, s(root, p1), [left, right]) :- !.
game:legal_moves(minimax_test_game, s(left, p2), [a, b]) :- !.
game:legal_moves(minimax_test_game, s(right, p2), [c, d]) :- !.
game:legal_moves(minimax_test_game, s(tie, p1), [first, second]) :- !.
game:legal_moves(minimax_test_game, s(_Terminal, _Player), []).

game:valid_move(minimax_test_game, State, Move) :-
    game:legal_moves(minimax_test_game, State, Moves),
    memberchk(Move, Moves).

game:apply_move(minimax_test_game, s(root, p1), left, s(left, p2)).
game:apply_move(minimax_test_game, s(root, p1), right, s(right, p2)).
game:apply_move(minimax_test_game, s(left, p2), a, s(win_p1, p1)).
game:apply_move(minimax_test_game, s(left, p2), b, s(lose_p1, p1)).
game:apply_move(minimax_test_game, s(right, p2), c, s(draw, p1)).
game:apply_move(minimax_test_game, s(right, p2), d, s(win_p1, p1)).
game:apply_move(minimax_test_game, s(tie, p1), first, s(draw, p2)).
game:apply_move(minimax_test_game, s(tie, p1), second, s(draw, p2)).

game:terminal_state(minimax_test_game, s(win_p1, _), win(p1)).
game:terminal_state(minimax_test_game, s(lose_p1, _), win(p2)).
game:terminal_state(minimax_test_game, s(draw, _), draw).

:- begin_tests(phase4_minimax).

test(terminal_scores_are_perspective_relative) :-
    ai:minimax(minimax_test_game, s(win_p1, p1), p1, 1),
    ai:minimax(minimax_test_game, s(lose_p1, p1), p1, -1),
    ai:minimax(minimax_test_game, s(draw, p1), p1, 0),
    ai:minimax(minimax_test_game, s(win_p1, p2), p2, -1),
    ai:minimax(minimax_test_game, s(lose_p1, p2), p2, 1),
    ai:minimax(minimax_test_game, s(draw, p2), p2, 0).

test(minimax_uses_minimizing_opponent) :-
    ai:minimax(minimax_test_game, s(left, p2), p1, -1),
    ai:minimax(minimax_test_game, s(right, p2), p1, 0),
    ai:minimax(minimax_test_game, s(left, p2), p2, 1).

test(minimax_evaluates_root_from_perspective) :-
    ai:minimax(minimax_test_game, s(root, p1), p1, 0).

test(choose_best_move_selects_optimal_move) :-
    ai:choose_best_move(minimax_test_game, s(root, p1), p1, Move, Score),
    assertion(Move == right),
    assertion(Score == 0).

test(choose_best_move_keeps_first_move_on_ties) :-
    ai:choose_best_move(minimax_test_game, s(tie, p1), p1, Move, Score),
    assertion(Move == first),
    assertion(Score == 0).

test(choose_best_move_requires_perspective_turn) :-
    assertion(\+ ai:choose_best_move(minimax_test_game, s(left, p2), p1, _, _)).

test(minimax_does_not_mutate_state) :-
    State = nim_state([1,2], player1),
    ai:minimax(nim, State, player1, _Score),
    assertion(State == nim_state([1,2], player1)).

test(minimax_solves_small_nim_position) :-
    State = nim_state([1,2], player1),
    ai:minimax(nim, State, player1, Score),
    assertion(Score == 1),
    ai:choose_best_move(nim, State, player1, Move, BestScore),
    assertion(Move == remove(2,1)),
    assertion(BestScore == 1).

test(minimax_nim_score_is_perspective_relative) :-
    ai:minimax(nim, nim_state([1,2], player1), player2, Score),
    assertion(Score == -1).

test(minimax_tic_tac_toe_takes_immediate_win) :-
    State = ttt_state([[x,x,e],[o,o,x],[o,e,o]], x),
    ai:minimax(tic_tac_toe, State, x, Score),
    assertion(Score == 1),
    ai:choose_best_move(tic_tac_toe, State, x, Move, BestScore),
    assertion(Move == place(1,3)),
    assertion(BestScore == 1).

test(minimax_tic_tac_toe_perspective_flip) :-
    State = ttt_state([[x,x,e],[o,o,x],[o,e,o]], x),
    ai:minimax(tic_tac_toe, State, o, Score),
    assertion(Score == -1).

:- end_tests(phase4_minimax).
