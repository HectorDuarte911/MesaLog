:- module(ai, [
    minimax/4,
    minimax/5,
    choose_best_move/5,
    choose_best_move/6,
    alpha_beta/4,
    alpha_beta/5,
    choose_best_move_alpha_beta/5,
    choose_best_move_alpha_beta/6,
    evaluate/4
]).

:- use_module(game).
:- use_module(engine, []).
:- use_module(library(lists)).
:- use_module(library(error)).

:- discontiguous best_alpha_beta_move/8.

% AI search module for MesaLog (Phase 4, Subphases 1-3).
%
% This module implements plain minimax and fail-soft alpha-beta pruning over
% the generic game contract. It does not depend on any concrete game. Both
% algorithms share terminal evaluation, depth control, and move selection, so
% their results are directly comparable.
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
%
% Depth control (Phase 4.3):
% - The atom unlimited keeps the original unbounded behavior.
% - A non-negative integer N limits search to N plies. At a non-terminal node
%   reached with depth 0, evaluate/4 provides the fallback score.
% - Terminal states are always evaluated, even when the depth is exhausted.
%
% Engine integration (Phase 4.3):
% - ai(minimax) and ai(alpha_beta) are unbounded engine controllers.
% - ai(minimax, Depth) and ai(alpha_beta, Depth) are depth-limited controllers.
% - They are installed as clauses of the multifile engine:choose_move/5 hook.

% Evaluation hook for non-terminal cut-off nodes. Components such as the
% heuristic system can add clauses as ai:evaluation_hook/4 in later phases.
:- multifile evaluation_hook/4.

% Engine move-source hook, extended with AI controllers.
:- multifile engine:choose_move/5.

% ---------------------------------------------------------------------------
% Depth control and cut-off evaluation
% ---------------------------------------------------------------------------

% check_depth(+Depth)
% Accepts the unlimited sentinel or a non-negative integer. A bad depth is a
% caller error rather than a silent failure.
check_depth(unlimited) :-
    !.
check_depth(Depth) :-
    must_be(nonneg, Depth).

% depth_cutoff(+Depth)
% True when a non-terminal node must be evaluated by the fallback instead of
% being expanded further.
depth_cutoff(unlimited) :-
    !,
    fail.
depth_cutoff(Depth) :-
    Depth =< 0.

% next_depth(+Depth, -NextDepth)
% Unlimited stays unlimited; a numeric budget decreases by one ply.
next_depth(unlimited, unlimited) :-
    !.
next_depth(Depth, NextDepth) :-
    NextDepth is Depth - 1.

%% evaluate(+Game, +State, +Perspective, -Score)
% Fallback evaluation for a non-terminal node where search stops. A concrete
% evaluation component may supply ai:evaluation_hook/4 clauses; otherwise the
% neutral score 0 is used.
evaluate(Game, State, Perspective, Score) :-
    (   evaluation_hook(Game, State, Perspective, HookScore)
    ->  Score = HookScore
    ;   Score = 0
    ).

% ---------------------------------------------------------------------------
% Plain minimax
% ---------------------------------------------------------------------------

%% minimax(+Game, +State, +Perspective, -Score)
% Unbounded minimax value of State from Perspective's point of view.
minimax(Game, State, Perspective, Score) :-
    minimax(Game, State, Perspective, unlimited, Score),
    !.

%% minimax(+Game, +State, +Perspective, +Depth, -Score)
% Depth-limited minimax. Depth is either unlimited or a non-negative integer.
minimax(Game, State, Perspective, Depth, Score) :-
    check_depth(Depth),
    minimax_search(Game, State, Perspective, Depth, Score),
    !.

% minimax_search(+Game, +State, +Perspective, +Depth, -Score)
% Terminal states are evaluated first, then the depth budget is checked, then
% successors are explored. This order guarantees a real terminal result is never
% replaced by the cut-off fallback.
minimax_search(Game, State, Perspective, Depth, Score) :-
    (   game:terminal_state(Game, State, Result)
    ->  terminal_score(Result, Perspective, Score)
    ;   depth_cutoff(Depth)
    ->  evaluate(Game, State, Perspective, Score)
    ;   next_depth(Depth, NextDepth),
        game:current_player(Game, State, Player),
        once(game:legal_moves(Game, State, Moves)),
        child_scores(Game, State, Perspective, NextDepth, Moves, Scores),
        (   Scores == []
        ->  Score = 0
        ;   Player == Perspective
        ->  max_list(Scores, Score)
        ;   min_list(Scores, Score)
        )
    ).

