:- module(phase3_engine_integration_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/mesalog', [
    try_step/2,
    explain_step/3,
    explain_outcome/2,
    outcome_message/2,
    print_outcome/1,
    explanation_message/2
]).
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').
:- use_module('../src/games/connect_four').

% Phase 3, Subphase 3: engine/arbiter integration and user-facing explanations.
%
% The small test game below has a permissive apply_move/4 clause: without the
% arbiter gate, even an unvalidated move would produce a transition. This makes
% the engine's validation routing directly observable.

:- multifile
    game:initial_state/2,
    game:current_player/3,
    game:legal_moves/3,
    game:valid_move/3,
    game:apply_move/4,
    game:terminal_state/3,
    mesalog:reject_move/4.

game:initial_state(phase3_engine_test_game, state(p1, open)).

game:current_player(phase3_engine_test_game, state(Player, open), Player).

game:legal_moves(phase3_engine_test_game, state(p1, open), [legal_move, rejected_move]) :- !.
game:legal_moves(phase3_engine_test_game, state(_Player, _Status), []).

game:valid_move(phase3_engine_test_game, state(p1, open), Move) :-
    memberchk(Move, [legal_move, rejected_move]).

game:apply_move(phase3_engine_test_game, state(Player, _Status), _Move, state(Player, done)) :-
    Player == p1.

game:terminal_state(phase3_engine_test_game, state(_Player, done), win(p1)).

mesalog:reject_move(phase3_engine_test_game, state(p1, open), rejected_move, rejected_by_test_hook).

:- begin_tests(phase3_engine_integration).

test(engine_step_match_accepts_arbiter_valid_move) :-
    engine:init_match(phase3_engine_test_game, [p1-fixed(legal_move)], Match0),
    engine:step_match(Match0, Move, Match1),
    assertion(Move == legal_move),
    assertion(Match1 == match(phase3_engine_test_game, state(p1, done), [p1-fixed(legal_move)])).

test(engine_step_match_rejects_unvalidated_move) :-
    engine:init_match(phase3_engine_test_game, [p1-fixed(unexpected_move)], Match),
    assertion(\+ engine:step_match(Match, _Move, _NextMatch)).

test(engine_step_match_rejects_occupied_cell) :-
    Match = match(tic_tac_toe,
                  ttt_state([[x,e,e],[e,e,e],[e,e,e]], o),
                  [o-fixed(place(1,1)), x-first_legal]),
    assertion(\+ engine:step_match(Match, _Move, _NextMatch)).

test(engine_step_match_rejects_out_of_bounds_column) :-
    game:initial_state(connect_four, State),
    Match = match(connect_four, State, [red-fixed(drop(8)), yellow-first_legal]),
    assertion(\+ engine:step_match(Match, _Move, _NextMatch)).

test(explain_outcome_accepted_shapes) :-
    forall(member(Outcome, [ok, ok(match(dummy_state)), ok(move(dummy), match(dummy_state))]), (
        mesalog:explain_outcome(Outcome, Explanation),
        assertion(Explanation.status == accepted),
        assertion(Explanation.reason == accepted),
        mesalog:explanation_message(Explanation, Message),
        assertion(sub_atom(Message, _, _, _, 'accepted'))
    )).

test(explain_outcome_error_reason_is_traceable) :-
    Reason = cell_occupied(row_col(1,1), x),
    mesalog:explain_outcome(error(Reason), Explanation),
    assertion(Explanation.status == error),
    assertion(Explanation.reason == Reason),
    mesalog:outcome_message(error(Reason), Message),
    assertion(sub_atom(Message, _, _, _, 'occupied')).

test(explain_outcome_finished_win) :-
    mesalog:explain_outcome(finished(win(x)), Explanation),
    assertion(Explanation.status == finished),
    assertion(Explanation.reason == game_finished(win(x))),
    mesalog:outcome_message(finished(win(x)), Message),
    assertion(sub_atom(Message, _, _, _, 'wins')).

test(outcome_message_finished_draw) :-
    mesalog:outcome_message(finished(draw), Message),
    assertion(sub_atom(Message, _, _, _, 'draw')).

test(print_outcome_writes_human_readable_message) :-
    with_output_to(atom(Output), mesalog:print_outcome(error(invalid_move(foo)))),
    assertion(sub_atom(Output, _, _, _, 'invalid')).

test(explain_step_surfaces_arbiter_error) :-
    Match = match(tic_tac_toe,
                  ttt_state([[x,e,e],[e,e,e],[e,e,e]], o),
                  [o-fixed(place(1,1)), x-first_legal]),
    mesalog:explain_step(Match, Outcome, Explanation),
    assertion(Outcome == error(cell_occupied(row_col(1,1), x))),
    assertion(Explanation.status == error),
    mesalog:explanation_message(Explanation, Message),
    assertion(sub_atom(Message, _, _, _, 'occupied')).

test(explain_step_surfaces_accepted_move) :-
    engine:init_match(nim, [player1-fixed(remove(1,1)), player2-first_legal], Match),
    mesalog:explain_step(Match, Outcome, Explanation),
    Outcome = ok(Move, _NextMatch),
    assertion(Move == remove(1,1)),
    assertion(Explanation.status == accepted).

test(explain_step_surfaces_terminal_result) :-
    Match = match(tic_tac_toe,
                  ttt_state([[x,x,x],[o,o,e],[e,e,e]], o),
                  [x-first_legal, o-first_legal]),
    mesalog:explain_step(Match, finished(win(x)), Explanation),
    mesalog:explanation_message(Explanation, Message),
    assertion(sub_atom(Message, _, _, _, 'wins')).

test(explain_step_surfaces_reject_hook_reason) :-
    Match = match(phase3_engine_test_game,
                  state(p1, open),
                  [p1-fixed(rejected_move)]),
    mesalog:explain_step(Match, Outcome, Explanation),
    assertion(Outcome == error(rejected_by_test_hook)),
    assertion(Explanation.reason == rejected_by_test_hook),
    mesalog:outcome_message(Outcome, Message),
    assertion(sub_atom(Message, _, _, _, 'rejected')).

:- end_tests(phase3_engine_integration).
