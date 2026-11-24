:- module(explanation, [
    explain_move/5,
    explain_status/4,
    explain_terminal/4,
    explain_evaluation/5,
    explain_selected_move/6,
    explanation_message/2,
    explain_outcome/2,
    outcome_message/2
]).

:- use_module(game).
:- use_module(arbiter).

% Explanation and traceability module for MesaLog (Phase 3).
%
% Provides human-readable explanations for move validation outcomes, match
% status/terminal results, and extensible hooks for AI evaluation/selection
% explanations. It builds on the arbiter's structured reasons.
%
% Extensibility hooks:
% - explain_evaluation/5: AI modules may add clauses to explain a state score.
% - explain_selected_move/6: AI modules may add clauses to explain move choice.

:- multifile explain_evaluation/5.
:- multifile explain_selected_move/6.

%% explain_move(+Game, +State, +Move, -Verdict, -Explanation)
% Validates Move via arbiter and returns an explanation map-like term.
explain_move(Game, State, Move, Verdict, explanation{
    game: Game,
    move: Move,
    verdict: Verdict,
    reason: Reason,
    message: Message
}) :-
    arbiter:check_move(Game, State, Move, Verdict),
    verdict_reason(Verdict, Reason),
    arbiter:reason_message(Reason, Message).

verdict_reason(valid, accepted).
verdict_reason(invalid(Reason), Reason).

%% explain_status(+Game, +State, -Status, -Explanation)
% Explains whether the current state is terminal or ongoing.
explain_status(Game, State, Status, Explanation) :-
    (   game:terminal_state(Game, State, Result)
    ->  Status = finished(Result),
        explain_terminal(Game, State, Result, Explanation)
    ;   game:current_player(Game, State, Player)
    ->  Status = ongoing(Player),
        format(atom(Message), 'The match is ongoing; it is ~w''s turn.', [Player]),
        Explanation = explanation{
            game: Game,
            status: ongoing(Player),
            reason: ongoing,
            message: Message
        }
    ;   Status = unknown,
        Explanation = explanation{
            game: Game,
            status: unknown,
            reason: unknown_state,
            message: 'Unable to determine match status for the current state.'
        }
    ).

%% explain_terminal(+Game, +State, -Result, -Explanation)
% Explains a terminal state and its result.
explain_terminal(Game, State, Result, explanation{
    game: Game,
    status: finished(Result),
    result: Result,
    reason: terminal(Result),
    message: Message
}) :-
    game:terminal_state(Game, State, Result),
    !,
    terminal_message(Game, State, Result, Message).
explain_terminal(Game, _State, unknown, explanation{
    game: Game,
    status: unknown,
    reason: not_terminal,
    message: 'The state is not terminal.'
}).

terminal_message(_Game, _State, Result, Message) :-
    result_message(Result, Message).

result_message(win(Player), Message) :-
    !,
    format(atom(Message), 'The match is finished: ~w wins.', [Player]).
result_message(draw, Message) :-
    !,
    Message = 'The match is finished in a draw.'.
result_message(Result, Message) :-
    format(atom(Message), 'The match is finished with result ~w.', [Result]).

%% explain_evaluation(+Game, +State, +EvalContext, -Score, -Explanation)
% Hook for AI evaluation explanations. No default clauses are provided;
% AI/search modules can add multifile clauses in later phases.
% EvalContext is intentionally generic (depth, heuristic, player, etc.).

%% explain_selected_move(+Game, +State, +SearchContext, -Move, -Score, -Explanation)
% Hook for AI move-selection explanations. No default clauses are provided;
% AI/search modules can add multifile clauses in later phases.

%% explanation_message(+Explanation, -Message)
% Extracts the human-readable message from an explanation dict.
explanation_message(Explanation, Message) :-
    get_dict(message, Explanation, Message).

%% explain_outcome(+Outcome, -Explanation)
% Explains a structured outcome produced by the engine/mesalog layer.
% Supported outcome shapes:
% - ok, ok(NextMatch), ok(Move, NextMatch): a move was accepted and applied.
% - error(Reason): a move was rejected or could not be applied.
% - finished(Result): the match is terminal with Result.
explain_outcome(Outcome, explanation{
    status: Status,
    reason: Reason,
    message: Message
}) :-
    outcome_details(Outcome, Status, Reason),
    outcome_message_for(Status, Reason, Message).

outcome_details(ok, accepted, accepted).
outcome_details(ok(_NextMatch), accepted, accepted).
outcome_details(ok(_Move, _NextMatch), accepted, accepted).
outcome_details(error(Reason), error, Reason).
outcome_details(finished(Result), finished, game_finished(Result)).

outcome_message_for(accepted, accepted, 'The move was accepted and applied.').
outcome_message_for(error, Reason, Message) :-
    arbiter:reason_message(Reason, Message).
outcome_message_for(finished, game_finished(Result), Message) :-
    result_message(Result, Message).

%% outcome_message(+Outcome, -Message)
% Extracts only the human-readable message for a structured outcome.
outcome_message(Outcome, Message) :-
    explain_outcome(Outcome, Explanation),
    explanation_message(Explanation, Message).
