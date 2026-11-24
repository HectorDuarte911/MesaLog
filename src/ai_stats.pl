:- module(ai_stats, [
    search_report/6,
    compare_search/5,
    print_comparison/5
]).

:- use_module(game).
:- use_module(ai).
:- use_module(library(error)).

% Search statistics for MesaLog (Phase 4, Subphase 4).
%
% This module measures the explored behavior of the two search algorithms without
% changing them. It wraps any conforming game in a counting game term and counts
% game:apply_move/4 calls, which correspond to the successor states actually
% expanded during search.
%
% The counter is dynamic module state, so it is reset and cleaned up around every
% measurement with setup_call_cleanup/3. Search code itself remains pure.
%
% Report shape:
% - report(Score, Nodes)

:- multifile
    game:initial_state/2,
    game:initial_player/2,
    game:current_player/3,
    game:legal_moves/3,
    game:valid_move/3,
    game:apply_move/4,
    game:terminal_state/3.

:- dynamic expanded_nodes/1.

% Counting game wrapper: stats(Game) behaves like Game but increments the
% counter whenever a successor state is produced.
game:initial_state(stats(Game), State) :-
    game:initial_state(Game, State).
game:initial_player(stats(Game), Player) :-
    game:initial_player(Game, Player).
game:current_player(stats(Game), State, Player) :-
    game:current_player(Game, State, Player).
game:legal_moves(stats(Game), State, Moves) :-
    game:legal_moves(Game, State, Moves).
game:valid_move(stats(Game), State, Move) :-
    game:valid_move(Game, State, Move).
game:apply_move(stats(Game), State, Move, NextState) :-
    bump_nodes,
    game:apply_move(Game, State, Move, NextState).
game:terminal_state(stats(Game), State, Result) :-
    game:terminal_state(Game, State, Result).

reset_counter :-
    retractall(expanded_nodes(_)),
    assertz(expanded_nodes(0)).

bump_nodes :-
    retract(expanded_nodes(N)),
    N1 is N + 1,
    assertz(expanded_nodes(N1)).

% algorithm_predicate(+Algorithm, -Predicate)
% Maps a public algorithm name to the ai predicate that implements it.
algorithm_predicate(minimax, ai:minimax).
algorithm_predicate(alpha_beta, ai:alpha_beta).

%% search_report(+Algorithm, +Game, +State, +Perspective, +Depth, -Report)
% Runs Algorithm on Game from Perspective with the given Depth and returns
% report(Score, Nodes), where Nodes is the number of expanded successors.
% Algorithm is minimax or alpha_beta; Depth accepts the same values as the ai
% predicates (unlimited or a non-negative integer).
search_report(Algorithm, Game, State, Perspective, Depth, report(Score, Nodes)) :-
    must_be(oneof([minimax, alpha_beta]), Algorithm),
    algorithm_predicate(Algorithm, Predicate),
    setup_call_cleanup(
        reset_counter,
        (   call(Predicate, stats(Game), State, Perspective, Depth, Score),
            expanded_nodes(Nodes)
        ),
        retractall(expanded_nodes(_))
    ).

%% compare_search(+Game, +State, +Perspective, +Depth, -Comparison)
% Runs both algorithms on the same position and returns:
%   comparison(report(MinimaxScore, MinimaxNodes),
%              report(AlphaBetaScore, AlphaBetaNodes),
%              SavedNodes,
%              Equivalent)
% Equivalent is true when the scores unify structurally, false otherwise.
% SavedNodes is MinimaxNodes - AlphaBetaNodes.
compare_search(Game, State, Perspective, Depth,comparison(MinimaxReport, AlphaBetaReport, SavedNodes,Equivalent)) :-
    search_report(minimax, Game, State, Perspective, Depth, MinimaxReport),
    search_report(alpha_beta, Game, State, Perspective, Depth, AlphaBetaReport),
    MinimaxReport = report(MinimaxScore, MinimaxNodes),
    AlphaBetaReport = report(AlphaBetaScore, AlphaBetaNodes),
    SavedNodes is MinimaxNodes - AlphaBetaNodes,
    (   MinimaxScore == AlphaBetaScore
    ->  Equivalent = true
    ;   Equivalent = false
    ).

%% print_comparison(+Label, +Game, +State, +Perspective, +Depth)
% User-facing helper: computes a comparison and prints it in a readable form.
print_comparison(Label, Game, State, Perspective, Depth) :-
    compare_search(Game, State, Perspective, Depth, Comparison),
    Comparison = comparison(report(MinimaxScore, MinimaxNodes),
                            report(AlphaBetaScore, AlphaBetaNodes),
                            SavedNodes, Equivalent),
    format('~w~n', [Label]),
    format('  minimax:    score ~w, nodes ~w~n', [MinimaxScore, MinimaxNodes]),
    format('  alpha-beta: score ~w, nodes ~w~n', [AlphaBetaScore, AlphaBetaNodes]),
    format('  saved nodes: ~w, equivalent: ~w~n', [SavedNodes, Equivalent]).
