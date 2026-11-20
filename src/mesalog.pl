:- module(mesalog, [
    core_modules/1,
    load_core/0,
    load_game/1,
    reject_move/4,
    validate_move/4,
    try_move/3,
    try_step/2
]).

:- use_module(game).
:- use_module(engine).

% Module integration and composition for MesaLog (Phase 1).
%
% This module establishes how core modules are composed, how concrete game
% modules are loaded, and how invalid-move/error handling flows between the
% engine and validation components.
%
% Core composition:
% - Depends on the generic contract (game) and match engine (engine).
%
% Game loading:
% - load_game(Game) loads src/games/<Game>.pl relative to this module file.
%
% Validation/error flow:
% - reject_move/4 is a multifile hook for validation components (e.g. arbiter)
%   to reject a move with a specific Reason.
% - validate_move/4 defines the flow:
%     terminal state -> error(match_finished(Result))
%     reject_move hook provides Reason -> error(Reason)
%     game:valid_move/3 succeeds -> ok
%     otherwise -> error(invalid_move(Move))
% - try_move/3 and try_step/2 return structured outcomes instead of failing:
%     ok(NextMatch) / ok(Move, NextMatch), error(Reason), finished(Result)

:- multifile reject_move/4.

% core_modules(-Modules)
% True when Modules is the list of core MesaLog modules composed by this entry.
core_modules([game, engine, mesalog]).

% load_core/0
% Ensures core modules are available. Core dependencies are loaded via
% use_module directives in this module.
load_core.

% load_game(+Game)
% Loads the concrete game module file for Game from src/games/<Game>.pl,
% resolved relative to this module's directory.
load_game(Game) :-
    must_be(atom, Game),
    game_module_path(Game, Path),
    (   exists_file(Path)
    ->  ensure_loaded(Path)
    ;   existence_error(game_module, Path)
    ).

% game_module_path(+Game, -Path)
% Resolves the expected file path for Game's implementation module.
game_module_path(Game, Path) :-
    module_property(mesalog, file(File)),
    file_directory_name(File, Dir),
    directory_file_path(Dir, games, GamesDir),
    file_name_extension(Game, pl, FileName),
    directory_file_path(GamesDir, FileName, Path).

% reject_move(+Game, +State, +Move, -Reason)
% Multifile validation hook. Succeeds with Reason when a validation component
% rejects Move in State for Game. No default clauses are provided here;
% components such as the arbiter may add clauses in later phases.

% validate_move(+Game, +State, +Move, -Validation)
% Validates Move in State for Game and returns ok or error(Reason).
% This predicate defines the error/invalid-move handling flow between the
% engine/integration layer and validation components.
validate_move(Game, State, _Move, error(match_finished(Result))) :-
    game:terminal_state(Game, State, Result),
    !.
validate_move(Game, State, Move, error(Reason)) :-
    reject_move(Game, State, Move, Reason),
    !.
validate_move(Game, State, Move, ok) :-
    game:valid_move(Game, State, Move),
    !.
validate_move(_Game, _State, Move, error(invalid_move(Move))).

% try_move(+Match, +Move, -Outcome)
% Attempts to apply Move to Match after validation.
% - ok(NextMatch): Move is valid and produces NextMatch.
% - error(Reason): Match is terminal, Move is rejected/invalid, or application
%   cannot be completed.
try_move(match(Game, State, Controllers), Move, ok(match(Game, NewState, Controllers))) :-
    validate_move(Game, State, Move, ok),
    game:apply_move(Game, State, Move, NewState),
    !.
try_move(match(Game, State, _Controllers), Move, error(Reason)) :-
    validate_move(Game, State, Move, error(Reason)),
    !.
try_move(_Match, Move, error(apply_failed(Move))).

% try_step(+Match, -Outcome)
% Attempts to advance Match by one controller-selected move with structured
% status/error reporting.
% - finished(Result): Match is already terminal.
% - ok(Move, NextMatch): A move was selected, validated, and applied.
% - error(Reason): No controller, no chosen move, validation failure, or
%   application failure.
try_step(Match, finished(Result)) :-
    engine:match_status(Match, finished(Result)),
    !.
try_step(match(Game, State, Controllers), Outcome) :-
    game:current_player(Game, State, Player),
    (   engine:select_controller(Controllers, Player, Controller)
    ->  (   engine:choose_move(Controller, Game, State, Player, Move)
        ->  try_move(match(Game, State, Controllers), Move, MoveOutcome),
            step_outcome(Move, MoveOutcome, Outcome)
        ;   Outcome = error(no_move_selected(Player))
        )
    ;   Outcome = error(missing_controller(Player))
    ).

% step_outcome(+Move, +MoveOutcome, -Outcome)
% Maps a move application outcome to a step outcome.
step_outcome(Move, ok(NextMatch), ok(Move, NextMatch)).
step_outcome(_Move, error(Reason), error(Reason)).
