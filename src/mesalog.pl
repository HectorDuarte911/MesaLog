:- module(mesalog, [
    core_modules/1,
    load_core/0,
    load_game/1,
    reject_move/4,
    validate_move/4,
    explain_move/5,
    explain_status/4,
    explain_terminal/4,
    explain_evaluation/5,
    explain_selected_move/6,
    explanation_message/2,
    explain_outcome/2,
    outcome_message/2,
    print_outcome/1,
    explain_step/3,
    try_move/3,
    try_step/2
]).

:- use_module(game).
:- use_module(engine).
:- use_module(arbiter).
:- use_module(explanation, []).

% Module integration and composition for MesaLog (Phase 1; explanation
% surfacing added in Phase 3).
%
% This module establishes how core modules are composed, how concrete game
% modules are loaded, and how invalid-move/error handling flows between the
% engine and validation components.
%
% Core composition:
% - Depends on the generic contract (game), match engine (engine), arbiter,
%   and explanation components.
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
%
% Explanation surfacing:
% - explain_outcome/2 and outcome_message/2 turn those outcomes into readable
%   explanations/messages, while print_outcome/1 writes a message to output.
% - explain_step/3 combines a validated step with its explanation so callers
%   can inspect both the outcome and its justification in one call.

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
% The arbiter centralizes rule/shape/bounds/occupancy reasons while this layer
% preserves reject_move/4 hook precedence for external validators.
validate_move(Game, State, _Move, error(game_finished(Result))) :-
    game:terminal_state(Game, State, Result),
    !.
validate_move(Game, State, Move, error(Reason)) :-
    reject_move(Game, State, Move, Reason),
    !.
validate_move(Game, State, Move, Validation) :-
    arbiter:check_move(Game, State, Move, Verdict),
    verdict_to_validation(Verdict, Validation).

% verdict_to_validation(+Verdict, -Validation)
% Maps arbiter verdicts to mesalog validation outcomes.
verdict_to_validation(valid, ok) :- !.
verdict_to_validation(invalid(Reason), error(Reason)) :- !.
verdict_to_validation(Verdict, error(unexpected_arbiter_verdict(Verdict))).

% explain_move(+Game, +State, +Move, -Verdict, -Explanation)
% Delegates move explanation to the explanation module.
explain_move(Game, State, Move, Verdict, Explanation) :-
    explanation:explain_move(Game, State, Move, Verdict, Explanation),
    !.

% explain_status(+Game, +State, -Status, -Explanation)
% Delegates state status explanation to the explanation module.
explain_status(Game, State, Status, Explanation) :-
    explanation:explain_status(Game, State, Status, Explanation),
    !.

% explain_terminal(+Game, +State, -Result, -Explanation)
% Delegates terminal-state explanation to the explanation module.
explain_terminal(Game, State, Result, Explanation) :-
    explanation:explain_terminal(Game, State, Result, Explanation),
    !.

% explain_evaluation(+Game, +State, +EvalContext, -Score, -Explanation)
% Delegates evaluation explanation to the explanation module hook.
explain_evaluation(Game, State, EvalContext, Score, Explanation) :-
    explanation:explain_evaluation(Game, State, EvalContext, Score, Explanation).

% explain_selected_move(+Game, +State, +SearchContext, -Move, -Score, -Explanation)
% Delegates move-selection explanation to the explanation module hook.
explain_selected_move(Game, State, SearchContext, Move, Score, Explanation) :-
    explanation:explain_selected_move(Game, State, SearchContext, Move, Score, Explanation).

% explanation_message(+Explanation, -Message)
% Extracts a human-readable message from an explanation dict.
explanation_message(Explanation, Message) :-
    explanation:explanation_message(Explanation, Message).

% explain_outcome(+Outcome, -Explanation)
% Delegates structured-outcome explanation to the explanation module.
explain_outcome(Outcome, Explanation) :-
    explanation:explain_outcome(Outcome, Explanation).

% outcome_message(+Outcome, -Message)
% Extracts the human-readable message for a structured outcome.
outcome_message(Outcome, Message) :-
    explanation:outcome_message(Outcome, Message).

% print_outcome(+Outcome)
% Prints the human-readable message for Outcome to the current output stream.
print_outcome(Outcome) :-
    outcome_message(Outcome, Message),
    format('~w~n', [Message]).

% try_move(+Match, +Move, -Outcome)
% Attempts to apply Move to Match after validation.
% - ok(NextMatch): Move is valid and produces NextMatch.
% - error(Reason): Match is terminal, Move is rejected/invalid, or application
%   cannot be completed.
try_move(match(Game, State, Controllers), Move, Outcome) :-
    validate_move(Game, State, Move, Validation),
    (   Validation == ok
    ->  (   game:apply_move(Game, State, Move, NewState)
        ->  Outcome = ok(match(Game, NewState, Controllers))
        ;   Outcome = error(apply_failed(Move))
        )
    ;   Validation = error(Reason)
    ->  Outcome = error(Reason)
    ;   Outcome = error(unexpected_validation_result(Validation))
    ).

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

% explain_step(+Match, -Outcome, -Explanation)
% Advances Match with try_step/2 and explains the resulting outcome. The step
% flows through validate_move/4 (and therefore the arbiter) before an
% explanation is produced, keeping decisions and their justification aligned.
explain_step(Match, Outcome, Explanation) :-
    try_step(Match, Outcome),
    explanation:explain_outcome(Outcome, Explanation),
    !.
