:- module(connect_four, []).

:- use_module('../game').

% Connect Four game module for MesaLog (Phase 2, Subphase 3).
%
% This module implements Connect Four through the generic MesaLog game contract
% declared in game.pl. It provides an immutable board state, gravity-based drop
% moves, legal move generation, move validation/application, win/draw terminal
% detection, a human-readable display, and basic evaluable features.
%
% Default game identifier:
% - connect_four
%   Board: 6 rows x 7 columns, all empty
%   Players: red and yellow
%   Starting player: red
%
% State representation:
% - c4_state(Board, CurrentPlayer)
%   - Board: list of 6 rows, top to bottom. Each row is a list of 7 cells,
%     left to right. A cell is red, yellow, or e (empty).
%   - CurrentPlayer: atom identifying the player who must move (red or yellow).
%
% Move representation:
% - drop(Column)
%   - Column: 1-based column index (1..7, left to right).
%   The piece placed is the CurrentPlayer from the state. Gravity places the
%   piece in the lowest empty row of the selected column.

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

%% Default Connect Four configuration

default_c4_rows(6).
default_c4_cols(7).

default_c4_board([
    [e, e, e, e, e, e, e],
    [e, e, e, e, e, e, e],
    [e, e, e, e, e, e, e],
    [e, e, e, e, e, e, e],
    [e, e, e, e, e, e, e],
    [e, e, e, e, e, e, e]
]).

default_c4_players(red, yellow).

player_mark(red).
player_mark(yellow).

other_player(red, yellow).
other_player(yellow, red).

%% Game contract implementation

% initial_state(+Game, -State)
% Provides the initial Connect Four state.
game:initial_state(connect_four, c4_state(Board, StartPlayer)) :-
    default_c4_board(Board),
    default_c4_players(StartPlayer, _OtherPlayer).

% initial_player(+Game, -Player)
% Provides the player who moves first in Connect Four.
game:initial_player(connect_four, StartPlayer) :-
    default_c4_players(StartPlayer, _OtherPlayer).

% current_player(+Game, +State, -Player)
% Extracts the player to move from the immutable Connect Four state.
game:current_player(connect_four, c4_state(_Board, Player), Player).

% legal_moves(+Game, +State, -Moves)
% Generates legal drop(Column) moves for columns that are not full. Terminal
% states produce an empty move list.
game:legal_moves(connect_four, State, []) :-
    game:terminal_state(connect_four, State, _Result),
    !.
game:legal_moves(connect_four, c4_state(Board, _Player), Moves) :-
    default_c4_cols(ColCount),
    findall(drop(Col), (between(1, ColCount, Col), column_has_space(Board, Col)), Moves).

% column_has_space(+Board, +Col)
% True when the top cell of the column is empty.
column_has_space(Board, Col) :-
    board_cell(Board, 1, Col, e).

% valid_move(+Game, +State, +Move)
% True when Move is a legal drop move in a non-terminal Connect Four state.
game:valid_move(connect_four, State, Move) :-
    \+ game:terminal_state(connect_four, State, _Result),
    valid_c4_move(State, Move).

% valid_c4_move(+State, +Move)
% Validates move structure and checks that the selected column has space.
valid_c4_move(c4_state(Board, _Player), drop(Col)) :-
    integer(Col),
    default_c4_cols(ColCount),
    between(1, ColCount, Col),
    column_has_space(Board, Col).

% apply_move(+Game, +State, +Move, -NewState)
% Applies a legal drop move, producing a new immutable state. Gravity places the
% current player's piece in the lowest empty row of the selected column and turn
% passes to the opponent.
game:apply_move(connect_four, c4_state(Board, Player), drop(Col), c4_state(NewBoard, NextPlayer)) :-
    valid_c4_move(c4_state(Board, Player), drop(Col)),
    lowest_empty_row(Board, Col, Row),
    place_piece(Board, Row, Col, Player, NewBoard),
    other_player(Player, NextPlayer).

