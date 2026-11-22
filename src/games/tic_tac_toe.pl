:- module(tic_tac_toe, []).

:- use_module('../game').

% Tic-Tac-Toe game module for MesaLog (Phase 2, Subphase 2).
%
% This module implements Tic-Tac-Toe through the generic MesaLog game contract
% declared in game.pl. It provides an immutable board state, legal move
% generation, move validation/application, win/draw terminal detection, a
% human-readable display, and basic evaluable features.
%
% Default game identifier:
% - tic_tac_toe
%   Board: 3x3 empty grid
%   Players: x and o
%   Starting player: x
%
% State representation:
% - ttt_state(Board, CurrentPlayer)
%   - Board: list of 3 rows, each row is a list of 3 cells.
%     A cell is x, o, or e (empty).
%   - CurrentPlayer: atom identifying the player who must move (x or o).
%
% Move representation:
% - place(Row, Col)
%   - Row: 1-based row index (1..3, top to bottom).
%   - Col: 1-based column index (1..3, left to right).
%   The mark placed is the CurrentPlayer from the state.

:- multifile
    game:initial_state/2,
    game:initial_player/2,
    game:current_player/3,
    game:legal_moves/3,
    game:valid_move/3,
    game:apply_move/4,
    game:terminal_state/3,
    game:display_state/2,
    game:features/3.

%% Default Tic-Tac-Toe configuration

default_ttt_board([
    [e, e, e],
    [e, e, e],
    [e, e, e]
]).

default_ttt_players(x, o).

other_player(x, o).
other_player(o, x).

%% Game contract implementation

% initial_state(+Game, -State)
% Provides the initial Tic-Tac-Toe state.
game:initial_state(tic_tac_toe, ttt_state(Board, StartPlayer)) :-
    default_ttt_board(Board),
    default_ttt_players(StartPlayer, _OtherPlayer).

% initial_player(+Game, -Player)
% Provides the player who moves first in Tic-Tac-Toe.
game:initial_player(tic_tac_toe, StartPlayer) :-
    default_ttt_players(StartPlayer, _OtherPlayer).

% current_player(+Game, +State, -Player)
% Extracts the player to move from the immutable Tic-Tac-Toe state.
game:current_player(tic_tac_toe, ttt_state(_Board, Player), Player).

% legal_moves(+Game, +State, -Moves)
% Generates all legal place(Row, Col) moves in empty cells. Terminal states
% produce an empty move list.
game:legal_moves(tic_tac_toe, State, []) :-
    game:terminal_state(tic_tac_toe, State, _Result),
    !.
game:legal_moves(tic_tac_toe, ttt_state(Board, _Player), Moves) :-
    findall(place(Row, Col), empty_cell(Board, Row, Col), Moves).

% empty_cell(+Board, -Row, -Col)
% Enumerates coordinates of empty cells by backtracking through rows and cols.
empty_cell(Board, Row, Col) :-
    nth1(Row, Board, BoardRow),
    nth1(Col, BoardRow, e).

% valid_move(+Game, +State, +Move)
% True when Move is a legal place move in a non-terminal Tic-Tac-Toe state.
game:valid_move(tic_tac_toe, State, Move) :-
    \+ game:terminal_state(tic_tac_toe, State, _Result),
    valid_ttt_move(State, Move).

% valid_ttt_move(+State, +Move)
% Validates move structure and checks that the target cell is empty.
valid_ttt_move(ttt_state(Board, _Player), place(Row, Col)) :-
    integer(Row),
    integer(Col),
    between(1, 3, Row),
    between(1, 3, Col),
    nth1(Row, Board, BoardRow),
    nth1(Col, BoardRow, e).

% apply_move(+Game, +State, +Move, -NewState)
% Applies a legal place move, producing a new immutable state. The current
% player's mark is placed in the selected cell and turn passes to the opponent.
game:apply_move(tic_tac_toe, ttt_state(Board, Player), place(Row, Col), ttt_state(NewBoard, NextPlayer)) :-
    valid_ttt_move(ttt_state(Board, Player), place(Row, Col)),
    place_mark(Board, Row, Col, Player, NewBoard),
    other_player(Player, NextPlayer).

% place_mark(+Board, +Row, +Col, +Mark, -NewBoard)
% Recursively rebuilds the board with Mark placed at Row, Col.
% The input board is not modified; a new board term is returned.
place_mark([BoardRow|RestRows], 1, Col, Mark, [NewRow|RestRows]) :-
    !,
    place_in_row(BoardRow, Col, Mark, NewRow).
place_mark([BoardRow|RestRows], Row, Col, Mark, [BoardRow|NewRestRows]) :-
    Row > 1,
    NextRow is Row - 1,
    place_mark(RestRows, NextRow, Col, Mark, NewRestRows).

% place_in_row(+Row, +Col, +Mark, -NewRow)
% Recursively rebuilds a row with Mark placed at Col.
place_in_row([_Cell|RestCells], 1, Mark, [Mark|RestCells]) :-
    !.
place_in_row([Cell|RestCells], Col, Mark, [Cell|NewRestCells]) :-
    Col > 1,
    NextCol is Col - 1,
    place_in_row(RestCells, NextCol, Mark, NewRestCells).

