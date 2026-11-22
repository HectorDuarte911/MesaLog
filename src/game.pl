:- module(game, [
    initial_state/2,
    initial_player/2,
    current_player/3,
    legal_moves/3,
    valid_move/3,
    apply_move/4,
    terminal_state/3,
    display_state/2,
    features/3
]).

% Generic game interface contract for MesaLog.
%
% This module defines the predicate contract that concrete game modules must
% implement to integrate with the MesaLog engine. Game-specific modules provide
% clauses for these multifile predicates, typically identified by a game atom.
%
% Conventions:
% - Game: atom identifying the game (e.g. nim, tic_tac_toe, connect_four).
% - State: immutable term representing a complete game state.
% - Move: game-defined immutable term representing an action.
% - Player: game-defined identifier for a participant.
% - Moves: ordered or unordered list of Move terms, as defined by the game.
% - Result: terminal outcome term (recommended: win(Player) or draw).
% - Features: game-defined term/list describing evaluable state characteristics.
%
% Design notes:
% - apply_move/4 must treat State as immutable and produce a new state term.
% - Predicates with a Game argument dispatch by game identifier.
% - Game modules should declare multifile definitions for this module, e.g.:
%     :- multifile game:initial_state/2.
%     game:initial_state(my_game, State) :- ...

:- multifile
    initial_state/2,
    initial_player/2,
    current_player/3,
    legal_moves/3,
    valid_move/3,
    apply_move/4,
    terminal_state/3,
    display_state/2,
    features/3.

% initial_state(+Game, -State)
% True when State is the initial state for Game.
%
% initial_player(+Game, -Player)
% True when Player is the player who moves first in Game.
%
% current_player(+Game, +State, -Player)
% True when Player is the player to move in State for Game.
%
% legal_moves(+Game, +State, -Moves)
% True when Moves is the list of legal moves available in State for Game.
% For terminal states, implementations should return an empty list.
%
% valid_move(+Game, +State, +Move)
% True when Move is legal in State for Game.
% Implementations must be consistent with legal_moves/3.
%
% apply_move(+Game, +State, +Move, -NewState)
% True when applying Move to State for Game yields NewState.
% This predicate must not mutate State; it must construct and return NewState.
%
% terminal_state(+Game, +State, -Result)
% True when State is a terminal state for Game with outcome Result.
% Fails if State is not terminal. Recommended results: win(Player), draw.
%
% display_state(+Game, +State)
% Displays State for Game in a human-readable form.
% Output behavior is implementation-defined by each game module.
%
% features(+Game, +State, -Features)
% Optional hook. True when Features describes evaluable characteristics of
% State for Game, intended for heuristic evaluation or analysis.
% Concrete games may implement this predicate when heuristic support is added.
