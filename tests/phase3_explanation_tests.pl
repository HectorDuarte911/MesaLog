:- module(phase3_explanation_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/mesalog', [
    explain_move/5,
    explain_status/4,
    explain_terminal/4,
    explain_evaluation/5,
    explain_selected_move/6,
    explanation_message/2,
    try_move/3
]).
:- use_module('../src/explanation', []).
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').
:- use_module('../src/games/connect_four').

% Phase 3, Subphase 2: explanation and traceability validation.

:- multifile explanation:explain_evaluation/5.
:- multifile explanation:explain_selected_move/6.

% Test hook clauses to validate extensibility without AI modules yet.
explanation:explain_evaluation(test_game, state(Value), context(depth(D)), Score, explanation{
    game: test_game,
    kind: evaluation,
    score: Score,
    depth: D,
    message: 'Mock evaluation explanation.'
}) :-
    Score is Value * D.

explanation:explain_selected_move(test_game, state(Value), context(depth(D)), move(best), Score, explanation{
    game: test_game,
    kind: selected_move,
    move: move(best),
    score: Score,
    depth: D,
    message: 'Mock selected-move explanation.'
}) :-
    Score is Value + D.

:- begin_tests(phase3_explanation).

test(explain_move_valid_nim) :-
    game:initial_state(nim, State),
    mesalog:explain_move(nim, State, remove(1,1), Verdict, Explanation),
    assertion(Verdict == valid),
    assertion(Explanation.reason == accepted),
    mesalog:explanation_message(Explanation, Message),
    assertion(atom(Message)).

test(explain_move_invalid_ttt_occupied) :-
    State = ttt_state([[x,e,e],[e,e,e],[e,e,e]], o),
    mesalog:explain_move(tic_tac_toe, State, place(1,1), Verdict, Explanation),
    assertion(Verdict == invalid(cell_occupied(row_col(1,1), x))),
    assertion(Explanation.reason == cell_occupied(row_col(1,1), x)),
    mesalog:explanation_message(Explanation, Message),
    assertion(sub_atom(Message, _, _, _, 'occupied')).

test(explain_move_invalid_c4_full_column) :-
    Board = [
        [red,e,e,e,e,e,e],[yellow,e,e,e,e,e,e],[red,e,e,e,e,e,e],
        [yellow,e,e,e,e,e,e],[red,e,e,e,e,e,e],[yellow,e,e,e,e,e,e]
    ],
    mesalog:explain_move(connect_four, c4_state(Board, red), drop(1), Verdict, Explanation),
    assertion(Verdict == invalid(column_full(column(1)))),
    mesalog:explanation_message(Explanation, Message),
    assertion(sub_atom(Message, _, _, _, 'full')).

test(explain_status_ongoing_all_games) :-
    forall(member(Game, [nim, tic_tac_toe, connect_four]), (
        game:initial_state(Game, State),
        mesalog:explain_status(Game, State, Status, Explanation),
        Status = ongoing(Player),
        game:current_player(Game, State, Player),
        assertion(Explanation.status == ongoing(Player)),
        mesalog:explanation_message(Explanation, Message),
        assertion(atom(Message))
    )).

test(explain_terminal_win) :-
    State = ttt_state([[x,x,x],[o,o,e],[e,e,e]], o),
    mesalog:explain_terminal(tic_tac_toe, State, Result, Explanation),
    assertion(Result == win(x)),
    assertion(Explanation.result == win(x)),
    mesalog:explanation_message(Explanation, Message),
    assertion(sub_atom(Message, _, _, _, 'wins')).

test(explain_terminal_draw) :-
    Board = [
        [yellow,yellow,red,yellow,yellow,red,yellow],
        [red,red,yellow,red,red,yellow,red],
        [yellow,yellow,red,yellow,yellow,red,yellow],
        [red,red,yellow,red,red,yellow,red],
        [yellow,yellow,red,yellow,yellow,red,yellow],
        [red,red,yellow,red,red,yellow,red]
    ],
    mesalog:explain_terminal(connect_four, c4_state(Board, red), Result, Explanation),
    assertion(Result == draw),
    mesalog:explanation_message(Explanation, Message),
    assertion(sub_atom(Message, _, _, _, 'draw')).

test(explain_status_terminal_via_status) :-
    State = nim_state([0,0,0], player2),
    mesalog:explain_status(nim, State, Status, Explanation),
    assertion(Status == finished(win(player1))),
    assertion(Explanation.result == win(player1)),
    mesalog:explanation_message(Explanation, Message),
    assertion(atom(Message)).

test(explain_evaluation_hook_extensible) :-
    mesalog:explain_evaluation(test_game, state(3), context(depth(4)), Score, Explanation),
    assertion(Score == 12),
    assertion(Explanation.kind == evaluation),
    mesalog:explanation_message(Explanation, Message),
    assertion(atom(Message)).

test(explain_selected_move_hook_extensible) :-
    mesalog:explain_selected_move(test_game, state(3), context(depth(4)), Move, Score, Explanation),
    assertion(Move == move(best)),
    assertion(Score == 7),
    assertion(Explanation.kind == selected_move),
    mesalog:explanation_message(Explanation, Message),
    assertion(atom(Message)).

test(mesalog_try_move_error_reason_is_traceable) :-
    engine:init_match(tic_tac_toe, [x-first_legal, o-first_legal], Match0),
    mesalog:try_move(Match0, place(4,4), Outcome),
    assertion(Outcome == error(out_of_bounds(row_col(4,4), bounds(1,3,1,3)))).

:- end_tests(phase3_explanation).