% terminal_state(+Game, +State, -Result)
% A Tic-Tac-Toe state is terminal when a player has three in a row or when the
% board is full (draw). Win is checked before draw.
game:terminal_state(tic_tac_toe, ttt_state(Board, _Player), win(Winner)) :-
    winning_mark(Board, Winner),
    !.
game:terminal_state(tic_tac_toe, ttt_state(Board, _Player), draw) :-
    board_full(Board).

% winning_mark(+Board, -Mark)
% True when Mark (x or o) occupies a complete winning line.
winning_mark(Board, Mark) :-
    player_mark(Mark),
    line(Line),
    line_marks(Board, Line, [Mark, Mark, Mark]).

% player_mark(-Mark)
% Enumerates valid player marks.
player_mark(x).
player_mark(o).

% line(-Line)
% Defines the eight winning lines as lists of row-col coordinates.
line([(1,1), (1,2), (1,3)]).
line([(2,1), (2,2), (2,3)]).
line([(3,1), (3,2), (3,3)]).
line([(1,1), (2,1), (3,1)]).
line([(1,2), (2,2), (3,2)]).
line([(1,3), (2,3), (3,3)]).
line([(1,1), (2,2), (3,3)]).
line([(1,3), (2,2), (3,1)]).

% line_marks(+Board, +Line, -Marks)
% Extracts cell marks for the coordinates in Line.
line_marks(_Board, [], []).
line_marks(Board, [(Row, Col)|Rest], [Mark|Marks]) :-
    board_cell(Board, Row, Col, Mark),
    line_marks(Board, Rest, Marks).

% board_cell(+Board, +Row, +Col, -Mark)
% Retrieves the mark at Row, Col.
board_cell(Board, Row, Col, Mark) :-
    nth1(Row, Board, BoardRow),
    nth1(Col, BoardRow, Mark).

% board_full(+Board)
% True when no empty cell remains.
board_full(Board) :-
    \+ (member(Row, Board), member(e, Row)).

% display_state(+Game, +State)
% Prints a human-readable 3x3 board representation.
game:display_state(tic_tac_toe, ttt_state(Board, CurrentPlayer)) :-
    format('Tic-Tac-Toe state~n', []),
    format('  Current player: ~w~n', [CurrentPlayer]),
    format('    1 2 3~n', []),
    display_rows(Board, 1).

% display_rows(+Rows, +RowIndex)
% Prints each board row with its index.
display_rows([], _RowIndex).
display_rows([Row|Rest], RowIndex) :-
    display_cells(Row, Symbols),
    format('  ~w ~w ~w ~w~n', [RowIndex|Symbols]),
    NextRowIndex is RowIndex + 1,
    display_rows(Rest, NextRowIndex).

% display_cells(+Cells, -Symbols)
% Converts internal cell atoms to display symbols.
display_cells([], []).
display_cells([Cell|Rest], [Symbol|Symbols]) :-
    cell_symbol(Cell, Symbol),
    display_cells(Rest, Symbols).

% cell_symbol(+Cell, -Symbol)
% Maps internal empty marker to a dot for readability.
cell_symbol(e, '.') :- !.
cell_symbol(Mark, Mark).

% features(+Game, +State, -Features)
% Provides basic evaluable features for Tic-Tac-Toe states. These features can
% be used later by heuristic evaluation and AI components.
game:features(tic_tac_toe, ttt_state(Board, CurrentPlayer), Features) :-
    other_player(CurrentPlayer, Opponent),
    mark_count(Board, x, XCount),
    mark_count(Board, o, OCount),
    mark_count(Board, e, EmptyCount),
    line_potential_count(Board, CurrentPlayer, CurrentPotential),
    line_potential_count(Board, Opponent, OpponentPotential),
    center_mark(Board, CenterMark),
    Features = ttt_features{
        current_player: CurrentPlayer,
        opponent: Opponent,
        board: Board,
        x_count: XCount,
        o_count: OCount,
        empty_count: EmptyCount,
        current_player_potential_lines: CurrentPotential,
        opponent_potential_lines: OpponentPotential,
        center_mark: CenterMark
    }.

% mark_count(+Board, +Mark, -Count)
% Counts how many cells contain Mark in the whole board.
mark_count(Board, Mark, Count) :-
    findall(1, (member(Row, Board), member(Cell, Row), Cell == Mark), Ones),
    length(Ones, Count).

% line_potential_count(+Board, +Player, -Count)
% Counts winning lines that are still potentially completable by Player
% (no opponent mark present).
line_potential_count(Board, Player, Count) :-
    other_player(Player, Opponent),
    findall(Line, (line(Line), \+ line_has_mark(Board, Line, Opponent)), Lines),
    length(Lines, Count).

% line_has_mark(+Board, +Line, +Mark)
% True when any coordinate in Line contains Mark.
line_has_mark(Board, Line, Mark) :-
    member((Row, Col), Line),
    board_cell(Board, Row, Col, Mark),
    !.

% center_mark(+Board, -Mark)
% Returns the mark in the center cell (2,2).
center_mark(Board, Mark) :-
    board_cell(Board, 2, 2, Mark).