% child_scores(+Game, +State, +Perspective, +Depth, +Moves, -Scores)
% Collects the value of every successor at the same remaining depth.
% findall/3 performs the exploration by backtracking over Moves and applying
% each move immutably.
child_scores(Game, State, Perspective, Depth, Moves, Scores) :-
    findall(ChildScore,
            (   member(Move, Moves),
                game:apply_move(Game, State, Move, NextState),
                minimax_search(Game, NextState, Perspective, Depth, ChildScore)
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
% Unbounded move selection for Perspective. Ties keep the first legal move.
choose_best_move(Game, State, Perspective, Move, Score) :-
    choose_best_move(Game, State, Perspective, unlimited, Move, Score),
    !.

%% choose_best_move(+Game, +State, +Perspective, +Depth, -Move, -Score)
% Depth-limited move selection for Perspective.
choose_best_move(Game, State, Perspective, Depth, Move, Score) :-
    check_depth(Depth),
    game:current_player(Game, State, Perspective),
    once(game:legal_moves(Game, State, Moves)),
    Moves \== [],
    next_depth(Depth, NextDepth),
    findall(ChildScore-SelectedMove,
            (   member(SelectedMove, Moves),
                game:apply_move(Game, State, SelectedMove, NextState),
                minimax_search(Game, NextState, Perspective, NextDepth,
                               ChildScore)
            ),
            ScoredMoves),
    ScoredMoves \== [],
    best_scored_move(ScoredMoves, Score-Move),
    !.

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
% Alpha-beta pruning
% ---------------------------------------------------------------------------

% Search windows are numeric because scores are numeric. The bounds only need
% to be wider than any score the game/evaluation hook can produce; terminal
% scores are -1, 0, 1, so these sentinels are far outside that range.
lower_bound(-1000000).
upper_bound(1000000).

%% alpha_beta(+Game, +State, +Perspective, -Score)
% Unbounded alpha-beta value, equivalent to minimax/4.
alpha_beta(Game, State, Perspective, Score) :-
    alpha_beta(Game, State, Perspective, unlimited, Score),
    !.

%% alpha_beta(+Game, +State, +Perspective, +Depth, -Score)
% Depth-limited alpha-beta value, equivalent to minimax/5 at the same depth.
alpha_beta(Game, State, Perspective, Depth, Score) :-
    check_depth(Depth),
    lower_bound(Lower),
    upper_bound(Upper),
    alpha_beta_search(Game, State, Perspective, Depth, Lower, Upper, Score),
    !.

% alpha_beta_search(+Game, +State, +Perspective, +Depth, +Alpha, +Beta, -Score)
% Fail-soft alpha-beta: on a cutoff the tightened bound is returned instead of
% the unconditional bound. This keeps the value as informative as possible
% without changing the decision at the root.
alpha_beta_search(Game, State, Perspective, Depth, Alpha, Beta, Score) :-
    (   game:terminal_state(Game, State, Result)
    ->  terminal_score(Result, Perspective, Score)
    ;   depth_cutoff(Depth)
    ->  evaluate(Game, State, Perspective, Score)
    ;   next_depth(Depth, NextDepth),
        game:current_player(Game, State, Player),
        once(game:legal_moves(Game, State, Moves)),
        (   Moves == []
        ->  Score = 0
        ;   Player == Perspective
        ->  alpha_beta_max(Game, State, Perspective, NextDepth, Moves,
                           Alpha, Beta, Score)
        ;   alpha_beta_min(Game, State, Perspective, NextDepth, Moves,
                           Alpha, Beta, Score)
        )
    ).

% alpha_beta_max(+Game, +State, +Perspective, +Depth, +Moves, +Alpha, +Beta,
%                -Score)
% Maximizing node. Alpha is the best value found so far by an ancestor; once it
% reaches Beta, the opponent can force a position no better than an already
% available alternative, so the remaining moves are skipped.
alpha_beta_max(_Game, _State, _Perspective, _Depth, [], Alpha, _Beta, Alpha).
alpha_beta_max(Game, State, Perspective, Depth, [Move|Rest], Alpha, Beta,
               Score) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Depth, Alpha, Beta,
                      ChildScore),
    Alpha1 is max(Alpha, ChildScore),
    (   Alpha1 >= Beta
    ->  Score = Alpha1
    ;   alpha_beta_max(Game, State, Perspective, Depth, Rest, Alpha1, Beta,
                       Score)
    ).

% alpha_beta_min(+Game, +State, +Perspective, +Depth, +Moves, +Alpha, +Beta,
%                -Score)
% Minimizing node, symmetric to alpha_beta_max/8.
alpha_beta_min(_Game, _State, _Perspective, _Depth, [], _Alpha, Beta, Beta).
alpha_beta_min(Game, State, Perspective, Depth, [Move|Rest], Alpha, Beta,
               Score) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Depth, Alpha, Beta,
                      ChildScore),
    Beta1 is min(Beta, ChildScore),
    (   Beta1 =< Alpha
    ->  Score = Beta1
    ;   alpha_beta_min(Game, State, Perspective, Depth, Rest, Alpha, Beta1,
                       Score)
    ).

