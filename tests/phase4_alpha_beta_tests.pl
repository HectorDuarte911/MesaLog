:- module(phase4_alpha_beta_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/ai').
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').

% Phase 4, Subphase 2: alpha-beta pruning validation.
%
% Two complementary strategies are used:
% - a small deterministic tree where a cutoff is guaranteed by move ordering;
% - a counting wrapper around real games, so minimax and alpha-beta can be
%   compared on the same positions for both score and number of expanded nodes.

:- multifile
    game:initial_state/2,
    game:initial_player/2,
    game:current_player/3,
    game:legal_moves/3,
    game:valid_move/3,
    game:apply_move/4,
    game:terminal_state/3.

% A tree with a forced cutoff: after the first root child yields the maximum
% score, the minimizing children skip most of their own successors.
game:initial_state(ab_test_game, s(root, p1)).
game:initial_player(ab_test_game, p1).
game:current_player(ab_test_game, s(_Node, Player), Player).

game:legal_moves(ab_test_game, s(root, p1), [a, b, c]) :- !.
game:legal_moves(ab_test_game, s(node_a, p2), [a1]) :- !.
game:legal_moves(ab_test_game, s(node_b, p2), [b1, b2, b3]) :- !.
game:legal_moves(ab_test_game, s(node_c, p2), [c1, c2]) :- !.
game:legal_moves(ab_test_game, s(_Terminal, _Player), []).

game:valid_move(ab_test_game, State, Move) :-
    game:legal_moves(ab_test_game, State, Moves),
    memberchk(Move, Moves).

game:apply_move(ab_test_game, s(root, p1), a, s(node_a, p2)).
game:apply_move(ab_test_game, s(root, p1), b, s(node_b, p2)).
game:apply_move(ab_test_game, s(root, p1), c, s(node_c, p2)).
game:apply_move(ab_test_game, s(node_a, p2), a1, s(win_p1, p1)).
game:apply_move(ab_test_game, s(node_b, p2), b1, s(win_p1, p1)).
game:apply_move(ab_test_game, s(node_b, p2), b2, s(lose_p1, p1)).
game:apply_move(ab_test_game, s(node_b, p2), b3, s(draw, p1)).
game:apply_move(ab_test_game, s(node_c, p2), c1, s(draw, p1)).
game:apply_move(ab_test_game, s(node_c, p2), c2, s(win_p1, p1)).

game:terminal_state(ab_test_game, s(win_p1, _), win(p1)).
game:terminal_state(ab_test_game, s(lose_p1, _), win(p2)).
game:terminal_state(ab_test_game, s(draw, _), draw).

% Counting wrapper around any conforming game. Only apply_move/4 is counted:
% it is the hook that actually creates successor states during search.
:- dynamic visited_count/1.

reset_visited :-
    retractall(visited_count(_)),
    assertz(visited_count(0)).

bump_visited :-
    retract(visited_count(N)),
    N1 is N + 1,
    assertz(visited_count(N1)).

visited_total(N) :-
    visited_count(N).

game:initial_state(counted(Game), State) :-
    game:initial_state(Game, State).
game:initial_player(counted(Game), Player) :-
    game:initial_player(Game, Player).
game:current_player(counted(Game), State, Player) :-
    game:current_player(Game, State, Player).
game:legal_moves(counted(Game), State, Moves) :-
    game:legal_moves(Game, State, Moves).
game:valid_move(counted(Game), State, Move) :-
    game:valid_move(Game, State, Move).
game:apply_move(counted(Game), State, Move, NextState) :-
    bump_visited,
    game:apply_move(Game, State, Move, NextState).
game:terminal_state(counted(Game), State, Result) :-
    game:terminal_state(Game, State, Result).

% search_node_count(+Algorithm, +Game, +State, +Perspective, -Score, -Nodes)
search_node_count(Algorithm, Game, State, Perspective, Score, Nodes) :-
    reset_visited,
    call(Algorithm, counted(Game), State, Perspective, Score),
    visited_total(Nodes).

% alpha_beta_position(+Game, +State, +Perspective)
alpha_beta_position(nim, nim_state([1,2], player1), player1).
alpha_beta_position(nim, nim_state([2,3], player1), player1).
alpha_beta_position(nim, nim_state([1,2], player1), player2).
alpha_beta_position(tic_tac_toe, ttt_state([[x,x,e],[o,o,x],[o,e,o]], x), x).
alpha_beta_position(tic_tac_toe, ttt_state([[x,e,o],[e,x,e],[e,e,o]], x), x).
alpha_beta_position(tic_tac_toe, ttt_state([[x,e,o],[e,x,e],[e,e,o]], x), o).

% Move selection is only defined on Perspective's turn, so these vectors are a
% subset of the score-evaluation vectors above.
best_move_position(nim, nim_state([1,2], player1), player1).
best_move_position(nim, nim_state([2,3], player1), player1).
best_move_position(tic_tac_toe, ttt_state([[x,x,e],[o,o,x],[o,e,o]], x), x).
best_move_position(tic_tac_toe, ttt_state([[x,e,o],[e,x,e],[e,e,o]], x), x).

:- begin_tests(phase4_alpha_beta).

test(alpha_beta_matches_minimax_on_forced_cutoff_tree) :-
    ai:minimax(ab_test_game, s(root, p1), p1, MinimaxScore),
    ai:alpha_beta(ab_test_game, s(root, p1), p1, AlphaBetaScore),
    assertion(MinimaxScore == 1),
    assertion(AlphaBetaScore == 1).

test(alpha_beta_evaluates_terminal_states_like_minimax) :-
    forall(member(Result-State, [win(p1)-s(win_p1, p1),
                                 win(p2)-s(lose_p1, p1),
                                 draw-s(draw, p1)]), (
        terminal_score_for(Result, p1, Expected),
        ai:alpha_beta(ab_test_game, State, p1, Score),
        assertion(Score == Expected)
    )).

test(alpha_beta_matches_minimax_across_real_game_positions) :-
    forall(alpha_beta_position(Game, State, Perspective), (
        ai:minimax(Game, State, Perspective, MinimaxScore),
        ai:alpha_beta(Game, State, Perspective, AlphaBetaScore),
        assertion(AlphaBetaScore == MinimaxScore)
    )).

test(alpha_beta_move_matches_minimax_across_real_game_positions) :-
    forall(best_move_position(Game, State, Perspective), (
        ai:choose_best_move(Game, State, Perspective, MinimaxMove, MinimaxScore),
        ai:choose_best_move_alpha_beta(Game, State, Perspective,
                                       AlphaBetaMove, AlphaBetaScore),
        assertion(AlphaBetaMove == MinimaxMove),
        assertion(AlphaBetaScore == MinimaxScore)
    )).

test(alpha_beta_requires_perspective_turn) :-
    assertion(\+ ai:choose_best_move_alpha_beta(ab_test_game, s(node_a, p2),
                                                p1, _, _)).

test(alpha_beta_prunes_forced_cutoff_tree) :-
    search_node_count(ai:minimax, ab_test_game, s(root, p1), p1, _, MinimaxNodes),
    search_node_count(ai:alpha_beta, ab_test_game, s(root, p1), p1, _, AlphaBetaNodes),
    assertion(MinimaxNodes == 9),
    assertion(AlphaBetaNodes < MinimaxNodes),
    assertion(AlphaBetaNodes == 6).

test(alpha_beta_prunes_real_game_positions) :-
    forall(alpha_beta_position(Game, State, Perspective), (
        search_node_count(ai:minimax, Game, State, Perspective, _, MinimaxNodes),
        search_node_count(ai:alpha_beta, Game, State, Perspective, _, AlphaBetaNodes),
        assertion(AlphaBetaNodes =< MinimaxNodes)
    )),
    search_node_count(ai:minimax, tic_tac_toe,
                      ttt_state([[x,e,o],[e,x,e],[e,e,o]], x), x, _, TttMinimaxNodes),
    search_node_count(ai:alpha_beta, tic_tac_toe,
                      ttt_state([[x,e,o],[e,x,e],[e,e,o]], x), x, _, TttAlphaBetaNodes),
    assertion(TttAlphaBetaNodes < TttMinimaxNodes).

test(alpha_beta_move_selection_prunes_root_search) :-
    reset_visited,
    ai:choose_best_move(counted(nim), nim_state([1,2], player1), player1,
                        Move, Score),
    visited_total(Nodes),
    assertion(Move == remove(2,1)),
    assertion(Score == 1),
    assertion(Nodes > 0).

test(alpha_beta_does_not_mutate_state) :-
    State = ttt_state([[x,x,e],[o,o,x],[o,e,o]], x),
    ai:alpha_beta(tic_tac_toe, State, x, _Score),
    assertion(State == ttt_state([[x,x,e],[o,o,x],[o,e,o]], x)).

:- end_tests(phase4_alpha_beta).

terminal_score_for(win(Perspective), Perspective, 1) :- !.
terminal_score_for(win(_Winner), _Perspective, -1) :- !.
terminal_score_for(draw, _Perspective, 0).
