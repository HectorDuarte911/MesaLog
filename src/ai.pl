:- module(ai, [
    minimax/4,
    choose_best_move/5,
    alpha_beta/4,
    choose_best_move_alpha_beta/5
]).

:- use_module(game).
:- use_module(library(lists)).

% AI search module for MesaLog (Phase 4, Subphases 1-2).
%
% This module implements plain minimax and alpha-beta pruning over the generic
% game contract. It does not depend on any concrete game. Both algorithms read
% the same game hooks and use the same terminal evaluation, so their results are
% directly comparable.
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

% ---------------------------------------------------------------------------
% Alpha-beta pruning (Phase 4, Subphase 2)
% ---------------------------------------------------------------------------

:- discontiguous best_alpha_beta_move/7.

% Search windows are numeric because scores are numeric. The bounds only need
% to be wider than any score the game/evaluation layer can produce; terminal
% scores are -1, 0, 1, so these sentinels are far outside that range.
lower_bound(-1000000).
upper_bound(1000000).

%% alpha_beta(+Game, +State, +Perspective, -Score)
% Returns the same value as minimax/4 while pruning branches that cannot affect
% the final decision. The initial window is deliberately unbounded in both
% directions, so a fully explored call yields the exact minimax score.
alpha_beta(Game, State, Perspective, Score) :-
    lower_bound(Lower),
    upper_bound(Upper),
    alpha_beta_search(Game, State, Perspective, Lower, Upper, Score),
    !.

% alpha_beta_search(+Game, +State, +Perspective, +Alpha, +Beta, -Score)
% Fail-soft alpha-beta: on a cutoff the tightened bound is returned instead of
% the unconditional bound. This keeps the value as informative as possible
% without changing the decision at the root.
alpha_beta_search(Game, State, Perspective, Alpha, Beta, Score) :-
    (   game:terminal_state(Game, State, Result)
    ->  terminal_score(Result, Perspective, Score)
    ;   game:current_player(Game, State, Player),
        once(game:legal_moves(Game, State, Moves)),
        (   Moves == []
        ->  Score = 0
        ;   Player == Perspective
        ->  alpha_beta_max(Game, State, Perspective, Moves, Alpha, Beta, Score)
        ;   alpha_beta_min(Game, State, Perspective, Moves, Alpha, Beta, Score)
        )
    ).

% alpha_beta_max(+Game, +State, +Perspective, +Moves, +Alpha, +Beta, -Score)
% Maximizing node. Alpha is the best value found so far by an ancestor; once it
% reaches Beta, the opponent can force a position no better than an already
% available alternative, so the remaining moves are skipped.
alpha_beta_max(_Game, _State, _Perspective, [], Alpha, _Beta, Alpha).
alpha_beta_max(Game, State, Perspective, [Move|Rest], Alpha, Beta, Score) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Alpha, Beta, ChildScore),
    Alpha1 is max(Alpha, ChildScore),
    (   Alpha1 >= Beta
    ->  Score = Alpha1
    ;   alpha_beta_max(Game, State, Perspective, Rest, Alpha1, Beta, Score)
    ).

% alpha_beta_min(+Game, +State, +Perspective, +Moves, +Alpha, +Beta, -Score)
% Minimizing node, symmetric to alpha_beta_max/7.
alpha_beta_min(_Game, _State, _Perspective, [], _Alpha, Beta, Beta).
alpha_beta_min(Game, State, Perspective, [Move|Rest], Alpha, Beta, Score) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Alpha, Beta, ChildScore),
    Beta1 is min(Beta, ChildScore),
    (   Beta1 =< Alpha
    ->  Score = Beta1
    ;   alpha_beta_min(Game, State, Perspective, Rest, Alpha, Beta1, Score)
    ).

%% choose_best_move_alpha_beta(+Game, +State, +Perspective, -Move, -Score)
% Root-level move selection using alpha-beta. The root keeps a running Alpha and
% uses the same tie rule as choose_best_move/5: the first legal move wins ties.
% The root Beta stays at the upper bound, so the returned score is exact.
choose_best_move_alpha_beta(Game, State, Perspective, Move, Score) :-
    game:current_player(Game, State, Perspective),
    once(game:legal_moves(Game, State, Moves)),
    Moves \== [],
    lower_bound(Lower),
    upper_bound(Upper),
    best_alpha_beta_move(Game, State, Perspective, Moves, Lower, Upper,
                         Score-Move),
    !.

% best_alpha_beta_move(+Game, +State, +Perspective, +Moves, +Alpha, +Beta,
%                      -Best)
% Walks the root moves, narrowing Alpha after each child search and carrying the
% best candidate found so far. A root cutoff can only happen if a score reaches
% the upper bound; in that case the current candidate is already best.
best_alpha_beta_move(Game, State, Perspective, [Move|Rest], Alpha, Beta, Best) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Alpha, Beta, ChildScore),
    Alpha1 is max(Alpha, ChildScore),
    (   Alpha1 >= Beta
    ->  Best = ChildScore-Move
    ;   best_alpha_beta_move(Game, State, Perspective, Rest, Alpha1, Beta,
                             ChildScore-Move, Best)
    ).

best_alpha_beta_move(_Game, _State, _Perspective, [], _Alpha, _Beta, Best, Best).

best_alpha_beta_move(Game, State, Perspective, [Move|Rest], Alpha, Beta,
                     Current, Best) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Alpha, Beta, ChildScore),
    Alpha1 is max(Alpha, ChildScore),
    (   Alpha1 >= Beta
    ->  Best = ChildScore-Move
    ;   better_scored_move(Current, ChildScore-Move, Next),
        best_alpha_beta_move(Game, State, Perspective, Rest, Alpha1, Beta,
                             Next, Best)
    ).

% better_scored_move(+Earlier, +Later, -Best)
% Keeps Earlier on ties so alpha-beta matches the minimax tie rule.
better_scored_move(Score-Move, OtherScore-OtherMove, Best) :-
    (   Score >= OtherScore
    ->  Best = Score-Move
    ;   Best = OtherScore-OtherMove
    ).
