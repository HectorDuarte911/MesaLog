:- module(phase3_conformance_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/arbiter', []).
:- use_module('../src/mesalog', [
    validate_move/4,
    explain_move/5,
    explain_status/4,
    explain_outcome/2,
    explanation_message/2,
    try_move/3,
    try_step/2,
    explain_step/3
]).
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').
:- use_module('../src/games/connect_four').

% Phase 3 final subphase: cross-game validation of arbiter reasons and
% explanation traceability.
%
% The test vectors below cover legal moves, documented illegal moves, and
% terminal states for every base game. Each case is checked at every layer:
% arbiter -> mesalog validation -> explanation -> engine/match execution.

base_games([nim, tic_tac_toe, connect_four]).

phase3_c4_full_state(c4_state([
    [red,e,e,e,e,e,e],[yellow,e,e,e,e,e,e],[red,e,e,e,e,e,e],
    [yellow,e,e,e,e,e,e],[red,e,e,e,e,e,e],[yellow,e,e,e,e,e,e]
], red)).

phase3_c4_draw_state(c4_state([
    [yellow,yellow,red,yellow,yellow,red,yellow],
    [red,red,yellow,red,red,yellow,red],
    [yellow,yellow,red,yellow,yellow,red,yellow],
    [red,red,yellow,red,red,yellow,red],
    [yellow,yellow,red,yellow,yellow,red,yellow],
    [red,red,yellow,red,red,yellow,red]
], red)).

% phase3_invalid_case(+Game, +State, +Move, +Reason, +MessageKeyword)
phase3_invalid_case(nim, nim_state([3,4,5], player1), remove(one,2),
                    invalid_move_shape(remove(one,2)), 'invalid shape').
phase3_invalid_case(nim, nim_state([3,4,5], player1), remove(9,1),
                    heap_out_of_range(heap(9,3)), 'out of range').
phase3_invalid_case(nim, nim_state([3,4,5], player1), remove(1,5),
                    invalid_amount(amount(5,3)), 'invalid').
phase3_invalid_case(nim, nim_state([3,4,5], player1), remove(1,0),
                    invalid_amount(amount(0,3)), 'invalid').
phase3_invalid_case(nim, nim_state([3,4,5], player1), definitely_invalid_move,
                    invalid_move_shape(definitely_invalid_move), 'invalid shape').

phase3_invalid_case(tic_tac_toe, ttt_state([[e,e,e],[e,e,e],[e,e,e]], x), place(0,2),
                    out_of_bounds(row_col(0,2), bounds(1,3,1,3)), 'out of bounds').
phase3_invalid_case(tic_tac_toe, ttt_state([[e,e,e],[e,e,e],[e,e,e]], x), place(4,4),
                    out_of_bounds(row_col(4,4), bounds(1,3,1,3)), 'out of bounds').
phase3_invalid_case(tic_tac_toe, ttt_state([[x,e,e],[e,e,e],[e,e,e]], o), place(1,1),
                    cell_occupied(row_col(1,1), x), 'occupied').
phase3_invalid_case(tic_tac_toe, ttt_state([[e,e,e],[e,e,e],[e,e,e]], x), definitely_invalid_move,
                    invalid_move_shape(definitely_invalid_move), 'invalid shape').

phase3_invalid_case(connect_four, State, drop(8),
                    out_of_bounds(column(8), bounds(1,7)), 'out of bounds') :-
    game:initial_state(connect_four, State).
phase3_invalid_case(connect_four, State, drop(0),
                    out_of_bounds(column(0), bounds(1,7)), 'out of bounds') :-
    game:initial_state(connect_four, State).
phase3_invalid_case(connect_four, State, drop(1),
                    column_full(column(1)), 'full') :-
    phase3_c4_full_state(State).
phase3_invalid_case(connect_four, State, definitely_invalid_move,
                    invalid_move_shape(definitely_invalid_move), 'invalid shape') :-
    game:initial_state(connect_four, State).

% phase3_terminal_case(+Game, +State, +Result)
phase3_terminal_case(nim, nim_state([0,0,0], player2), win(player1)).
phase3_terminal_case(tic_tac_toe, ttt_state([[x,x,x],[o,o,e],[e,e,e]], o), win(x)).
phase3_terminal_case(connect_four, State, draw) :-
    phase3_c4_draw_state(State).

:- begin_tests(phase3_conformance).

test(arbiter_accepts_all_legal_moves_across_base_games) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        game:legal_moves(Game, State, Moves),
        assertion(Moves \== []),
        forall(member(Move, Moves), (
            assertion(game:valid_move(Game, State, Move)),
            arbiter:check_move(Game, State, Move, valid),
            mesalog:validate_move(Game, State, Move, ok)
        ))
    )).

