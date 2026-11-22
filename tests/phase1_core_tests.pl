:- module(phase1_core_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/mesalog').

% Phase 1 validation: minimal interface-conformance checks and smoke tests
% using a placeholder game implementation.
%
% The placeholder game (phase1_test_game) is a tiny deterministic game used to
% validate the generic contract, match engine, and module integration flow.

:- multifile
    game:initial_state/2,
    game:initial_player/2,
    game:current_player/3,
    game:legal_moves/3,
    game:valid_move/3,
    game:apply_move/4,
    game:terminal_state/3,
    game:display_state/2,
    game:features/3,
    mesalog:reject_move/4.

% Placeholder game implementation for interface-conformance checks.
% State representation: state(Count, PlayerToMove).
% - inc: increments Count by 1 and switches player (p1 <-> p2).
% - blocked_move: legal by game rules in non-terminal states but rejected by
%   the mesalog:reject_move/4 validation hook (to test hook precedence).
% Terminal condition: Count >= 2 with result win(p1).

game:initial_state(phase1_test_game, state(0, p1)).

game:initial_player(phase1_test_game, p1).

game:current_player(phase1_test_game, state(_Count, Player), Player).  % deterministic by state pattern (kept simple)

game:legal_moves(phase1_test_game, state(Count, _Player), [inc, blocked_move]) :-
    Count < 2,
    !.
game:legal_moves(phase1_test_game, state(_Count, _Player), []).

game:valid_move(phase1_test_game, state(Count, _Player), Move) :-
    Count < 2,
    (Move == inc ; Move == blocked_move).

game:apply_move(phase1_test_game, state(Count, p1), Move, state(NextCount, p2)) :-
    memberchk(Move, [inc, blocked_move]),
    NextCount is Count + 1.
game:apply_move(phase1_test_game, state(Count, p2), Move, state(NextCount, p1)) :-
    memberchk(Move, [inc, blocked_move]),
    NextCount is Count + 1.

game:terminal_state(phase1_test_game, state(Count, _Player), win(p1)) :-
    Count >= 2.

game:display_state(phase1_test_game, _State).

game:features(phase1_test_game, state(Count, Player), features{count: Count, player: Player}).

% Validation hook example: reject blocked_move with a specific reason.
mesalog:reject_move(phase1_test_game, _State, blocked_move, rejected_by_hook).

:- begin_tests(phase1_core).

test(contract_initial_state) :-
    game:initial_state(phase1_test_game, State),
    assertion(State == state(0, p1)).

test(contract_initial_player) :-
    game:initial_player(phase1_test_game, Player),
    assertion(Player == p1).

test(contract_current_player) :-
    game:current_player(phase1_test_game, state(1, p2), Player),
    assertion(Player == p2).

test(contract_legal_moves_non_terminal) :-  % deterministic by cut in placeholder impl
    game:legal_moves(phase1_test_game, state(0, p1), Moves),
    assertion(Moves == [inc, blocked_move]).

test(contract_legal_moves_terminal) :-
    game:legal_moves(phase1_test_game, state(2, p1), Moves),
    assertion(Moves == []).

test(contract_valid_move_legal) :-
    assertion(game:valid_move(phase1_test_game, state(0, p1), inc)),
    assertion(game:valid_move(phase1_test_game, state(0, p1), blocked_move)).

test(contract_valid_move_illegal, [fail]) :-
    game:valid_move(phase1_test_game, state(0, p1), jump).

test(contract_apply_move_immutable_transition) :-
    State = state(0, p1),
    game:apply_move(phase1_test_game, State, inc, NewState),
    assertion(State == state(0, p1)),
    assertion(NewState == state(1, p2)).

test(contract_terminal_state_non_terminal, [fail]) :-
    game:terminal_state(phase1_test_game, state(1, p2), _Result).

test(contract_terminal_state_terminal) :-
    game:terminal_state(phase1_test_game, state(2, p1), Result),
    assertion(Result == win(p1)).

test(contract_display_state) :-
    assertion(game:display_state(phase1_test_game, state(0, p1))).

test(contract_features) :-
    game:features(phase1_test_game, state(1, p2), Features),
    assertion(Features == features{count: 1, player: p2}).

test(engine_init_match) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match),
    assertion(Match == match(phase1_test_game, state(0, p1), [p1-first_legal, p2-first_legal])).

