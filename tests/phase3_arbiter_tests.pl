:- module(phase3_arbiter_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/arbiter').
:- use_module('../src/explanation').
:- use_module('../src/mesalog', [validate_move/4]).
:- use_module('../src/game').
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').
:- use_module('../src/games/connect_four').

:- begin_tests(phase3_arbiter).

test(nim_valid_move) :-
    game:initial_state(nim, State),
    arbiter:check_move(nim, State, remove(1,2), Verdict),
    assertion(Verdict == valid).

test(nim_invalid_shape) :-
    game:initial_state(nim, State),
    arbiter:check_move(nim, State, remove(one,2), Verdict),
    assertion(Verdict == invalid(invalid_move_shape(remove(one,2)))).

test(nim_heap_out_of_range) :-
    game:initial_state(nim, State),
    arbiter:check_move(nim, State, remove(9,1), Verdict),
    assertion(Verdict == invalid(heap_out_of_range(heap(9,3)))).

test(nim_invalid_amount) :-
    game:initial_state(nim, State),
    arbiter:check_move(nim, State, remove(1,5), Verdict),
    assertion(Verdict == invalid(invalid_amount(amount(5,3)))).

test(ttt_cell_occupied) :-
    State = ttt_state([[x,e,e],[e,e,e],[e,e,e]], o),
    arbiter:check_move(tic_tac_toe, State, place(1,1), Verdict),
    assertion(Verdict == invalid(cell_occupied(row_col(1,1), x))).

test(ttt_out_of_bounds) :-
    game:initial_state(tic_tac_toe, State),
    arbiter:check_move(tic_tac_toe, State, place(0,2), Verdict),
    assertion(Verdict == invalid(out_of_bounds(row_col(0,2), bounds(1,3,1,3)))).

test(c4_column_full) :-
    Board = [
        [red,e,e,e,e,e,e],[yellow,e,e,e,e,e,e],[red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],[red,e,e,e,e,e,e],[yellow,e,e,e,e,e,e]
    ],
    arbiter:check_move(connect_four, c4_state(Board, red), drop(1), Verdict),
    assertion(Verdict == invalid(column_full(column(1)))).

test(c4_out_of_bounds) :-
    game:initial_state(connect_four, State),
    arbiter:check_move(connect_four, State, drop(8), Verdict),
    assertion(Verdict == invalid(out_of_bounds(column(8), bounds(1,7)))).

test(explain_move_invalid_has_message) :-
    game:initial_state(tic_tac_toe, State),
    explanation:explain_move(tic_tac_toe, State, place(4,1), Verdict, Explanation),
    assertion(Verdict == invalid(out_of_bounds(row_col(4,1), bounds(1,3,1,3)))),
    assertion(Explanation.reason == out_of_bounds(row_col(4,1), bounds(1,3,1,3))),
    get_dict(message, Explanation, Msg),
    assertion(atom(Msg)).

test(explain_status_ongoing) :-
    game:initial_state(nim, State),
    explanation:explain_status(nim, State, Status, Explanation),
    assertion(Status == ongoing(player1)),
    get_dict(message, Explanation, Msg),
    assertion(atom(Msg)).

test(mesalog_validate_uses_arbiter_reason) :-
    game:initial_state(tic_tac_toe, State),
    mesalog:validate_move(tic_tac_toe, State, place(1,1), ok),
    mesalog:validate_move(tic_tac_toe, ttt_state([[x,e,e],[e,e,e],[e,e,e]], o), place(1,1), Validation),
    assertion(Validation == error(cell_occupied(row_col(1,1), x))).

:- end_tests(phase3_arbiter).
