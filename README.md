# 🎲 MesaLog

**MesaLog** is a generic board game engine developed in **SWI-Prolog**. Its goal is to provide a declarative, modular, and extensible foundation for defining, running, and analyzing turn-based games, incorporating explainable move validation, adversarial-search-based artificial intelligence, and a user-configurable heuristic system.

The project is framed in an academic context of declarative programming and aims to demonstrate, in an integrated way, concepts such as recursion, unification, backtracking, negation as failure, metaprogramming, operator definition, modularization, and the use of Prolog's dynamic database.

## 🔭 Overview

Instead of implementing each game as an isolated program, MesaLog separates:

- **The game-specific logic** (initial state, legal moves, state transition, win/draw condition, representation, etc.).
- **The common engine infrastructure** (match management, turns, validation, move search, evaluation, explanation, and history).

Thanks to this separation, the same engine can run different games as long as they comply with a common interface. The architecture is designed to facilitate the addition of new games, new heuristics, and different interaction modes without rewriting the core components.

## 🎯 Goals

- Build a **reusable engine** for board games in Prolog.
- Provide a **generic interface** that allows game modules to be interchanged.
- Implement an **AI based on minimax with alpha-beta pruning**.
- Enable **heuristic configuration** through predefined options and user-defined custom definitions.
- Provide a **declarative arbiter** capable of validating moves and explaining why an action is legal or illegal.
- Incorporate **traceability/explainability** of decisions and reasoning (leveraging Prolog's execution model).
- Define a **move DSL** using operators (`op/3`) to express moves in a readable way.
- Record and query **match history and statistics**.
- Maintain a **declarative and immutable** design for the game state.

## ✨ Key Features

- **Generic multi-game engine**: a single foundation for running different board/tabletop games.
- **Interchangeable game modules**: each game implements a common predicate contract.
- **Planned games**: Nim, Tic-Tac-Toe, and Connect Four.
- **Adversarial search**: minimax with alpha-beta pruning for AI decision-making.
- **Configurable heuristics**:
  - Selection from a catalog of predefined heuristics.
  - Definition of custom heuristics as weighted feature lists.
  - Support for named profiles/configurations.
- **Arbiter and explainable validation**: legality checking of moves and justification of rejections.
- **Move and state explanation**: support for inspecting why a decision or evaluation was made.
- **Move DSL**: expressive notation for entering moves.
- **History and statistics**: storage and querying of matches, results, and metrics.
- **Declarative design**: the state is represented as an immutable term transformed through predicates (without destructive mutation of the board).

## ♟️ Included Games

| Game | Brief description | State type | End condition |
|---|---|---|---|
| **Nim** | A strategy game with heaps/rows of objects; on each turn a player removes elements according to the configured rules. | Heaps and turn | Depends on the variant (e.g., the player who takes the last object loses or wins). |
| **Tic-Tac-Toe** | Two players place their marks on a 3×3 grid trying to align three in a row. | 3×3 board and turn | Three in a row (win) or full board (draw). |
| **Connect Four** | Two players drop pieces into a vertical board trying to align four consecutively. | Board (columns/rows) and turn | Four in a row (win) or full board (draw). |

> The exact definition of rules, internal representation, and supported variants is specified in each game's specific module.

## 🏗️ System Architecture

MesaLog is organized into layers/components with well-defined responsibilities:

1. **Generic game interface (`game`)**  
   Defines the contract that every game must fulfill to integrate with the engine (initial state, turns, legality, transition, terminality, evaluation/utilities, etc.).

2. **Concrete game modules (`games/*`)**  
   Implement the rules and particularities of Nim, Tic-Tac-Toe, and Connect Four according to the common interface.

3. **Match engine (`engine`)**  
   Orchestrates the flow of a match: initialization, move selection, move application, turn alternation, and end detection. The current Phase 1 implementation (`src/engine.pl`) provides match initialization, status inspection, controller lookup, single-step transitions, and a pluggable move-selection hook (`choose_move/5`) for controller-based move sources.

4. **Module integration (`mesalog`)**  
   Composes core modules, provides game module loading, and defines the error/invalid-move handling flow between the engine and validation components. The current Phase 1 implementation (`src/mesalog.pl`) loads core modules, resolves/loads game modules from `src/games/`, exposes a multifile `reject_move/4` validation hook, and provides structured outcomes through `validate_move/4`, `try_move/3`, and `try_step/2`.

5. **Arbiter (`arbiter`)**  
   Verifies that requested moves are valid in the current state and provides reasons for acceptance or rejection.

6. **Artificial intelligence (`ai`)**  
   Implements adversarial search algorithms (minimax and alpha-beta pruning) to select moves.

7. **Heuristics (`heuristics`)**  
   Manages evaluation functions, features, predefined heuristics, and custom weighted heuristics.

8. **Explanation and traceability (`explanation`)**  
   Facilitates the interpretation of validations, evaluations, and AI decisions (e.g., why a move was chosen or discarded).

9. **Move language/DSL (`dsl`)**  
   Defines a user-friendly syntax for expressing moves through operators declared with `op/3`.

10. **History and statistics (`statistics`)**  
    Records match events and results and allows them to be queried through the dynamic database and aggregate queries.

## 🗂️ Repository Structure (Proposed)

```text
mesalog/
├── README.md
├── .gitignore
├── config/                  # Configurations, heuristic profiles, parameters
├── docs/                    # Additional documentation (if applicable)
├── src/
│   ├── game.pl              # Generic game contract/interface
│   ├── engine.pl            # Match engine and orchestration
│   ├── mesalog.pl           # Module integration, composition, and loading
│   ├── arbiter.pl           # Move and rule validation
│   ├── explanation.pl       # Explanation and traceability
│   ├── ai.pl                # Minimax and alpha-beta pruning
│   ├── heuristics.pl        # Predefined and custom heuristics
│   ├── statistics.pl        # Match history and statistics
│   ├── dsl.pl               # Move DSL (op/3)
│   └── games/
│       ├── nim.pl           # Nim implementation
│       ├── tic_tac_toe.pl   # Tic-Tac-Toe implementation
│       └── connect_four.pl  # Connect Four implementation
└── tests/                   # Tests and demo queries
    ├── phase1_core_tests.pl         # Phase 1 interface/engine/integration checks
    ├── phase2_nim_tests.pl           # Phase 2 Nim game module checks
    ├── phase2_tic_tac_toe_tests.pl   # Phase 2 Tic-Tac-Toe game module checks
    ├── phase2_connect_four_tests.pl  # Phase 2 Connect Four game module checks
    ├── phase2_conformance_tests.pl   # Phase 2 cross-game conformance checks
    └── phase3_arbiter_tests.pl       # Phase 3 arbiter and explanation checks
```

> This structure reflects the project's planned organization; files and their contents may evolve during development. Currently implemented modules are `src/game.pl`, `src/engine.pl`, `src/mesalog.pl`, `src/arbiter.pl`, `src/explanation.pl`, `src/games/nim.pl`, `src/games/tic_tac_toe.pl`, and `src/games/connect_four.pl`, validated by `tests/phase1_core_tests.pl`, `tests/phase2_nim_tests.pl`, `tests/phase2_tic_tac_toe_tests.pl`, `tests/phase2_connect_four_tests.pl`, `tests/phase2_conformance_tests.pl`, and `tests/phase3_arbiter_tests.pl`.

## 🔌 Generic Game Interface

Each game module must integrate with the engine through a set of common predicates (contract). The interface is declared in `src/game.pl` as multifile predicates so concrete game modules can provide implementations for each game identifier. The exact signatures may be refined as implementation progresses, but the current contract includes:

| Predicate | Purpose |
|---|---|
| `initial_state(Game, State)` | Unifies `State` with the initial state for `Game`. |
| `initial_player(Game, Player)` | Unifies `Player` with the player who moves first in `Game`. |
| `current_player(Game, State, Player)` | Unifies `Player` with the player to move in `State`. |
| `legal_moves(Game, State, Moves)` | Unifies `Moves` with the list of legal moves available in `State`. |
| `valid_move(Game, State, Move)` | Succeeds if `Move` is legal in `State` (consistent with `legal_moves/3`). |
| `apply_move(Game, State, Move, NewState)` | Produces `NewState` by applying `Move` to `State` without mutating `State`. |
| `terminal_state(Game, State, Result)` | Succeeds if `State` is terminal and unifies `Result` with the outcome (recommended: `win(Player)` or `draw`); fails for non-terminal states. |
| `display_state(Game, State)` | Displays `State` for `Game` in a human-readable form. |
| `features(Game, State, Features)` | Optional hook that unifies `Features` with evaluable characteristics of `State` for heuristic evaluation/analysis. |

**Conventions:**
- `Game` is an atom identifying the game (e.g. `nim`, `tic_tac_toe`, `connect_four`).
- `State` and `Move` are immutable, game-defined terms.
- `apply_move/4` must be a functional state transition (input → output), preserving immutability.
- Game modules extend the contract by adding multifile clauses (e.g. `:- multifile game:initial_state/2.` and `game:initial_state(my_game, State) :- ...`).

## 🤖 Artificial Intelligence

MesaLog includes an AI component for adversarial games based on:

- **Minimax**: exploration of the game tree alternating maximization and minimization levels.
- **Alpha-beta pruning**: an optimization that avoids exploring branches that cannot influence the final decision, while preserving the same result as minimax.

### ⚙️ Planned Configuration

- Selection of the **maximum search depth**.
- Choice of the **heuristic function** (predefined or custom).
- Evaluation of non-terminal states using heuristics when the depth limit is reached.

The goal is for the same search algorithm to operate over different games, as long as they provide the information required by the generic interface (moves, transition, and evaluation/terminality).

## 🎛️ Configurable Heuristic System

A central requirement of MesaLog is that the evaluation used by the AI is not rigid, but **user-configurable**.

### 1. 📋 Predefined Heuristics

The system plans to provide a catalog of named heuristics that can be selected directly, for example:

```prolog
builtin(material).
builtin(positional).
builtin(mobility).
```

*(The specific names will depend on each game and the final implementation.)*

### 2. ⚖️ Custom Weighted Heuristics

The user will be able to define a heuristic as a linear combination of features with weights:

```prolog
weighted([
    (center, 3),
    (mobility, 1),
    (open_threats, 5)
]).
```

Where each pair `(Feature, Weight)` indicates the relative importance of an evaluable feature in the current state.

### 3. 🏷️ Profiles/Configurations (Optional)

Configurations may be reused through named profiles, for example:

```prolog
profile(aggressive, weighted([(open_threats, 5), (center, 2)])).
profile(defensive, weighted([(blocks, 5), (material, 2)])).
```

### 🔗 Integration with Search

The selected heuristic is used in node evaluation during minimax/alpha-beta (especially at leaf nodes of the explored depth or in non-terminal states), allowing the AI's behavior to be adjusted without modifying the search algorithm.

## ⚖️ Arbiter, Validation, and Explainability

MesaLog includes a **declarative arbiter** responsible for ensuring that matches comply with the rules of the game:

- **Move validation**: determines whether a move is legal in the current state.
- **Justified rejection**: indicates the reason why a move is not valid (incorrect turn, occupied position, out-of-range move, game-specific rule, etc.).
- **State consistency**: helps keep the match within valid transitions.

In addition, the **explanation/traceability** component aims to make aspects of the system's reasoning observable, for example:

- Why a move is accepted or rejected.
- Which conditions are satisfied in a terminal state.
- Which factors influence the heuristic evaluation of a position.
- How, at a high level, the AI's move selection is justified.

This approach leverages the declarative nature of Prolog and its search mechanism (unification, resolution, and backtracking) to provide more transparent explanations.

## ⌨️ Move DSL

To improve readability and interaction, MesaLog includes a **domain-specific language (DSL)** for expressing moves through operators defined with `op/3`.

Illustrative examples (subject to the project's final syntax):

```prolog
% Nim: remove 2 elements from heap 1
remove 2 from 1.

% Tic-Tac-Toe: place mark x at row 2, column 3
place x at (2,3).

% Connect Four: drop a piece in column 4
drop piece in 4.
```

The DSL decouples how the user expresses a move from its internal representation, maintaining a more natural interface without losing precision.

## 📊 Match History and Statistics

MesaLog uses Prolog's **dynamic database** mechanisms to record match information, enabling later queries about match progress and results.

### 🧰 Planned Capabilities

- Recording of matches and moves (e.g., through dynamic facts with `assertz/1`).
- Resetting or clearing records (e.g., with `retract/1` and `retractall/1`).
- Aggregate queries and analysis using predicates such as `findall/3`, `bagof/3`, and `setof/3`.

### 🔍 Target Query Examples

- List the move history of a match.
- Obtain the number of wins per player or per game.
- Query results by type of heuristic used.
- Analyze matches that ended in a draw.

## 📐 Declarative Design Principles

- **State immutability**: the game state is represented as a term that is not destructively modified; each move produces a new state.
- **Relations before side effects**: game rules are modeled as predicates that describe what constitutes a valid state or move.
- **Separation of knowledge and control**: the specific rules of each game are kept independent from the search algorithm and the engine.
- **Composability**: heuristics, games, and system components can be combined or replaced with localized changes.
- **Explainability**: decisions and validations are derived from explicit rules, making them easier to inspect.

## 📚 Applied Declarative Programming Concepts

The project is designed to showcase common topics from a declarative programming course in Prolog, including:

- **Lists and recursion**: representation and traversal of boards, heaps, move sequences, and collections of states.
- **Unification and resolution (SLD)**: pattern matching over states and moves, deriving conclusions from rules.
- **Backtracking**: generation and exploration of alternative moves/solutions.
- **Negation as failure and control**: disciplined use of `\+`, `!` (cut), and control predicates where appropriate.
- **Arithmetic and comparison**: evaluation of scores, counts, depths, and numeric conditions.
- **Operators (`op/3`)**: definition of a DSL for moves and/or readable configurations.
- **Metaprogramming**: manipulation of terms/predicates for interpretation, configuration, or explanation.
- **Modularization**: organization of the system into modules with clear interfaces.
- **Deductive and dynamic database**: domain facts/rules together with dynamic recording of matches and statistics.

## 📦 Requirements

- **SWI-Prolog** (recommended: a recent stable version, e.g. 11.x).
- An operating system compatible with SWI-Prolog (Windows, Linux, or macOS).
- (Optional, for development) Git.

### ✅ Installation Check

```bash
swipl --version
```

On Windows, if the command is not recognized, it can be run directly from the installation path (for example, `C:\Program Files\swipl\bin\swipl.exe`) or that folder can be added to the `PATH`.

## 🚀 Intended Usage

> **Note:** The usage interface may vary depending on the final implementation. The following examples are illustrative of the planned design.

### 📥 Load the System

```prolog
% Illustrative example
?- [src/engine].
```

**Current Phase 1 (implemented):**

```prolog
% Load core modules (contract, engine, integration)
?- use_module(src/mesalog).

% Or load modules individually
?- [src/game, src/engine, src/mesalog].
```

### 🧪 Run Validation Tests

```bash
# Phase 1 core tests
swipl -q -g "consult('tests/phase1_core_tests.pl'), run_tests, halt."

# Phase 2 Nim tests
swipl -q -g "consult('tests/phase2_nim_tests.pl'), run_tests, halt."

# Phase 2 Tic-Tac-Toe tests
swipl -q -g "consult('tests/phase2_tic_tac_toe_tests.pl'), run_tests, halt."

# Phase 2 Connect Four tests
swipl -q -g "consult('tests/phase2_connect_four_tests.pl'), run_tests, halt."

# Phase 2 conformance tests
swipl -q -g "consult('tests/phase2_conformance_tests.pl'), run_tests, halt."

# Phase 3 arbiter tests
swipl -q -g "consult('tests/phase3_arbiter_tests.pl'), run_tests, halt."

# All current tests
swipl -q -g "consult('tests/phase1_core_tests.pl'), consult('tests/phase2_nim_tests.pl'), consult('tests/phase2_tic_tac_toe_tests.pl'), consult('tests/phase2_connect_four_tests.pl'), consult('tests/phase2_conformance_tests.pl'), consult('tests/phase3_arbiter_tests.pl'), (run_tests -> halt(0) ; halt(1))"
```

### ▶️ Start a Match

```prolog
% Illustrative example
?- start_match(tic_tac_toe, human, ai).
?- start_match(nim, ai, ai).
?- start_match(connect_four, human, human).
```

### 🎮 Make a Move Using the DSL

```prolog
% Illustrative examples
?- play(place x at (1,1)).
?- play(remove 3 from 2).
?- play(drop piece in 4).
```

### ⚙️ Configure the AI and Heuristics

```prolog
% Select a predefined heuristic
?- configure_heuristic(ai1, builtin(positional)).

% Define a custom weighted heuristic
?- configure_heuristic(ai1,
       weighted([(center, 3), (mobility, 1), (open_threats, 5)])).

% Adjust search parameters (illustrative example)
?- configure_search(ai1, [algorithm(alphabeta), depth(4)]).
```

### 📈 Query History and Statistics

```prolog
% Illustrative examples
?- match_history(Match).
?- player_statistics(Player, Summary).
?- wins_by_game(Game, Total).
```

## 🚧 Project Status

MesaLog is in the **design and early implementation phase**. This README describes the vision, planned architecture, and target capabilities of the system (generic engine, games, minimax/alpha-beta AI, configurable heuristics, explainable arbiter, DSL, and history/statistics).

**Phase 1 (Core Architecture & Generic Engine) progress:**
- **Completed:** Generic game interface contract (`src/game.pl`), match engine with controller-based step transitions (`src/engine.pl`), module integration/composition and structured validation/error flow (`src/mesalog.pl`), and minimal interface-conformance/smoke validation tests (`tests/phase1_core_tests.pl`).
- **Pending in Phase 1:** none.

**Phase 2 (Base Game Modules) progress:**
- **Completed (Subphase 1 - Nim):** Nim module (`src/games/nim.pl`) implementing the generic `game` contract with immutable `nim_state(Heaps, CurrentPlayer)`, `remove(HeapIndex, Amount)` moves, legal move generation/validation, immutable move application, normal-play terminal detection (`win(Player)`), readable display, and basic evaluable features; validated by `tests/phase2_nim_tests.pl`.
- **Completed (Subphase 2 - Tic-Tac-Toe):** Tic-Tac-Toe module (`src/games/tic_tac_toe.pl`) implementing the generic `game` contract with immutable `ttt_state(Board, CurrentPlayer)`, `place(Row, Col)` moves, 3x3 board representation (`x`, `o`, `e`), legal move generation/validation, immutable move application, win/draw terminal detection, readable display, and basic evaluable features; validated by `tests/phase2_tic_tac_toe_tests.pl`.
- **Completed (Subphase 3 - Connect Four):** Connect Four module (`src/games/connect_four.pl`) implementing the generic `game` contract with immutable `c4_state(Board, CurrentPlayer)`, `drop(Column)` moves, 6x7 board representation (`red`, `yellow`, `e`), gravity-based placement, legal move generation/validation, immutable move application, four-in-a-row win/draw terminal detection, readable display, and basic evaluable features; validated by `tests/phase2_connect_four_tests.pl`.
- **Completed (Final subphase - Conformance and consistency):** Cross-game conformance/smoke tests (`tests/phase2_conformance_tests.pl`) verify that Nim, Tic-Tac-Toe, and Connect Four satisfy the generic `game` contract and run through the generic `engine` and `mesalog` integration flow without game-specific core changes.
- **Pending in Phase 2:** none.

**Phase 3 (Arbiter, Explanation, and Traceability) progress:**
- **Completed (Subphase 1 - Arbiter):** Arbiter module (`src/arbiter.pl`) centralizes move validation with structured reasons (shape/bounds/occupancy/amount/column-full/terminal), integrated into `mesalog:validate_move/4` while preserving `reject_move/4` hook precedence.
- **Completed (Subphase 1 - Explanation):** Explanation module (`src/explanation.pl`) provides human-readable move/status explanations and is exposed through `mesalog:explain_move/5` and `mesalog:explain_status/3`.
- **Pending in Phase 3:** deeper traceability hooks for AI evaluation/selection explanations and broader engine/user-facing explanation surfacing as later phases add AI/DSL/history.

The module structure, exact predicate signatures, and definitive commands/queries may be refined as development progresses.

## 👥 Authorship and Context

Project developed in the context of the **Declarative Programming** course (academic term), with an emphasis on the use of SWI-Prolog and the practical application of logic programming paradigm principles.

> **Language convention:** From now on, all source code, identifiers, and comments in this project must be written in English.
