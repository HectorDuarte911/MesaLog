:- module(phase4_search_control_tests, []).

:- use_module(library(plunit)).
:- use_module('../src/game').
:- use_module('../src/engine').
:- use_module('../src/ai').
:- use_module('../src/mesalog').
:- use_module('../src/games/nim').
:- use_module('../src/games/tic_tac_toe').

% Phase 4, Subphase 3: search control and engine integration.
%
% Depth-limited search is checked for terminal/fallback evaluation, equivalence
% between minimax and alpha-beta, and the AI controllers installed as clauses of
% engine:choose_move/5.

:- multifile
    game:initial_state/2,
    game:initial_player/2,
    game:current_player/3,
    game:legal_moves/3,
    game:valid_move/3,
    game:apply_move/4,
    game:terminal_state/3,
    ai:evaluation_hook/4.

% Minimal game with one non-terminal node and one terminal child. It is used to
% observe the cut-off evaluation hook without a large game tree.
game:initial_state(depth_test_game, s(open, p1)).
game:initial_player(depth_test_game, p1).
game:current_player(depth_test_game, s(_Node, Player), Player).

game:legal_moves(depth_test_game, s(open, p1), [go]) :- !.
game:legal_moves(depth_test_game, s(_Node, _Player), []).

game:valid_move(depth_test_game, State, Move) :-
    game:legal_moves(depth_test_game, State, Moves),
    memberchk(Move, Moves).

game:apply_move(depth_test_game, s(open, p1), go, s(done, p2)).

game:terminal_state(depth_test_game, s(done, _Player), draw).

% A game-specific hook score, used only for depth_test_game.
ai:evaluation_hook(depth_test_game, s(open, _Player), p1, 7).

search_depth_position(nim, nim_state([1,2], player1), player1, 0).
search_depth_position(nim, nim_state([1,2], player1), player1, 1).
search_depth_position(nim, nim_state([1,2], player1), player1, 2).
search_depth_position(nim, nim_state([2,3], player1), player1, 2).
search_depth_position(tic_tac_toe,
                      ttt_state([[x,x,e],[o,o,x],[o,e,o]], x), x, 1).
search_depth_position(tic_tac_toe,
                      ttt_state([[x,e,o],[e,x,e],[e,e,o]], x), x, 2).

search_depth_turn_position(nim, nim_state([1,2], player1), player1, 1).
search_depth_turn_position(nim, nim_state([1,2], player1), player1, 2).
search_depth_turn_position(nim, nim_state([2,3], player1), player1, 2).
search_depth_turn_position(tic_tac_toe,
                           ttt_state([[x,x,e],[o,o,x],[o,e,o]], x), x, 1).
search_depth_turn_position(tic_tac_toe,
                           ttt_state([[x,e,o],[e,x,e],[e,e,o]], x), x, 2).

:- begin_tests(phase4_search_control).

test(depth_zero_nonterminal_uses_neutral_fallback) :-
    State = nim_state([1,2], player1),
    ai:minimax(nim, State, player1, 0, MinimaxScore),
    ai:alpha_beta(nim, State, player1, 0, AlphaBetaScore),
    assertion(MinimaxScore == 0),
    assertion(AlphaBetaScore == 0).

test(terminal_state_is_evaluated_before_depth_cutoff) :-
    State = nim_state([0,0,0], player2),
    ai:minimax(nim, State, player1, 0, MinimaxScore),
    ai:alpha_beta(nim, State, player1, 0, AlphaBetaScore),
    assertion(MinimaxScore == 1),
    assertion(AlphaBetaScore == 1).

test(depth_one_sees_immediate_terminal) :-
    State = nim_state([1], player1),
    ai:minimax(nim, State, player1, 1, MinimaxScore),
    ai:alpha_beta(nim, State, player1, 1, AlphaBetaScore),
    assertion(MinimaxScore == 1),
    assertion(AlphaBetaScore == 1).

