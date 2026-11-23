:- module(nim, []).

:- use_module('../game').

% Nim game module for MesaLog (Phase 2, Subphase 1).
%
% This module implements the Nim game through the generic MesaLog game
% contract declared in game.pl. It provides an immutable state representation,
% legal move generation, move validation/application, terminal detection, a
% human-readable display, and basic evaluable features.
%
% Variant:
% - Normal play: the player who takes the last object wins.
%
% Default game identifier:
% - nim
%   Initial heaps: [3, 4, 5]
%   Players: player1 and player2
%   Starting player: player1
%
% State representation:
% - nim_state(Heaps, CurrentPlayer)
%   - Heaps: list of non-negative integers, each representing remaining objects.
%   - CurrentPlayer: atom identifying the player who must move.
%
% Move representation:
% - remove(HeapIndex, Amount)
%   - HeapIndex: 1-based index of the target heap.
%   - Amount: positive integer number of objects to remove.

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

%% Default Nim configuration

default_nim_heaps([3, 4, 5]).
default_nim_players(player1, player2).

other_player(player1, player2).
other_player(player2, player1).

%% Game contract implementation

% initial_state(+Game, -State)
% Provides the initial Nim state for the supported Nim game identifier.
game:initial_state(nim, nim_state(Heaps, StartPlayer)) :-
    default_nim_heaps(Heaps),
    default_nim_players(StartPlayer, _OtherPlayer).

% initial_player(+Game, -Player)
% Provides the player who moves first in Nim.
game:initial_player(nim, StartPlayer) :-
    default_nim_players(StartPlayer, _OtherPlayer).

% current_player(+Game, +State, -Player)
% Extracts the player to move from the immutable Nim state.
game:current_player(nim, nim_state(_Heaps, Player), Player).

% legal_moves(+Game, +State, -Moves)
% Generates all legal Nim moves in State. A move remove(HeapIndex, Amount) is
% legal when HeapIndex selects a heap and Amount is between 1 and that heap's
% current size. Terminal states produce an empty move list.
game:legal_moves(nim, State, []) :-
    game:terminal_state(nim, State, _Result),
    !.
game:legal_moves(nim, nim_state(Heaps, _Player), Moves) :-
    findall(
        remove(HeapIndex, Amount),
        legal_heap_move(Heaps, HeapIndex, Amount),
        Moves
    ).

% legal_heap_move(+Heaps, -HeapIndex, -Amount)
% Enumerates one legal remove move for any non-empty heap.
legal_heap_move(Heaps, HeapIndex, Amount) :-
    nth1(HeapIndex, Heaps, HeapSize),
    HeapSize > 0,
    between(1, HeapSize, Amount).

% valid_move(+Game, +State, +Move)
% True when Move is legal in the given Nim State. This check is consistent with
% legal_moves/3 and rejects moves in terminal states.
game:valid_move(nim, State, Move) :-
    \+ game:terminal_state(nim, State, _Result),
    valid_nim_move(State, Move).

% valid_nim_move(+State, +Move)
% Validates the structure and bounds of a Nim remove move.
valid_nim_move(nim_state(Heaps, _Player), remove(HeapIndex, Amount)) :-
    integer(HeapIndex),
    integer(Amount),
    Amount > 0,
    nth1(HeapIndex, Heaps, HeapSize),
    Amount =< HeapSize.

% apply_move(+Game, +State, +Move, -NewState)
% Applies a legal Nim move to State, producing a new immutable State.
% The selected heap is reduced by Amount and turn passes to the other player.
game:apply_move(nim, nim_state(Heaps, Player), remove(HeapIndex, Amount), nim_state(NewHeaps, NextPlayer)) :-
    valid_nim_move(nim_state(Heaps, Player), remove(HeapIndex, Amount)),
    remove_from_heap(Heaps, HeapIndex, Amount, NewHeaps),
    other_player(Player, NextPlayer).

% remove_from_heap(+Heaps, +HeapIndex, +Amount, -NewHeaps)
% Recursively builds a new heap list where HeapIndex has Amount fewer objects.
% The input list is not modified; a new list term is returned.
remove_from_heap([Heap|Rest], 1, Amount, [NewHeap|Rest]) :-
    !,
    NewHeap is Heap - Amount.
remove_from_heap([Heap|Rest], HeapIndex, Amount, [Heap|NewRest]) :-
    HeapIndex > 1,
    NextIndex is HeapIndex - 1,
    remove_from_heap(Rest, NextIndex, Amount, NewRest).

% terminal_state(+Game, +State, -Result)
% A Nim state is terminal when all heaps are empty. Under normal play, the
% player facing an empty position cannot move because the previous player took
% the last object; therefore the previous player wins.
game:terminal_state(nim, nim_state(Heaps, CurrentPlayer), win(Winner)) :-
    all_heaps_empty(Heaps),
    other_player(CurrentPlayer, Winner).

% all_heaps_empty(+Heaps)
% True when every heap contains zero objects.
all_heaps_empty([]).
all_heaps_empty([0|Rest]) :-
    all_heaps_empty(Rest).

% display_state(+Game, +State)
% Prints a human-readable representation of the Nim state.
game:display_state(nim, nim_state(Heaps, CurrentPlayer)) :-
    format('Nim state~n', []),
    format('  Current player: ~w~n', [CurrentPlayer]),
    display_heaps(Heaps, 1),
    total_objects(Heaps, Total),
    format('  Total objects: ~w~n', [Total]).

% display_heaps(+Heaps, +Index)
% Prints each heap with its 1-based index and remaining object count.
display_heaps([], _Index).
display_heaps([Heap|Rest], Index) :-
    format('  Heap ~w: ~w~n', [Index, Heap]),
    NextIndex is Index + 1,
    display_heaps(Rest, NextIndex).

% features(+Game, +State, -Features)
% Provides basic evaluable features for Nim states. These features can be used
% later by heuristic evaluation and AI components.
game:features(nim, nim_state(Heaps, CurrentPlayer), Features) :-
    total_objects(Heaps, TotalObjects),
    non_empty_heaps(Heaps, NonEmptyHeaps),
    max_heap(Heaps, MaxHeap),
    nim_sum(Heaps, NimSum),
    other_player(CurrentPlayer, Opponent),
    Features = nim_features{
        current_player: CurrentPlayer,
        opponent: Opponent,
        heaps: Heaps,
        total_objects: TotalObjects,
        non_empty_heaps: NonEmptyHeaps,
        max_heap: MaxHeap,
        nim_sum: NimSum
    }.

% total_objects(+Heaps, -Total)
% Computes the total number of remaining objects in all heaps.
total_objects(Heaps, Total) :-
    sum_list(Heaps, Total).

% non_empty_heaps(+Heaps, -Count)
% Counts heaps that still contain at least one object.
non_empty_heaps([], 0).
non_empty_heaps([Heap|Rest], Count) :-
    non_empty_heaps(Rest, RestCount),
    (   Heap > 0
    ->  Count is RestCount + 1
    ;   Count = RestCount
    ).

% max_heap(+Heaps, -Max)
% Returns the maximum heap size, or 0 when there are no heaps.
max_heap([], 0).
max_heap(Heaps, Max) :-
    max_list(Heaps, Max).

% nim_sum(+Heaps, -NimSum)
% Computes the Nim-sum (bitwise XOR) of all heap sizes.
nim_sum([], 0).
nim_sum([Heap|Rest], NimSum) :-
    nim_sum(Rest, RestNimSum),
    NimSum is Heap xor RestNimSum.