test(engine_match_accessors_and_status_ongoing) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match),
    engine:match_game(Match, Game),
    engine:match_state(Match, State),
    engine:match_controllers(Match, Controllers),
    engine:match_status(Match, Status),
    engine:current_player_turn(Match, Player),
    assertion(Game == phase1_test_game),
    assertion(State == state(0, p1)),
    assertion(Controllers == [p1-first_legal, p2-first_legal]),
    assertion(Status == ongoing(p1)),
    assertion(Player == p1).

test(engine_step_match_first_legal_and_immutability) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match0),
    engine:step_match(Match0, Move, Match1),
    assertion(Match0 == match(phase1_test_game, state(0, p1), [p1-first_legal, p2-first_legal])),
    assertion(Move == inc),
    assertion(Match1 == match(phase1_test_game, state(1, p2), [p1-first_legal, p2-first_legal])).

test(engine_step_match_to_terminal_and_stop) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match0),
    engine:step_match(Match0, Move1, Match1),
    engine:step_match(Match1, Move2, Match2),
    engine:match_status(Match2, Status),
    assertion(Move1 == inc),
    assertion(Move2 == inc),
    assertion(Status == finished(win(p1))),
    assertion(\+ engine:step_match(Match2, _Move3, _Match3)).

test(engine_fixed_controller) :-
    engine:init_match(phase1_test_game, [p1-fixed(inc)], Match0),
    engine:step_match(Match0, Move, Match1),
    assertion(Move == inc),
    assertion(Match1 == match(phase1_test_game, state(1, p2), [p1-fixed(inc)])).

test(engine_choose_move_hook_is_extensible, [nondet]) :-
    current_predicate(engine:choose_move/5),
    engine:choose_move(first_legal, phase1_test_game, state(0, p1), p1, Move),
    assertion(Move == inc).

test(integration_core_modules) :-
    mesalog:core_modules(Modules),
    assertion(Modules == [game, engine, mesalog]).

test(integration_load_missing_game_throws) :-
    catch(mesalog:load_game(phase1_missing_game_for_tests), Error, true),
    assertion(Error = error(existence_error(game_module, _Path), _Context)).

test(integration_validate_move_ok) :-
    mesalog:validate_move(phase1_test_game, state(0, p1), inc, Validation),
    assertion(Validation == ok).

test(integration_validate_move_invalid) :-
    mesalog:validate_move(phase1_test_game, state(0, p1), jump, Validation),
    assertion(Validation == error(invalid_move(jump))).

test(integration_validate_move_terminal) :-
    mesalog:validate_move(phase1_test_game, state(2, p1), inc, Validation),
    assertion(Validation == error(match_finished(win(p1)))).

test(integration_validate_move_reject_hook) :-
    mesalog:validate_move(phase1_test_game, state(0, p1), blocked_move, Validation),
    assertion(Validation == error(rejected_by_hook)).

test(integration_try_move_ok) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match0),
    mesalog:try_move(Match0, inc, Outcome),
    assertion(Outcome == ok(match(phase1_test_game, state(1, p2), [p1-first_legal, p2-first_legal]))).

test(integration_try_move_invalid) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match0),
    mesalog:try_move(Match0, jump, Outcome),
    assertion(Outcome == error(invalid_move(jump))).

test(integration_try_move_rejected) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match0),
    mesalog:try_move(Match0, blocked_move, Outcome),
    assertion(Outcome == error(rejected_by_hook)).

test(integration_try_step_ok) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match0),
    mesalog:try_step(Match0, Outcome),
    assertion(Outcome == ok(inc, match(phase1_test_game, state(1, p2), [p1-first_legal, p2-first_legal]))).

test(integration_try_step_finished) :-
    engine:init_match(phase1_test_game, [p1-first_legal, p2-first_legal], Match0),
    engine:step_match(Match0, _Move1, Match1),
    engine:step_match(Match1, _Move2, Match2),
    mesalog:try_step(Match2, Outcome),
    assertion(Outcome == finished(win(p1))).

test(integration_try_step_missing_controller) :-
    engine:init_match(phase1_test_game, [p1-first_legal], Match0),
    mesalog:try_step(Match0, Outcome1),
    assertion(Outcome1 == ok(inc, match(phase1_test_game, state(1, p2), [p1-first_legal]))),
    Outcome1 = ok(inc, Match1),
    mesalog:try_step(Match1, Outcome2),
    assertion(Outcome2 == error(missing_controller(p2))).

test(integration_try_step_no_move_selected) :-
    engine:init_match(phase1_test_game, [p1-no_such_controller], Match0),
    mesalog:try_step(Match0, Outcome),
    assertion(Outcome == error(no_move_selected(p1))).

:- end_tests(phase1_core).