test(evaluation_hook_overrides_neutral_fallback) :-
    ai:evaluate(depth_test_game, s(open, p1), p1, Score),
    assertion(Score == 7),
    ai:minimax(depth_test_game, s(open, p1), p1, 0, MinimaxScore),
    ai:alpha_beta(depth_test_game, s(open, p1), p1, 0, AlphaBetaScore),
    assertion(MinimaxScore == 7),
    assertion(AlphaBetaScore == 7).

test(evaluation_hook_does_not_override_terminal_result) :-
    ai:minimax(depth_test_game, s(done, p2), p1, 0, Score),
    assertion(Score == 0).

test(unhooked_state_uses_neutral_fallback) :-
    ai:evaluate(nim, nim_state([1,2], player1), player1, Score),
    assertion(Score == 0).

test(invalid_depth_is_rejected) :-
    catch(ai:minimax(nim, nim_state([1], player1), player1, -1, _),
          Error, true),
    assertion(Error = error(_, _)).

test(unbounded_api_matches_sufficient_depth) :-
    State = nim_state([1,2], player1),
    ai:minimax(nim, State, player1, UnboundedScore),
    ai:minimax(nim, State, player1, 10, DeepScore),
    assertion(DeepScore == UnboundedScore),
    ai:alpha_beta(nim, State, player1, DeepAlphaBetaScore),
    assertion(DeepAlphaBetaScore == UnboundedScore).

test(depth_limited_minimax_and_alpha_beta_agree) :-
    forall(search_depth_position(Game, State, Perspective, Depth), (
        ai:minimax(Game, State, Perspective, Depth, MinimaxScore),
        ai:alpha_beta(Game, State, Perspective, Depth, AlphaBetaScore),
        assertion(AlphaBetaScore == MinimaxScore)
    )).

test(depth_limited_move_selection_agrees) :-
    forall(search_depth_turn_position(Game, State, Perspective, Depth), (
        ai:choose_best_move(Game, State, Perspective, Depth,
                            MinimaxMove, MinimaxScore),
        ai:choose_best_move_alpha_beta(Game, State, Perspective, Depth,
                                       AlphaBetaMove, AlphaBetaScore),
        assertion(AlphaBetaMove == MinimaxMove),
        assertion(AlphaBetaScore == MinimaxScore)
    )).

test(engine_controller_minimax_depth_limit) :-
    engine:init_match(nim, [player1-ai(minimax, 3), player2-first_legal],
                      Match),
    engine:step_match(Match, Move, NextMatch),
    ai:choose_best_move(nim, nim_state([3,4,5], player1), player1, 3,
                        ExpectedMove, _),
    assertion(Move == ExpectedMove),
    assertion(NextMatch = match(nim, _, _)).

test(engine_controller_alpha_beta_depth_limit) :-
    engine:init_match(nim, [player1-ai(alpha_beta, 3), player2-first_legal],
                      Match),
    engine:step_match(Match, Move, _NextMatch),
    ai:choose_best_move_alpha_beta(nim, nim_state([3,4,5], player1),
                                   player1, 3, ExpectedMove, _),
    assertion(Move == ExpectedMove).

test(engine_controller_unbounded_minimax) :-
    engine:init_match(depth_test_game, [p1-ai(minimax), p2-first_legal],
                      Match),
    engine:step_match(Match, Move, _NextMatch),
    assertion(Move == go).

test(engine_controller_unbounded_alpha_beta) :-
    engine:init_match(depth_test_game, [p1-ai(alpha_beta), p2-first_legal],
                      Match),
    engine:step_match(Match, Move, _NextMatch),
    assertion(Move == go).

test(explain_step_works_with_ai_controller) :-
    State = ttt_state([[x,x,e],[o,o,x],[o,e,o]], x),
    Match = match(tic_tac_toe, State,
                  [x-ai(alpha_beta, 2), o-first_legal]),
    mesalog:explain_step(Match, Outcome, Explanation),
    assertion(Outcome = ok(place(1,3), _NextMatch)),
    assertion(Explanation.status == accepted).

:- end_tests(phase4_search_control).
