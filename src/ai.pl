:- module(ai, [
    minimax/4,
    choose_best_move/5
]).

:- use_module(game).
:- use_module(library(lists)).

% AI search module for MesaLog (Phase 4, Subphase 1).
%
% This module implements plain minimax over the generic game contract. It does
% not depend on any concrete game and performs no alpha-beta pruning yet; that
% refinement belongs to the next subphase.
%
% Score convention:
% - +1 when Perspective wins the game.
% - -1 when the opponent of Perspective wins.
% -  0 for a draw.
%
% Scores are always relative to the fixed Perspective player, independently of
% whose turn it is. A state where Perspective is to move is maximizing; a state
% where the opponent is to move is minimizing.
%
% Search uses immutable state transitions only: every child state is produced by
% game:apply_move/4 and the original State is never modified. The contract's
% legal-move list is treated as deterministic; once/1 commits to its first answer.

%% minimax(+Game, +State, +Perspective, -Score)
% Returns the minimax value of State from Perspective's point of view.
% Terminal states are evaluated directly; non-terminal states are expanded via
% game:legal_moves/3 and game:apply_move/4.
minimax(Game, State, Perspective, Score) :-
    (   game:terminal_state(Game, State, Result)
    ->  terminal_score(Result, Perspective, Score)
    ;   game:current_player(Game, State, Player),
        once(game:legal_moves(Game, State, Moves)),
        child_scores(Game, State, Perspective, Moves, Scores),
        (   Scores == []
        ->  Score = 0
        ;   Player == Perspective
        ->  max_list(Scores, Score)
        ;   min_list(Scores, Score)
        )
    ).

% child_scores(+Game, +State, +Perspective, +Moves, -Scores)
% Collects the minimax value of every successor state. findall/3 performs the
% exploration by backtracking over Moves and applying each move immutably.
child_scores(Game, State, Perspective, Moves, Scores) :-
    findall(ChildScore,
            (   member(Move, Moves),
                game:apply_move(Game, State, Move, NextState),
                minimax(Game, NextState, Perspective, ChildScore)
            ),
            Scores).

% terminal_score(+Result, +Perspective, -Score)
% Evaluates a terminal result relative to Perspective.
terminal_score(win(Perspective), Perspective, 1) :-
    !.
terminal_score(win(_Winner), _Perspective, -1) :-
    !.
terminal_score(draw, _Perspective, 0) :-
    !.
terminal_score(_Result, _Perspective, 0).

%% choose_best_move(+Game, +State, +Perspective, -Move, -Score)
% Selects the legal move with the best minimax successor score for Perspective.
% It is intended to be called on Perspective's turn. Ties are resolved in favor
% of the first legal move returned by game:legal_moves/3.
choose_best_move(Game, State, Perspective, Move, Score) :-
    game:current_player(Game, State, Perspective),
    once(game:legal_moves(Game, State, Moves)),
    Moves \== [],
    findall(ChildScore-SelectedMove,
            (   member(SelectedMove, Moves),
                game:apply_move(Game, State, SelectedMove, NextState),
                minimax(Game, NextState, Perspective, ChildScore)
            ),
            ScoredMoves),
    ScoredMoves \== [],
    best_scored_move(ScoredMoves, Score-Move).

% best_scored_move(+ScoredMoves, -Best)
% Selects the highest score, keeping the first candidate on ties.
best_scored_move([First|Rest], Best) :-
    best_scored_move(Rest, First, Best).

best_scored_move([], Best, Best).
best_scored_move([Score-Move|Rest], CurrentScore-CurrentMove, Best) :-
    (   Score > CurrentScore
    ->  best_scored_move(Rest, Score-Move, Best)
    ;   best_scored_move(Rest, CurrentScore-CurrentMove, Best)
    ).
