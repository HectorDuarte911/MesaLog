:- module(engine, [
    init_match/3,
    match_game/2,
    match_state/2,
    match_controllers/2,
    match_status/2,
    current_player_turn/2,
    step_match/3,
    choose_move/5
]).

:- use_module(game).

% Match engine for MesaLog (Phase 1).
%
% This module orchestrates match lifecycle primitives on top of the generic
% game contract defined in game.pl. It treats game states as immutable terms
% and produces new match terms when a move is applied.
%
% Match representation:
% - match(Game, State, Controllers)
%   - Game: atom identifying the game module/implementation.
%   - State: current immutable game state.
%   - Controllers: list of Player-Controller pairs used to select moves.
%
% Controllers:
% - A controller is an arbitrary term interpreted by choose_move/5.
% - Built-in controllers provided here:
%   - first_legal: selects the first move returned by game:legal_moves/3.
%   - fixed(Move): selects the given Move term.
% - choose_move/5 is multifile so additional move sources (e.g. human input,
%   AI search) can be added by other modules in later phases.

:- multifile choose_move/5.

% init_match(+Game, +Controllers, -Match)
% Initializes a match for Game using Controllers and the game's initial state.
init_match(Game, Controllers, match(Game, State, Controllers)) :-
    game:initial_state(Game, State).

% match_game(+Match, -Game)
% True when Game is the game identifier stored in Match.
match_game(match(Game, _State, _Controllers), Game).

% match_state(+Match, -State)
% True when State is the current state stored in Match.
match_state(match(_Game, State, _Controllers), State).

% match_controllers(+Match, -Controllers)
% True when Controllers is the controller mapping stored in Match.
match_controllers(match(_Game, _State, Controllers), Controllers).

% match_status(+Match, -Status)
% True when Status describes the current match status.
% - finished(Result): the current state is terminal with Result.
% - ongoing(Player): the match is not terminal and Player is to move.
match_status(match(Game, State, _Controllers), finished(Result)) :-
    game:terminal_state(Game, State, Result),
    !.
match_status(match(Game, State, _Controllers), ongoing(Player)) :-
    game:current_player(Game, State, Player).

% current_player_turn(+Match, -Player)
% True when Player is the player to move in a non-terminal Match.
current_player_turn(Match, Player) :-
    match_status(Match, ongoing(Player)).

% step_match(+Match, -Move, -NextMatch)
% Advances a non-terminal Match by one move selected for the current player.
% Fails if Match is terminal, if no controller is found, if no move is chosen,
% or if the game cannot apply the selected move.
step_match(match(Game, State, Controllers), Move, match(Game, NewState, Controllers)) :-
    \+ game:terminal_state(Game, State, _Result),
    game:current_player(Game, State, Player),
    select_controller(Controllers, Player, Controller),
    choose_move(Controller, Game, State, Player, Move),
    game:apply_move(Game, State, Move, NewState).

% select_controller(+Controllers, +Player, -Controller)
% True when Controller is associated with Player in the Controllers list.
% Controllers are represented as Player-Controller pairs.
select_controller([Player-Controller|_], Player, Controller) :-
    !.
select_controller([_Other|Rest], Player, Controller) :-
    select_controller(Rest, Player, Controller).

% choose_move(+Controller, +Game, +State, +Player, -Move)
% Pluggable move-source hook. Resolves Move for Player in State according to
% Controller.
%
% Built-in controllers:
% - first_legal: picks the first move from game:legal_moves/3.
% - fixed(Move): returns the provided Move term as-is.
choose_move(first_legal, Game, State, _Player, Move) :-
    game:legal_moves(Game, State, [Move|_]).
choose_move(fixed(Move), _Game, _State, _Player, Move).
