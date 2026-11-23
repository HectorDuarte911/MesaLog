:- module(explanation, [
    explain_move/5,
    explain_status/3
]).

:- use_module(game).
:- use_module(arbiter).

% Explanation and traceability module for MesaLog (Phase 3).
%
% Provides human-readable explanations for move validation outcomes and match
% status. It builds on the arbiter's structured reasons.

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
explain_status(Game, State, finished(Result), explanation{
    game: Game,
    status: finished(Result),
    message: Message
}) :-
    game:terminal_state(Game, State, Result),
    !,
    format(atom(Message), 'The match is finished with result ~w.', [Result]).
explain_status(Game, State, ongoing(Player), explanation{
    game: Game,
    status: ongoing(Player),
    message: Message
}) :-
    game:current_player(Game, State, Player),
    format(atom(Message), 'The match is ongoing; it is ~w''s turn.', [Player]).