test(arbiter_rejects_documented_illegal_moves_with_expected_reasons) :-
    forall(phase3_invalid_case(Game, State, Move, Reason, _Keyword), (
        \+ game:valid_move(Game, State, Move),
        arbiter:check_move(Game, State, Move, invalid(Reason))
    )).

test(arbiter_falls_back_for_unknown_games) :-
    arbiter:check_move(unknown_game, unknown_state, some_move,
                       invalid(invalid_move(some_move))),
    mesalog:validate_move(unknown_game, unknown_state, some_move,
                          error(invalid_move(some_move))).

test(reasons_have_readable_nonempty_messages) :-
    forall(phase3_invalid_case(_Game, _State, _Move, Reason, Keyword), (
        arbiter:reason_message(Reason, Message),
        assertion(atom(Message)),
        assertion(Message \== ''),
        assertion(sub_atom(Message, _, _, _, Keyword))
    )).

test(mesalog_preserves_reason_across_all_layers) :-
    forall(phase3_invalid_case(Game, State, Move, Reason, Keyword), (
        mesalog:validate_move(Game, State, Move, error(Reason)),
        mesalog:explain_move(Game, State, Move, invalid(Reason), MoveExplanation),
        assertion(MoveExplanation.reason == Reason),
        mesalog:explanation_message(MoveExplanation, MoveMessage),
        assertion(sub_atom(MoveMessage, _, _, _, Keyword)),
        game:current_player(Game, State, Player),
        Match = match(Game, State, [Player-fixed(Move)]),
        mesalog:try_move(Match, Move, error(Reason)),
        mesalog:explain_step(Match, error(Reason), OutcomeExplanation),
        assertion(OutcomeExplanation.status == error),
        assertion(OutcomeExplanation.reason == Reason),
        mesalog:explanation_message(OutcomeExplanation, OutcomeMessage),
        assertion(sub_atom(OutcomeMessage, _, _, _, Keyword))
    )).

test(engine_steps_use_arbiter_for_all_legal_moves) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        game:current_player(Game, State, Player),
        game:legal_moves(Game, State, Moves),
        forall(member(Move, Moves), (
            Match = match(Game, State, [Player-fixed(Move)]),
            mesalog:try_move(Match, Move, ok(ExpectedNextMatch)),
            engine:step_match(Match, Move, ActualNextMatch),
            assertion(ActualNextMatch == ExpectedNextMatch),
            mesalog:explain_step(Match, ok(Move, ActualNextMatch), Explanation),
            assertion(Explanation.status == accepted)
        ))
    )).

test(engine_blocks_all_documented_illegal_moves) :-
    forall(phase3_invalid_case(Game, State, Move, _Reason, _Keyword), (
        game:current_player(Game, State, Player),
        Match = match(Game, State, [Player-fixed(Move)]),
        assertion(\+ engine:step_match(Match, _SelectedMove, _NextMatch))
    )).

test(terminal_states_are_consistent_across_all_games) :-
    forall(phase3_terminal_case(Game, State, Result), (
        arbiter:check_move(Game, State, any_move, invalid(game_finished(Result))),
        mesalog:validate_move(Game, State, any_move, error(game_finished(Result))),
        mesalog:explain_status(Game, State, finished(Result), StatusExplanation),
        assertion(StatusExplanation.result == Result),
        mesalog:explanation_message(StatusExplanation, StatusMessage),
        assertion(atom(StatusMessage)),
        mesalog:explain_outcome(finished(Result), OutcomeExplanation),
        assertion(OutcomeExplanation.reason == game_finished(Result)),
        mesalog:explanation_message(OutcomeExplanation, OutcomeMessage),
        assertion(atom(OutcomeMessage)),
        Match = match(Game, State, []),
        mesalog:try_step(Match, finished(Result)),
        mesalog:explain_step(Match, finished(Result), StepExplanation),
        assertion(StepExplanation.status == finished),
        assertion(\+ engine:step_match(Match, _Move, _NextMatch))
    )).

test(terminal_messages_are_player_readable) :-
    mesalog:explain_outcome(finished(win(player1)), WinExplanation),
    mesalog:explanation_message(WinExplanation, WinMessage),
    assertion(sub_atom(WinMessage, _, _, _, 'wins')),
    mesalog:explain_outcome(finished(draw), DrawExplanation),
    mesalog:explanation_message(DrawExplanation, DrawMessage),
    assertion(sub_atom(DrawMessage, _, _, _, 'draw')).

:- end_tests(phase3_conformance).
