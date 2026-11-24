:- module(phase4_validation_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/ai').
:- use_module('../src/ai_stats').
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').
:- use_module('../examples/ai_demo').

% Phase 4, Subphase 4: validation and comparison.
%
% Known-game-theory scenarios are used as fixed expected results, then both
% search algorithms are compared on the same positions. Search statistics are
% measured through ai_stats, which counts expanded successor states.

known_position(nim_zero, nim, nim_state([1,2,3], player1), player1, 6).
known_position(nim_win_small, nim, nim_state([1,2], player1), player1, 6).
known_position(nim_win_large, nim, nim_state([3,4,5], player1), player1, 6).
known_position(tic_tac_toe_win, tic_tac_toe,
               ttt_state([[x,x,e],[o,o,x],[o,e,o]], x), x, 3).
known_position(tic_tac_toe_block, tic_tac_toe,
               ttt_state([[o,o,e],[x,e,e],[e,e,x]], x), x, 3).

:- begin_tests(phase4_validation).

test(nim_zero_position_is_losing_for_player_to_move) :-
    State = nim_state([1,2,3], player1),
    ai:minimax(nim, State, player1, Score),
    ai:alpha_beta(nim, State, player1, AlphaBetaScore),
    assertion(Score == -1),
    assertion(AlphaBetaScore == -1),
    ai:choose_best_move(nim, State, player1, Move, BestScore),
    assertion(BestScore == -1),
    assertion(game:valid_move(nim, State, Move)).

test(nim_winning_positions_have_known_best_moves) :-
    ai:choose_best_move(nim, nim_state([1,2], player1), player1,
                        SmallMove, SmallScore),
    assertion(SmallMove == remove(2,1)),
    assertion(SmallScore == 1),
    ai:choose_best_move_alpha_beta(nim, nim_state([3,4,5], player1), player1,
                                   LargeMove, LargeScore),
    assertion(LargeMove == remove(1,2)),
    assertion(LargeScore == 1).

test(tic_tac_toe_takes_immediate_win) :-
    State = ttt_state([[x,x,e],[o,o,x],[o,e,o]], x),
    ai:choose_best_move_alpha_beta(tic_tac_toe, State, x, Move, Score),
    assertion(Move == place(1,3)),
    assertion(Score == 1).

test(tic_tac_toe_blocks_opponent_immediate_win) :-
    State = ttt_state([[o,o,e],[x,e,e],[e,e,x]], x),
    ai:choose_best_move_alpha_beta(tic_tac_toe, State, x, Move, Score),
    assertion(Move == place(1,3)),
    assertion(Score >= 0).

test(known_scenarios_agree_between_algorithms) :-
    forall(known_position(_Name, Game, State, Perspective, _Depth), (
        ai:minimax(Game, State, Perspective, MinimaxScore),
        ai:alpha_beta(Game, State, Perspective, AlphaBetaScore),
        assertion(AlphaBetaScore == MinimaxScore),
        ai:choose_best_move(Game, State, Perspective, MinimaxMove, _),
        ai:choose_best_move_alpha_beta(Game, State, Perspective,
                                       AlphaBetaMove, _),
        assertion(AlphaBetaMove == MinimaxMove)
    )).

test(known_scenarios_agree_with_depth_limit) :-
    forall(known_position(_Name, Game, State, Perspective, Depth), (
        ai:minimax(Game, State, Perspective, Depth, MinimaxScore),
        ai:alpha_beta(Game, State, Perspective, Depth, AlphaBetaScore),
        assertion(AlphaBetaScore == MinimaxScore),
        ai:choose_best_move(Game, State, Perspective, Depth,
                            MinimaxMove, _),
        ai:choose_best_move_alpha_beta(Game, State, Perspective, Depth,
                                       AlphaBetaMove, _),
        assertion(AlphaBetaMove == MinimaxMove)
    )).

test(search_report_counts_expanded_successors) :-
    ai_stats:search_report(minimax, nim, nim_state([2,3], player1),
                           player1, 3, report(MinimaxScore, MinimaxNodes)),
    ai_stats:search_report(alpha_beta, nim, nim_state([2,3], player1),
                           player1, 3, report(AlphaBetaScore, AlphaBetaNodes)),
    assertion(MinimaxScore == AlphaBetaScore),
    assertion(integer(MinimaxNodes)),
    assertion(integer(AlphaBetaNodes)),
    assertion(MinimaxNodes > 0),
    assertion(AlphaBetaNodes > 0).

test(compare_search_reports_equivalent_scores_and_saved_nodes) :-
    ai_stats:compare_search(nim, nim_state([2,3], player1), player1, 3,
                            Comparison),
    Comparison = comparison(report(MinimaxScore, MinimaxNodes),
                            report(AlphaBetaScore, AlphaBetaNodes),
                            SavedNodes, Equivalent),
    assertion(MinimaxScore == AlphaBetaScore),
    assertion(Equivalent == true),
    assertion(MinimaxNodes > AlphaBetaNodes),
    ExpectedSaved is MinimaxNodes - AlphaBetaNodes,
    assertion(SavedNodes == ExpectedSaved).

test(compare_search_is_equivalent_on_known_scenarios) :-
    forall(known_position(_Name, Game, State, Perspective, Depth), (
        ai_stats:compare_search(Game, State, Perspective, Depth,
                                comparison(report(MinimaxScore, _),
                                           report(AlphaBetaScore, _),
                                           _, Equivalent)),
        assertion(Equivalent == true),
        assertion(MinimaxScore == AlphaBetaScore)
    )).

test(unknown_algorithm_is_rejected) :-
    catch(ai_stats:search_report(unknown, nim, nim_state([1], player1),
                                 player1, 1, _),
          Error, true),
    assertion(Error = error(_, _)).

test(print_comparison_is_user_readable) :-
    with_output_to(atom(Output),
        ai_stats:print_comparison('Demo comparison',
                                  nim, nim_state([2,3], player1), player1, 3)),
    assertion(sub_atom(Output, _, _, _, 'Demo comparison')),
    assertion(sub_atom(Output, _, _, _, 'minimax:')),
    assertion(sub_atom(Output, _, _, _, 'alpha-beta:')),
    assertion(sub_atom(Output, _, _, _, 'saved nodes:')).

test(ai_demo_runs_successfully) :-
    with_output_to(atom(Output), ai_demo:demo),
    assertion(sub_atom(Output, _, _, _, 'AI move selection')),
    assertion(sub_atom(Output, _, _, _, 'Search comparison')),
    assertion(sub_atom(Output, _, _, _, 'Tic-Tac-Toe match')),
    assertion(sub_atom(Output, _, _, _, 'result:')).

:- end_tests(phase4_validation).