%% choose_best_move_alpha_beta(+Game, +State, +Perspective, -Move, -Score)
% Unbounded root-level move selection using alpha-beta.
choose_best_move_alpha_beta(Game, State, Perspective, Move, Score) :-
    choose_best_move_alpha_beta(Game, State, Perspective, unlimited, Move,
                                Score),
    !.

%% choose_best_move_alpha_beta(+Game, +State, +Perspective, +Depth, -Move,
%%                             -Score)
% Depth-limited root-level move selection using alpha-beta.
choose_best_move_alpha_beta(Game, State, Perspective, Depth, Move, Score) :-
    check_depth(Depth),
    game:current_player(Game, State, Perspective),
    once(game:legal_moves(Game, State, Moves)),
    Moves \== [],
    next_depth(Depth, NextDepth),
    lower_bound(Lower),
    upper_bound(Upper),
    best_alpha_beta_move(Game, State, Perspective, NextDepth, Moves, Lower,
                         Upper, Score-Move),
    !.

% best_alpha_beta_move(+Game, +State, +Perspective, +Depth, +Moves, +Alpha,
%                      +Beta, -Best)
% Walks the root moves, narrowing Alpha after each child search and carrying the
% best candidate found so far. A root cutoff can only happen if a score reaches
% the upper bound; in that case the current candidate is already best.
best_alpha_beta_move(Game, State, Perspective, Depth, [Move|Rest], Alpha,
                     Beta, Best) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Depth, Alpha, Beta,
                      ChildScore),
    Alpha1 is max(Alpha, ChildScore),
    (   Alpha1 >= Beta
    ->  Best = ChildScore-Move
    ;   best_alpha_beta_move(Game, State, Perspective, Depth, Rest, Alpha1,
                             Beta, ChildScore-Move, Best)
    ).

best_alpha_beta_move(_Game, _State, _Perspective, _Depth, [], _Alpha, _Beta,
                     Best, Best).

best_alpha_beta_move(Game, State, Perspective, Depth, [Move|Rest], Alpha,
                     Beta, Current, Best) :-
    game:apply_move(Game, State, Move, NextState),
    alpha_beta_search(Game, NextState, Perspective, Depth, Alpha, Beta,
                      ChildScore),
    Alpha1 is max(Alpha, ChildScore),
    (   Alpha1 >= Beta
    ->  Best = ChildScore-Move
    ;   better_scored_move(Current, ChildScore-Move, Next),
        best_alpha_beta_move(Game, State, Perspective, Depth, Rest, Alpha1,
                             Beta, Next, Best)
    ).

% better_scored_move(+Earlier, +Later, -Best)
% Keeps Earlier on ties so alpha-beta matches the minimax tie rule.
better_scored_move(Score-Move, OtherScore-OtherMove, Best) :-
    (   Score >= OtherScore
    ->  Best = Score-Move
    ;   Best = OtherScore-OtherMove
    ).

% ---------------------------------------------------------------------------
% Engine controllers
% ---------------------------------------------------------------------------

% engine:choose_move/5 is multifile, so the AI module installs its own move
% sources without making the engine depend on search internals. The engine still
% validates every selected move through arbiter:check_move/4 in step_match/3.
engine:choose_move(ai(minimax), Game, State, Player, Move) :-
    choose_best_move(Game, State, Player, Move, _).
engine:choose_move(ai(alpha_beta), Game, State, Player, Move) :-
    choose_best_move_alpha_beta(Game, State, Player, Move, _).
engine:choose_move(ai(minimax, Depth), Game, State, Player, Move) :-
    choose_best_move(Game, State, Player, Depth, Move, _).
engine:choose_move(ai(alpha_beta, Depth), Game, State, Player, Move) :-
    choose_best_move_alpha_beta(Game, State, Player, Depth, Move, _).