% lowest_empty_row(+Board, +Col, -Row)
% Finds the lowest (largest row index) empty cell in Col.
lowest_empty_row(Board, Col, Row) :-
    default_c4_rows(RowCount),
    lowest_empty_row_from(Board, Col, RowCount, Row).

% lowest_empty_row_from(+Board, +Col, +CurrentRow, -Row)
% Searches upward from CurrentRow until an empty cell is found.
lowest_empty_row_from(Board, Col, CurrentRow, CurrentRow) :-
    board_cell(Board, CurrentRow, Col, e),
    !.
lowest_empty_row_from(Board, Col, CurrentRow, Row) :-
    CurrentRow > 1,
    NextRow is CurrentRow - 1,
    lowest_empty_row_from(Board, Col, NextRow, Row).

% place_piece(+Board, +Row, +Col, +Piece, -NewBoard)
% Recursively rebuilds the board with Piece placed at Row, Col.
place_piece([BoardRow|RestRows], 1, Col, Piece, [NewRow|RestRows]) :-
    !,
    place_in_row(BoardRow, Col, Piece, NewRow).
place_piece([BoardRow|RestRows], Row, Col, Piece, [BoardRow|NewRestRows]) :-
    Row > 1,
    NextRow is Row - 1,
    place_piece(RestRows, NextRow, Col, Piece, NewRestRows).

% place_in_row(+RowCells, +Col, +Piece, -NewRowCells)
% Recursively rebuilds a row with Piece placed at Col.
place_in_row([_Cell|RestCells], 1, Piece, [Piece|RestCells]) :-
    !.
place_in_row([Cell|RestCells], Col, Piece, [Cell|NewRestCells]) :-
    Col > 1,
    NextCol is Col - 1,
    place_in_row(RestCells, NextCol, Piece, NewRestCells).

% board_cell(+Board, +Row, +Col, -Cell)
% Retrieves the cell at Row, Col.
board_cell(Board, Row, Col, Cell) :-
    nth1(Row, Board, BoardRow),
    nth1(Col, BoardRow, Cell).

% terminal_state(+Game, +State, -Result)
% A Connect Four state is terminal when a player has four in a row or when the
% board is full (draw). Win is checked before draw.
game:terminal_state(connect_four, c4_state(Board, _Player), win(Winner)) :-
    winning_mark(Board, Winner),
    !.
game:terminal_state(connect_four, c4_state(Board, _Player), draw) :-
    board_full(Board).

% winning_mark(+Board, -Mark)
% True when Mark (red or yellow) occupies a complete four-in-a-row line.
winning_mark(Board, Mark) :-
    player_mark(Mark),
    line4(Line),
    line_marks(Board, Line, [Mark, Mark, Mark, Mark]).

% line4(-Line)
% Generates all four-cell lines on a 6x7 board: horizontal, vertical, and both
% diagonals. Coordinates are (Row, Col).
line4(Line) :-
    direction(Dr, Dc),
    start_position(Dr, Dc, Row, Col),
    line_from(Row, Col, Dr, Dc, 4, Line).

% direction(-Dr, -Dc)
% Line directions: right, down, down-right, down-left.
direction(0, 1).
direction(1, 0).
direction(1, 1).
direction(1, -1).

% start_position(+Dr, +Dc, -Row, -Col)
% Generates valid start coordinates so a 4-cell line stays inside the board.
start_position(Dr, Dc, Row, Col) :-
    default_c4_rows(RowCount),
    default_c4_cols(ColCount),
    EndRowMin is 1 - min(0, Dr * 3),
    EndRowMax is RowCount - max(0, Dr * 3),
    EndColMin is 1 - min(0, Dc * 3),
    EndColMax is ColCount - max(0, Dc * 3),
    between(EndRowMin, EndRowMax, Row),
    between(EndColMin, EndColMax, Col).

% line_from(+Row, +Col, +Dr, +Dc, +Length, -Line)
% Builds a line of Length coordinates starting at (Row, Col) in direction (Dr,Dc).
line_from(_Row, _Col, _Dr, _Dc, 0, []) :- !.
line_from(Row, Col, Dr, Dc, Length, [(Row, Col)|Rest]) :-
    Length > 0,
    NextLength is Length - 1,
    NextRow is Row + Dr,
    NextCol is Col + Dc,
    line_from(NextRow, NextCol, Dr, Dc, NextLength, Rest).

