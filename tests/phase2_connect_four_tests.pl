:- module(phase2_connect_four_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/mesalog').
:- use_module('../src/games/connect_four').

% Phase 2, Subphase 3: Connect Four game module validation.

:- begin_tests(phase2_connect_four).

test(c4_initial_state) :-
    game:initial_state(connect_four, State),
    State = c4_state(Board, red),
    length(Board, 6),
    Board = [Row1|_],
    length(Row1, 7),
    assertion(Board == [
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e]
    ]).

test(c4_initial_player) :-
    game:initial_player(connect_four, Player),
    assertion(Player == red).

test(c4_current_player) :-
    game:current_player(connect_four, c4_state([[e,e,e,e,e,e,e],[e,e,e,e,e,e,e],[e,e,e,e,e,e,e],[e,e,e,e,e,e,e],[e,e,e,e,e,e,e],[e,e,e,e,e,e,e]], yellow), Player),
    assertion(Player == yellow).

test(c4_legal_moves_initial) :-
    game:initial_state(connect_four, State),
    game:legal_moves(connect_four, State, Moves),
    assertion(Moves == [drop(1),drop(2),drop(3),drop(4),drop(5),drop(6),drop(7)]).

test(c4_legal_moves_excludes_full_column) :-
    Board = [
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e]
    ],
    game:legal_moves(connect_four, c4_state(Board, red), Moves),
    assertion(Moves == [drop(2),drop(3),drop(4),drop(5),drop(6),drop(7)]).

test(c4_legal_moves_terminal_empty) :-
    Board = [
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [red,red,red,red,e,e,e],
        [yellow,yellow,yellow,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e]
    ],
    game:legal_moves(connect_four, c4_state(Board, yellow), Moves),
    assertion(Moves == []).

test(c4_valid_move_legal) :-
    game:initial_state(connect_four, State),
    assertion(game:valid_move(connect_four, State, drop(4))).

test(c4_valid_move_rejects_full_column, [fail]) :-
    Board = [
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e]
    ],
    game:valid_move(connect_four, c4_state(Board, red), drop(1)).

test(c4_valid_move_rejects_out_of_range, [fail]) :-
    game:initial_state(connect_four, State),
    game:valid_move(connect_four, State, drop(8)).

test(c4_apply_move_gravity_and_switch) :-
    game:initial_state(connect_four, State),
    game:apply_move(connect_four, State, drop(4), NewState),
    assertion(State = c4_state(_, red)),
    assertion(NewState == c4_state([
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,red,e,e,e]
    ], yellow)).

test(c4_apply_move_stacks_on_existing_piece) :-
    State = c4_state([
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,red,e,e,e]
    ], yellow),
    game:apply_move(connect_four, State, drop(4), NewState),
    assertion(NewState == c4_state([
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,yellow,e,e,e],
        [e,e,e,red,e,e,e]
    ], red)).

test(c4_terminal_win_horizontal) :-
    Board = [
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [red,red,red,red,yellow,yellow,e]
    ],
    game:terminal_state(connect_four, c4_state(Board, yellow), Result),
    assertion(Result == win(red)).

test(c4_terminal_win_vertical) :-
    Board = [
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [red,yellow,yellow,yellow,e,e,e]
    ],
    game:terminal_state(connect_four, c4_state(Board, yellow), Result),
    assertion(Result == win(red)).

test(c4_terminal_win_diagonal) :-
    Board = [
        [e,e,e,e,e,e,e],
        [e,e,e,e,e,e,e],
        [e,e,e,red,e,e,e],
        [e,e,red,yellow,e,e,e],
        [e,red,yellow,yellow,e,e,e],
        [red,yellow,red,yellow,e,e,e]
    ],
    game:terminal_state(connect_four, c4_state(Board, yellow), Result),
    assertion(Result == win(red)).

test(c4_terminal_draw) :-
    Board = [
        [yellow,yellow,red,yellow,yellow,red,yellow],
        [red,red,yellow,red,red,yellow,red],
        [yellow,yellow,red,yellow,yellow,red,yellow],
        [red,red,yellow,red,red,yellow,red],
        [yellow,yellow,red,yellow,yellow,red,yellow],
        [red,red,yellow,red,red,yellow,red]
    ],
    game:legal_moves(connect_four, c4_state(Board, red), Moves),
    assertion(Moves == []),
    game:terminal_state(connect_four, c4_state(Board, red), Result),
    assertion(Result == draw).

test(c4_terminal_non_terminal, [fail]) :-
    game:initial_state(connect_four, State),
    game:terminal_state(connect_four, State, _Result).

test(c4_display_state_succeeds) :-
    game:initial_state(connect_four, State),
    with_output_to(string(_Output), game:display_state(connect_four, State)).

test(c4_features_initial) :-
    game:initial_state(connect_four, State),
    game:features(connect_four, State, Features),
    assertion(Features.current_player == red),
    assertion(Features.opponent == yellow),
    assertion(Features.red_count == 0),
    assertion(Features.yellow_count == 0),
    assertion(Features.empty_count == 42),
    assertion(Features.current_player_center_control == 0).

test(c4_engine_integration_init_and_status) :-
    engine:init_match(connect_four, [red-first_legal, yellow-first_legal], Match),
    engine:match_status(Match, Status),
    assertion(Status == ongoing(red)).

test(c4_engine_integration_step) :-
    engine:init_match(connect_four, [red-fixed(drop(4)), yellow-fixed(drop(4))], Match0),
    engine:step_match(Match0, Move1, Match1),
    engine:step_match(Match1, Move2, Match2),
    engine:match_state(Match2, State),
    assertion(Move1 == drop(4)),
    assertion(Move2 == drop(4)),
    State = c4_state(Board, red),
    assertion(board_cell_test(Board, 6, 4, red)),
    assertion(board_cell_test(Board, 5, 4, yellow)).

board_cell_test(Board, Row, Col, Cell) :-
    nth1(Row, Board, BoardRow),
    nth1(Col, BoardRow, Cell).

test(c4_mesalog_validate_move_ok) :-
    game:initial_state(connect_four, State),
    mesalog:validate_move(connect_four, State, drop(1), Validation),
    assertion(Validation == ok).

test(c4_mesalog_validate_move_invalid) :-
    Board = [
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],
        [red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e]
    ],
    mesalog:validate_move(connect_four, c4_state(Board, red), drop(1), Validation),
    assertion(Validation == error(invalid_move(drop(1)))).

test(c4_mesalog_try_move_ok) :-
    engine:init_match(connect_four, [red-first_legal, yellow-first_legal], Match0),
    mesalog:try_move(Match0, drop(1), Outcome),
    Outcome = ok(match(connect_four, c4_state(Board, yellow), _)),
    assertion(board_cell_test(Board, 6, 1, red)).

test(c4_mesalog_load_game) :-
    mesalog:load_game(connect_four).

:- end_tests(phase2_connect_four).
