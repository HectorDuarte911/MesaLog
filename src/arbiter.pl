:- module(arbiter, [
    check_move/4,
    invalid_reason/4,
    reason_message/2
]).

:- use_module(game).

:- discontiguous game_invalid_reason/4.

% Arbiter module for MesaLog (Phase 3).
%
% This module centralizes move validation against the generic game contract and
% provides structured reasons for invalid moves. It is designed to be used by
% integration layers (e.g. mesalog) and by explanation components.
%
% Validation flow:
% - finished(Result): state is terminal.
% - valid: move is accepted by game rules.
% - invalid(Reason): move is rejected with a structured reason.
%
% Reason terms are game-aware but normalized where possible:
% - game_finished(Result)
% - invalid_move_shape(Move)
% - out_of_bounds(Details, Bounds)
% - cell_occupied(Details, OccupiedBy)
% - heap_out_of_range(heap(Index, Count))
% - invalid_amount(amount(Amount, HeapSize))
% - column_full(column(Column))
% - invalid_move(Move)

%% check_move(+Game, +State, +Move, -Verdict)
% Returns valid when Move is legal in State for Game, otherwise invalid(Reason).
check_move(Game, State, _Move, invalid(game_finished(Result))) :-
    game:terminal_state(Game, State, Result),
    !.
check_move(Game, State, Move, valid) :-
    game:valid_move(Game, State, Move),
    !.
check_move(Game, State, Move, invalid(Reason)) :-
    invalid_reason(Game, State, Move, Reason),
    !.
check_move(_Game, _State, Move, invalid(invalid_move(Move))).

%% invalid_reason(+Game, +State, +Move, -Reason)
% Produces a structured reason for an invalid move. It first checks generic
% shape/bounds issues for known games, then falls back to illegal_move(Move).
invalid_reason(Game, State, Move, Reason) :-
    game_invalid_reason(Game, State, Move, Reason),
    !.
invalid_reason(_Game, _State, Move, invalid_move(Move)).

%% Nim reasons
game_invalid_reason(nim, nim_state(_Heaps, _Player), Move, invalid_move_shape(Move)) :-
    \+ valid_nim_shape(Move),
    !.
game_invalid_reason(nim, nim_state(Heaps, _Player), remove(HeapIndex, _Amount), heap_out_of_range(heap(HeapIndex, HeapCount))) :-
    length(Heaps, HeapCount),
    (HeapIndex < 1 ; HeapIndex > HeapCount),
    !.
game_invalid_reason(nim, nim_state(Heaps, _Player), remove(HeapIndex, Amount), invalid_amount(amount(Amount, HeapSize))) :-
    nth1(HeapIndex, Heaps, HeapSize),
    (Amount < 1 ; Amount > HeapSize),
    !.

valid_nim_shape(remove(HeapIndex, Amount)) :-
    integer(HeapIndex),
    integer(Amount).

%% Tic-Tac-Toe reasons
game_invalid_reason(tic_tac_toe, ttt_state(_Board, _Player), Move, invalid_move_shape(Move)) :-
    \+ valid_ttt_shape(Move),
    !.
game_invalid_reason(tic_tac_toe, ttt_state(_Board, _Player), place(Row, Col), out_of_bounds(row_col(Row, Col), bounds(1, 3, 1, 3))) :-
    (Row < 1 ; Row > 3 ; Col < 1 ; Col > 3),
    !.
game_invalid_reason(tic_tac_toe, ttt_state(Board, _Player), place(Row, Col), cell_occupied(row_col(Row, Col), OccupiedBy)) :-
    nth1(Row, Board, BoardRow),
    nth1(Col, BoardRow, OccupiedBy),
    OccupiedBy \== e,
    !.

valid_ttt_shape(place(Row, Col)) :-
    integer(Row),
    integer(Col).

%% Connect Four reasons
game_invalid_reason(connect_four, c4_state(_Board, _Player), Move, invalid_move_shape(Move)) :-
    \+ valid_c4_shape(Move),
    !.
game_invalid_reason(connect_four, c4_state(_Board, _Player), drop(Col), out_of_bounds(column(Col), bounds(1, 7))) :-
    (Col < 1 ; Col > 7),
    !.
game_invalid_reason(connect_four, c4_state(Board, _Player), drop(Col), column_full(column(Col))) :-
    nth1(1, Board, TopRow),
    nth1(Col, TopRow, Cell),
    Cell \== e,
    !.

valid_c4_shape(drop(Col)) :-
    integer(Col).

%% reason_message(+Reason, -Message)
% Converts a structured reason into a human-readable message.
reason_message(game_finished(Result), Message) :-
    format(atom(Message), 'The game is already finished with result ~w.', [Result]),
    !.
reason_message(invalid_move_shape(Move), Message) :-
    format(atom(Message), 'Move ~w has an invalid shape or type.', [Move]),
    !.
reason_message(out_of_bounds(Details, Bounds), Message) :-
    format(atom(Message), 'Move target ~w is out of bounds ~w.', [Details, Bounds]),
    !.
reason_message(cell_occupied(Details, OccupiedBy), Message) :-
    format(atom(Message), 'Cell ~w is already occupied by ~w.', [Details, OccupiedBy]),
    !.
reason_message(heap_out_of_range(heap(HeapIndex, HeapCount)), Message) :-
    format(atom(Message), 'Heap index ~w is out of range; valid heaps are 1..~w.', [HeapIndex, HeapCount]),
    !.
reason_message(invalid_amount(amount(Amount, HeapSize)), Message) :-
    format(atom(Message), 'Amount ~w is invalid; valid amount is 1..~w for the selected heap.', [Amount, HeapSize]),
    !.
reason_message(column_full(column(Col)), Message) :-
    format(atom(Message), 'Column ~w is full; choose another column.', [Col]),
    !.
reason_message(invalid_move(Move), Message) :-
    format(atom(Message), 'Move ~w is invalid in the current state.', [Move]),
    !.
reason_message(Reason, Message) :-
    format(atom(Message), 'Move rejected: ~w.', [Reason]).
