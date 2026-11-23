:- module(phase2_nim_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/mesalog').
:- use_module('../src/games/nim').

% Phase 2, Subphase 1: Nim game module validation.
%
% These tests verify that the Nim module conforms to the generic MesaLog game
% contract and integrates with the match engine and validation flow.

:- begin_tests(phase2_nim).

test(nim_initial_state) :-
    game:initial_state(nim, State),
    assertion(State == nim_state([3, 4, 5], player1)).

test(nim_initial_player) :-
    game:initial_player(nim, Player),
    assertion(Player == player1).

test(nim_current_player) :-
    game:current_player(nim, nim_state([3, 4, 5], player2), Player),
    assertion(Player == player2).

test(nim_legal_moves_initial_state_count_and_shape) :-
    game:initial_state(nim, State),
    game:legal_moves(nim, State, Moves),
    assertion(Moves == [
        remove(1, 1), remove(1, 2), remove(1, 3),
        remove(2, 1), remove(2, 2), remove(2, 3), remove(2, 4),
        remove(3, 1), remove(3, 2), remove(3, 3), remove(3, 4), remove(3, 5)
    ]).

test(nim_legal_moves_terminal_state) :-
    game:legal_moves(nim, nim_state([0, 0, 0], player1), Moves),
    assertion(Moves == []).

test(nim_valid_move_legal) :-
    game:initial_state(nim, State),
    assertion(game:valid_move(nim, State, remove(2, 3))).

test(nim_valid_move_rejects_zero_amount, [fail]) :-
    game:initial_state(nim, State),
    game:valid_move(nim, State, remove(1, 0)).

test(nim_valid_move_rejects_too_large_amount, [fail]) :-
    game:initial_state(nim, State),
    game:valid_move(nim, State, remove(1, 4)).

test(nim_valid_move_rejects_invalid_heap, [fail]) :-
    game:initial_state(nim, State),
    game:valid_move(nim, State, remove(4, 1)).

test(nim_valid_move_rejects_terminal_state, [fail]) :-
    game:valid_move(nim, nim_state([0, 0, 0], player1), remove(1, 1)).

test(nim_apply_move_updates_heap_and_switches_player) :-
    State = nim_state([3, 4, 5], player1),
    game:apply_move(nim, State, remove(2, 3), NewState),
    assertion(State == nim_state([3, 4, 5], player1)),
    assertion(NewState == nim_state([3, 1, 5], player2)).

test(nim_apply_move_can_empty_heap) :-
    game:apply_move(nim, nim_state([3, 4, 5], player2), remove(1, 3), NewState),
    assertion(NewState == nim_state([0, 4, 5], player1)).

test(nim_terminal_state_non_terminal, [fail]) :-
    game:terminal_state(nim, nim_state([0, 1, 0], player2), _Result).

test(nim_terminal_state_normal_play_winner) :-
    game:terminal_state(nim, nim_state([0, 0, 0], player2), Result),
    assertion(Result == win(player1)).

test(nim_terminal_state_after_last_move) :-
    game:apply_move(nim, nim_state([0, 0, 2], player1), remove(3, 2), NewState),
    assertion(NewState == nim_state([0, 0, 0], player2)),
    game:terminal_state(nim, NewState, Result),
    assertion(Result == win(player1)).

test(nim_display_state_succeeds) :-
    game:initial_state(nim, State),
    with_output_to(string(_Output), game:display_state(nim, State)).

test(nim_features) :-
    game:features(nim, nim_state([3, 4, 5], player1), Features),
    assertion(Features.current_player == player1),
    assertion(Features.opponent == player2),
    assertion(Features.heaps == [3, 4, 5]),
    assertion(Features.total_objects == 12),
    assertion(Features.non_empty_heaps == 3),
    assertion(Features.max_heap == 5),
    assertion(Features.nim_sum == 2).

test(nim_engine_integration_init_and_status) :-
    engine:init_match(nim, [player1-first_legal, player2-first_legal], Match),
    engine:match_status(Match, Status),
    engine:current_player_turn(Match, Player),
    assertion(Status == ongoing(player1)),
    assertion(Player == player1).

test(nim_engine_integration_step) :-
    engine:init_match(nim, [player1-fixed(remove(1, 3)), player2-fixed(remove(2, 4))], Match0),
    engine:step_match(Match0, Move1, Match1),
    engine:step_match(Match1, Move2, Match2),
    engine:match_state(Match2, State2),
    assertion(Move1 == remove(1, 3)),
    assertion(Move2 == remove(2, 4)),
    assertion(State2 == nim_state([0, 0, 5], player1)).

test(nim_mesalog_validate_move_ok) :-
    game:initial_state(nim, State),
    mesalog:validate_move(nim, State, remove(3, 1), Validation),
    assertion(Validation == ok).

test(nim_mesalog_validate_move_invalid) :-
    game:initial_state(nim, State),
    mesalog:validate_move(nim, State, remove(3, 9), Validation),
    assertion(Validation == error(invalid_move(remove(3, 9)))).

test(nim_mesalog_try_move_ok) :-
    engine:init_match(nim, [player1-first_legal, player2-first_legal], Match0),
    mesalog:try_move(Match0, remove(1, 1), Outcome),
    assertion(Outcome == ok(match(nim, nim_state([2, 4, 5], player2), [player1-first_legal, player2-first_legal]))).

test(nim_mesalog_load_game) :-
    mesalog:load_game(nim).

:- end_tests(phase2_nim).
