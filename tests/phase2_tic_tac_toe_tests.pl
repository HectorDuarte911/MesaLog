:- module(phase2_tic_tac_toe_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/mesalog').
:- use_module('../src/games/tic_tac_toe').

% Phase 2, Subphase 2: Tic-Tac-Toe game module validation.
%
% These tests verify that the Tic-Tac-Toe module conforms to the generic
% MesaLog game contract and integrates with the match engine and validation flow.

:- begin_tests(phase2_tic_tac_toe).

test(ttt_initial_state) :-
    game:initial_state(tic_tac_toe, State),
    assertion(State == ttt_state([[e,e,e],[e,e,e],[e,e,e]], x)).

test(ttt_initial_player) :-
    game:initial_player(tic_tac_toe, Player),
    assertion(Player == x).

test(ttt_current_player) :-
    game:current_player(tic_tac_toe, ttt_state([[e,e,e],[e,e,e],[e,e,e]], o), Player),
    assertion(Player == o).

test(ttt_legal_moves_initial_count) :-
    game:initial_state(tic_tac_toe, State),
    game:legal_moves(tic_tac_toe, State, Moves),
    length(Moves, Count),
    assertion(Count == 9),
    assertion(memberchk(place(1,1), Moves)),
    assertion(memberchk(place(3,3), Moves)).

test(ttt_legal_moves_terminal_empty) :-
    Terminal = ttt_state([[x,x,x],[o,o,e],[e,e,e]], o),
    game:legal_moves(tic_tac_toe, Terminal, Moves),
    assertion(Moves == []).

test(ttt_valid_move_legal) :-
    game:initial_state(tic_tac_toe, State),
    assertion(game:valid_move(tic_tac_toe, State, place(2,2))).

test(ttt_valid_move_rejects_occupied, [fail]) :-
    State = ttt_state([[x,e,e],[e,e,e],[e,e,e]], o),
    game:valid_move(tic_tac_toe, State, place(1,1)).

test(ttt_valid_move_rejects_out_of_range, [fail]) :-
    game:initial_state(tic_tac_toe, State),
    game:valid_move(tic_tac_toe, State, place(0,1)).

test(ttt_valid_move_rejects_terminal, [fail]) :-
    Terminal = ttt_state([[x,x,x],[o,o,e],[e,e,e]], o),
    game:valid_move(tic_tac_toe, Terminal, place(2,3)).

test(ttt_apply_move_places_mark_and_switches_player) :-
    State = ttt_state([[e,e,e],[e,e,e],[e,e,e]], x),
    game:apply_move(tic_tac_toe, State, place(1,2), NewState),
    assertion(State == ttt_state([[e,e,e],[e,e,e],[e,e,e]], x)),
    assertion(NewState == ttt_state([[e,x,e],[e,e,e],[e,e,e]], o)).

test(ttt_apply_move_second_player) :-
    State = ttt_state([[e,x,e],[e,e,e],[e,e,e]], o),
    game:apply_move(tic_tac_toe, State, place(2,2), NewState),
    assertion(NewState == ttt_state([[e,x,e],[e,o,e],[e,e,e]], x)).

test(ttt_terminal_win_row) :-
    State = ttt_state([[x,x,x],[o,o,e],[e,e,e]], o),
    game:terminal_state(tic_tac_toe, State, Result),
    assertion(Result == win(x)).

test(ttt_terminal_win_column) :-
    State = ttt_state([[x,o,e],[x,o,e],[x,e,e]], o),
    game:terminal_state(tic_tac_toe, State, Result),
    assertion(Result == win(x)).

test(ttt_terminal_win_diagonal) :-
    State = ttt_state([[o,x,e],[x,o,e],[e,e,o]], x),
    game:terminal_state(tic_tac_toe, State, Result),
    assertion(Result == win(o)).

test(ttt_terminal_draw) :-
    State = ttt_state([[x,o,x],[x,o,o],[o,x,x]], o),
    game:terminal_state(tic_tac_toe, State, Result),
    assertion(Result == draw).

test(ttt_terminal_non_terminal, [fail]) :-
    game:terminal_state(tic_tac_toe, ttt_state([[x,o,e],[e,x,e],[e,e,o]], x), _Result).

test(ttt_display_state_succeeds) :-
    game:initial_state(tic_tac_toe, State),
    with_output_to(string(_Output), game:display_state(tic_tac_toe, State)).

test(ttt_features_initial) :-
    game:initial_state(tic_tac_toe, State),
    game:features(tic_tac_toe, State, Features),
    assertion(Features.current_player == x),
    assertion(Features.opponent == o),
    assertion(Features.x_count == 0),
    assertion(Features.o_count == 0),
    assertion(Features.empty_count == 9),
    assertion(Features.center_mark == e).

test(ttt_engine_integration_init_and_status) :-
    engine:init_match(tic_tac_toe, [x-first_legal, o-first_legal], Match),
    engine:match_status(Match, Status),
    assertion(Status == ongoing(x)).

test(ttt_engine_integration_steps) :-
    engine:init_match(tic_tac_toe, [x-fixed(place(1,1)), o-fixed(place(2,2))], Match0),
    engine:step_match(Match0, Move1, Match1),
    engine:step_match(Match1, Move2, Match2),
    engine:match_state(Match2, State),
    assertion(Move1 == place(1,1)),
    assertion(Move2 == place(2,2)),
    assertion(State == ttt_state([[x,e,e],[e,o,e],[e,e,e]], x)).

test(ttt_mesalog_validate_move_ok) :-
    game:initial_state(tic_tac_toe, State),
    mesalog:validate_move(tic_tac_toe, State, place(1,3), Validation),
    assertion(Validation == ok).

test(ttt_mesalog_validate_move_invalid) :-
    State = ttt_state([[x,e,e],[e,e,e],[e,e,e]], o),
    mesalog:validate_move(tic_tac_toe, State, place(1,1), Validation),
    assertion(Validation == error(cell_occupied(row_col(1,1), x))).

test(ttt_mesalog_try_move_ok) :-
    engine:init_match(tic_tac_toe, [x-first_legal, o-first_legal], Match0),
    mesalog:try_move(Match0, place(1,1), Outcome),
    assertion(Outcome == ok(match(tic_tac_toe, ttt_state([[x,e,e],[e,e,e],[e,e,e]], o), [x-first_legal, o-first_legal]))).

test(ttt_mesalog_load_game) :-
    mesalog:load_game(tic_tac_toe).

:- end_tests(phase2_tic_tac_toe).