% line_marks(+Board, +Line, -Marks)
% Extracts cell marks for the coordinates in Line.
line_marks(_Board, [], []).
line_marks(Board, [(Row, Col)|Rest], [Mark|Marks]) :-
    board_cell(Board, Row, Col, Mark),
    line_marks(Board, Rest, Marks).

% board_full(+Board)
% True when no empty cell remains in the top row (all columns full).
board_full(Board) :-
    \+ (member(Row, Board), member(e, Row)).

% display_state(+Game, +State)
% Prints a human-readable 6x7 Connect Four board.
game:display_state(connect_four, c4_state(Board, CurrentPlayer)) :-
    format('Connect Four state~n', []),
    format('  Current player: ~w~n', [CurrentPlayer]),
    format('  1 2 3 4 5 6 7~n', []),
    display_rows(Board),
    format('  -------------~n', []).

% display_rows(+Rows)
% Prints board rows from top to bottom.
display_rows([]).
display_rows([Row|Rest]) :-
    display_cells(Row, Symbols),
    format('  ~w ~w ~w ~w ~w ~w ~w~n', Symbols),
    display_rows(Rest).

% display_cells(+Cells, -Symbols)
% Converts internal cell atoms to display symbols.
display_cells([], []).
display_cells([Cell|Rest], [Symbol|Symbols]) :-
    cell_symbol(Cell, Symbol),
    display_cells(Rest, Symbols).

% cell_symbol(+Cell, -Symbol)
% Maps internal cell markers to compact display symbols.
cell_symbol(e, '.') :- !.
cell_symbol(red, 'R') :- !.
cell_symbol(yellow, 'Y').

% features(+Game, +State, -Features)
% Provides basic evaluable features for Connect Four states. These features can
% be used later by heuristic evaluation and AI components.
game:features(connect_four, c4_state(Board, CurrentPlayer), Features) :-
    other_player(CurrentPlayer, Opponent),
    mark_count(Board, red, RedCount),
    mark_count(Board, yellow, YellowCount),
    mark_count(Board, e, EmptyCount),
    line_potential_count(Board, CurrentPlayer, CurrentPotential),
    line_potential_count(Board, Opponent, OpponentPotential),
    center_column_count(Board, CurrentPlayer, CurrentCenter),
    center_column_count(Board, Opponent, OpponentCenter),
    Features = c4_features{
        current_player: CurrentPlayer,
        opponent: Opponent,
        board: Board,
        red_count: RedCount,
        yellow_count: YellowCount,
        empty_count: EmptyCount,
        current_player_potential_lines: CurrentPotential,
        opponent_potential_lines: OpponentPotential,
        current_player_center_control: CurrentCenter,
        opponent_center_control: OpponentCenter
    }.

% mark_count(+Board, +Mark, -Count)
% Counts how many cells contain Mark in the whole board.
mark_count(Board, Mark, Count) :-
    findall(1, (member(Row, Board), member(Cell, Row), Cell == Mark), Ones),
    length(Ones, Count).

% line_potential_count(+Board, +Player, -Count)
% Counts four-cell lines that are still potentially completable by Player
% (no opponent mark present).
line_potential_count(Board, Player, Count) :-
    other_player(Player, Opponent),
    findall(Line, (line4(Line), \+ line_has_mark(Board, Line, Opponent)), Lines),
    length(Lines, Count).

% line_has_mark(+Board, +Line, +Mark)
% True when any coordinate in Line contains Mark.
line_has_mark(Board, Line, Mark) :-
    member((Row, Col), Line),
    board_cell(Board, Row, Col, Mark),
    !.

% center_column_count(+Board, +Player, -Count)
% Counts Player pieces in the center column (column 4), a common strategic feature.
center_column_count(Board, Player, Count) :-
    findall(1, (between(1, 6, Row), board_cell(Board, Row, 4, Player)), Ones),
    length(Ones, Count).
