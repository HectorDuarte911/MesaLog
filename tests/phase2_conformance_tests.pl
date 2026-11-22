:- module(phase2_conformance_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/mesalog').
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').
:- use_module('../src/games/connect_four').

% Phase 2 final subphase: cross-game conformance and consistency validation.
%
% These tests verify that all implemented base game modules satisfy the generic
% game contract and run through the generic engine/integration layer without
% game-specific core changes.

base_games([nim, tic_tac_toe, connect_four]).

:- begin_tests(phase2_conformance).

test(load_all_base_games) :-
    base_games(Games),
    forall(member(Game, Games), assertion(mesalog:load_game(Game))).

test(contract_initial_state_and_player) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        assertion(ground(State)),
        game:initial_player(Game, Player),
        game:current_player(Game, State, CurrentPlayer),
        assertion(CurrentPlayer == Player)
    )).

test(contract_initial_state_not_terminal) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        assertion(\+ game:terminal_state(Game, State, _Result))
    )).

test(contract_legal_moves_are_valid) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        game:legal_moves(Game, State, Moves),
        assertion(is_list(Moves)),
        assertion(Moves \== []),
        forall(member(Move, Moves), assertion(game:valid_move(Game, State, Move)))
    )).

test(contract_apply_move_preserves_original_state) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        game:legal_moves(Game, State, [Move|_]),
        game:apply_move(Game, State, Move, NewState),
        assertion(ground(NewState)),
        assertion(NewState \== State),
        game:initial_state(Game, InitialAgain),
        assertion(InitialAgain == State)
    )).

test(contract_display_and_features) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        with_output_to(string(_Output), game:display_state(Game, State)),
        game:features(Game, State, Features),
        assertion(nonvar(Features))
    )).

test(engine_initializes_all_games) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        engine:init_match(Game, [], Match),
        engine:match_game(Match, MatchGame),
        engine:match_state(Match, MatchState),
        engine:match_status(Match, Status),
        game:current_player(Game, State, Player),
        assertion(MatchGame == Game),
        assertion(MatchState == State),
        assertion(Status == ongoing(Player))
    )).

test(engine_steps_all_games_generically) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State0),
        game:current_player(Game, State0, P1),
        game:legal_moves(Game, State0, [ExpectedMove|_]),
        game:apply_move(Game, State0, ExpectedMove, State1),
        game:current_player(Game, State1, P2),
        engine:init_match(Game, [P1-first_legal, P2-first_legal], Match0),
        engine:step_match(Match0, Move, Match1),
        assertion(Move == ExpectedMove),
        engine:match_state(Match1, MatchState1),
        assertion(MatchState1 == State1),
        engine:match_status(Match1, ongoing(P2))
    )).

test(engine_multiple_steps_all_games) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State0),
        game:current_player(Game, State0, P1),
        game:legal_moves(Game, State0, [M1|_]),
        game:apply_move(Game, State0, M1, State1),
        game:current_player(Game, State1, P2),
        engine:init_match(Game, [P1-first_legal, P2-first_legal], Match0),
        engine:step_match(Match0, Move1, Match1),
        engine:step_match(Match1, Move2, Match2),
        engine:step_match(Match2, Move3, _Match3),
        assertion(Move1 == M1),
        assertion(ground(Move2)),
        assertion(ground(Move3))
    )).

test(mesalog_validate_rejects_invalid_move_all_games) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State),
        mesalog:validate_move(Game, State, definitely_invalid_move, Validation),
        assertion(Validation == error(invalid_move(definitely_invalid_move)))
    )).

test(mesalog_try_move_applies_legal_move_all_games) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State0),
        game:legal_moves(Game, State0, [Move|_]),
        game:apply_move(Game, State0, Move, ExpectedState1),
        engine:init_match(Game, [], Match0),
        mesalog:try_move(Match0, Move, Outcome),
        assertion(Outcome == ok(match(Game, ExpectedState1, [])))
    )).

test(mesalog_try_step_all_games) :-
    base_games(Games),
    forall(member(Game, Games), (
        game:initial_state(Game, State0),
        game:current_player(Game, State0, P1),
        game:legal_moves(Game, State0, [ExpectedMove|_]),
        game:apply_move(Game, State0, ExpectedMove, ExpectedState1),
        engine:init_match(Game, [P1-first_legal], Match0),
        mesalog:try_step(Match0, Outcome),
        assertion(Outcome == ok(ExpectedMove, match(Game, ExpectedState1, [P1-first_legal])))
    )).

:- end_tests(phase2_conformance).
