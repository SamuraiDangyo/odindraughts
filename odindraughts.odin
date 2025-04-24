package draughts

// OdinDraughts. Draughts engine in Odin language.
// Copyright (C) 2025 Toni Helminen
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strings"

// Constants
BOARD_SIZE :: 10
EMPTY      :: 0
WHITE_PAWN :: 1
BLACK_PAWN :: 2
WHITE_KING :: 3
BLACK_KING :: 4

// Types

Position :: struct {
    row, col: int,
}

Move :: struct {
    from, to: Position,
}

GameState :: struct {
    board: [BOARD_SIZE][BOARD_SIZE]int,
    current_player: int,
    forced_capture: Maybe(Position),
    game_over: bool,
    rng: rand.Rand,
}

// Initialize the board

init_board :: proc() -> [BOARD_SIZE][BOARD_SIZE]int {
    board: [BOARD_SIZE][BOARD_SIZE]int

    for i in 0..<BOARD_SIZE {
        for j in 0..<BOARD_SIZE {
            // Set up initial pawn positions
            if (i + j) % 2 == 1 {
                if i <= 3 { // Rows 1-4 (0-3 in 0-based)
                    board[i][j] = BLACK_PAWN
                } else if i >= 6 { // Rows 7-10 (6-9 in 0-based)
                    board[i][j] = WHITE_PAWN
                } else {
                    board[i][j] = EMPTY
                }
            } else {
                board[i][j] = EMPTY
            }
        }
    }

    return board
}

// Initialize game state

init_game :: proc() -> GameState {
    board := init_board()
    rng := rand.create(u64(os.now()._nsec))

    return GameState{
        board = board,
        current_player = WHITE_PAWN,
        forced_capture = nil,
        game_over = false,
        rng = rng,
    }
}

// Print the board

print_board :: proc(board: [BOARD_SIZE][BOARD_SIZE]int) {
    fmt.print("   ")
    for j in 0..<BOARD_SIZE {
        fmt.printf("%c ", 'a' + j)
    }
    fmt.println()

    for i in 0..<BOARD_SIZE {
        fmt.printf("%2d ", i+1)
        for j in 0..<BOARD_SIZE {
            switch board[i][j] {
                case EMPTY:
                    if (i + j) % 2 == 0 {
                        fmt.print("· ")
                    } else {
                        fmt.print("  ")
                    }
                case WHITE_PAWN:
                    fmt.print("○ ")
                case BLACK_PAWN:
                    fmt.print("● ")
                case WHITE_KING:
                    fmt.print("Ⓞ ")
                case BLACK_KING:
                    fmt.print("⓿ ")
            }
        }
        fmt.println()
    }
}

// Convert algebraic notation to position

notation_to_pos :: proc(notation: string) -> Maybe(Position) {
    if len(notation) != 2 do return nil

    col := to_lower(notation[0]) - 'a'
    row := int(notation[1] - '0') - 1

    if row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE {
        return nil
    }

    return Position{row, col}
}

// Convert position to algebraic notation

pos_to_notation :: proc(pos: Position) -> string {
    builder := strings.builder_make()
    strings.write_byte(&builder, 'a' + byte(pos.col))
    strings.write_int(&builder, pos.row + 1)
    return strings.to_string(builder)
}

// Check if position is valid

is_valid_pos :: proc(pos: Position) -> bool {
    return pos.row >= 0 && pos.row < BOARD_SIZE && pos.col >= 0 && pos.col < BOARD_SIZE
}

// Check if piece belongs to current player

is_current_player_piece :: proc(player: int, piece: int) -> bool {
    return (player == WHITE_PAWN && (piece == WHITE_PAWN || piece == WHITE_KING)) ||
           (player == BLACK_PAWN && (piece == BLACK_PAWN || piece == BLACK_KING))
}

// Check if move is a capture

is_capture_move :: proc(move: Move) -> bool {
    return abs(move.from.row - move.to.row) == 2
}

// Get captured position between two positions

get_captured_pos :: proc(move: Move) -> Position {
    return Position{
        row = (move.from.row + move.to.row) / 2,
        col = (move.from.col + move.to.col) / 2,
    }
}

// Check if piece is a king

is_king :: proc(piece: int) -> bool {
    return piece == WHITE_KING || piece == BLACK_KING
}

// Check if pawn should promote to king

should_promote :: proc(pos: Position, piece: int) -> bool {
    return (piece == WHITE_PAWN && pos.row == 0) ||
           (piece == BLACK_PAWN && pos.row == BOARD_SIZE - 1)
}

// Validate simple move

is_valid_simple_move :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int, move: Move) -> bool {
    from_piece := board[move.from.row][move.from.col]
    to_piece := board[move.to.row][move.to.col]

    // Check destination is empty and on dark square

    if to_piece != EMPTY || (move.to.row + move.to.col) % 2 == 0 {
        return false
    }

    // Check movement direction for pawns

    if !is_king(from_piece) {
        if from_piece == WHITE_PAWN && move.to.row > move.from.row {
            return false // white pawns move up (decreasing row numbers)
        } else if from_piece == BLACK_PAWN && move.to.row < move.from.row {
            return false // black pawns move down (increasing row numbers)
        }
    }

    // Check move distance

    row_diff := abs(move.from.row - move.to.row)
    col_diff := abs(move.from.col - move.to.col)

    return row_diff == 1 && col_diff == 1
}

// Validate capture move

is_valid_capture_move :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int, move: Move) -> bool {
    from_piece := board[move.from.row][move.from.col]
    to_piece := board[move.to.row][move.to.col]

    // Check destination is empty and on dark square

    if to_piece != EMPTY || (move.to.row + move.to.col) % 2 == 0 {
        return false
    }

    // Check movement direction for pawns

    if !is_king(from_piece) {
        if from_piece == WHITE_PAWN && move.to.row > move.from.row {
            return false // white pawns move up
        } else if from_piece == BLACK_PAWN && move.to.row < move.from.row {
            return false // black pawns move down
        }
    }

    // Check move distance

    row_diff := abs(move.from.row - move.to.row)
    col_diff := abs(move.from.col - move.to.col)

    if row_diff != 2 || col_diff != 2 {
        return false
    }

    // Check if there's an opponent's piece to capture

    captured_pos := get_captured_pos(move)
    captured_piece := board[captured_pos.row][captured_pos.col]

    if player == WHITE_PAWN {
        if captured_piece != BLACK_PAWN && captured_piece != BLACK_KING {
            return false
        }
    } else {
        if captured_piece != WHITE_PAWN && captured_piece != WHITE_KING {
            return false
        }
    }

    return true
}

// Check if piece has any captures available

has_captures :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int, pos: Position) -> bool {
    piece := board[pos.row][pos.col]
    directions := [?][2]int{{-2, -2}, {-2, 2}, {2, -2}, {2, 2}}

    for dir in directions {
        to := Position{pos.row + dir[0], pos.col + dir[1]}
        if is_valid_pos(to) {
            move := Move{pos, to}
            if is_valid_capture_move(board, player, move) {
                return true
            }
        }
    }

    return false
}

// Check if current player has any captures available

player_has_captures :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int) -> bool {
    for i in 0..<BOARD_SIZE {
        for j in 0..<BOARD_SIZE {
            if is_current_player_piece(player, board[i][j]) {
                pos := Position{i, j}
                if has_captures(board, player, pos) {
                    return true
                }
            }
        }
    }
    return false
}

// Get all pieces that have captures available

get_pieces_with_captures :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int) -> [dynamic]Position {
    pieces := make([dynamic]Position)

    for i in 0..<BOARD_SIZE {
        for j in 0..<BOARD_SIZE {
            pos := Position{i, j}
            if is_current_player_piece(player, board[i][j]) && has_captures(board, player, pos) {
                append(&pieces, pos)
            }
        }
    }

    return pieces
}

// Get all possible captures for a piece

get_possible_captures :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int, pos: Position) -> [dynamic]Position {
    captures := make([dynamic]Position)
    directions := [?][2]int{{-2, -2}, {-2, 2}, {2, -2}, {2, 2}}

    for dir in directions {
        to := Position{pos.row + dir[0], pos.col + dir[1]}
        if is_valid_pos(to) {
            move := Move{pos, to}
            if is_valid_capture_move(board, player, move) {
                append(&captures, to)
            }
        }
    }

    return captures
}

// Get all possible simple moves for a piece

get_possible_simple_moves :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int, pos: Position) -> [dynamic]Position {
    moves := make([dynamic]Position)
    piece := board[pos.row][pos.col]

    directions: [][2]int
    if is_king(piece) {
        directions = [?][2]int{{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}
    } else if piece == WHITE_PAWN {
        directions = [?][2]int{{-1, -1}, {-1, 1}}
    } else { // BLACK_PAWN
        directions = [?][2]int{{1, -1}, {1, 1}}
    }

    for dir in directions {
        to := Position{pos.row + dir[0], pos.col + dir[1]}
        if is_valid_pos(to) {
            move := Move{pos, to}
            if is_valid_simple_move(board, player, move) {
                append(&moves, to)
            }
        }
    }

    return moves
}

// Make a move on the board

make_move :: proc(gs: ^GameState, move: Move) -> Maybe(Position) {
    from_piece := gs.board[move.from.row][move.from.col]

    // Move the piece

    gs.board[move.to.row][move.to.col] = from_piece
    gs.board[move.from.row][move.from.col] = EMPTY

    // Handle promotion

    if should_promote(move.to, from_piece) {
        gs.board[move.to.row][move.to.col] = from_piece == WHITE_PAWN ? WHITE_KING : BLACK_KING
    }

    // Handle capture

    if is_capture_move(move) {
        captured_pos := get_captured_pos(move)
        gs.board[captured_pos.row][captured_pos.col] = EMPTY

        // Check for additional captures with the same piece
        if has_captures(gs.board, gs.current_player, move.to) {
            return move.to
        }
    }

    return nil
}

// Make a random move for the AI

make_random_move :: proc(gs: ^GameState) {
    must_capture := player_has_captures(gs.board, gs.current_player)

    // Get all possible moves

    possible_moves: [dynamic]Move

    if must_capture {
        pieces := get_pieces_with_captures(gs.board, gs.current_player)
        for piece in pieces {
            captures := get_possible_captures(gs.board, gs.current_player, piece)
            for to in captures {
                append(&possible_moves, Move{piece, to})
            }
        }
    } else {
        for i in 0..<BOARD_SIZE {
            for j in 0..<BOARD_SIZE {
                pos := Position{i, j}
                if is_current_player_piece(gs.current_player, gs.board[i][j]) {
                    moves := get_possible_simple_moves(gs.board, gs.current_player, pos)
                    for to in moves {
                        append(&possible_moves, Move{pos, to})
                    }
                }
            }
        }
    }

    if len(possible_moves) == 0 {
        gs.game_over = true
        return
    }

    // Select random move

    move_idx := rand.int_max(len(possible_moves), &gs.rng)
    move := possible_moves[move_idx]

    // Print the move

    fmt.printf("Black moves: %s to %s\n", pos_to_notation(move.from), pos_to_notation(move.to))

    // Make the move

    additional_capture := make_move(gs, move)

    // Handle multiple captures

    for additional_capture != nil {
        captures := get_possible_captures(gs.board, gs.current_player, additional_capture.?)
        if len(captures) == 0 do break

        // Select random capture

        capture_idx := rand.int_max(len(captures), &gs.rng)
        next_move := Move{additional_capture.?, captures[capture_idx]}

        fmt.printf("Black continues capture to %s\n", pos_to_notation(next_move.to))
        additional_capture = make_move(gs, next_move)
    }

    // Switch player

    gs.current_player = gs.current_player == WHITE_PAWN ? BLACK_PAWN : WHITE_PAWN
}

// Check if game is over

is_game_over :: proc(board: [BOARD_SIZE][BOARD_SIZE]int, player: int) -> bool {
    white_pieces, black_pieces := 0, 0

    for i in 0..<BOARD_SIZE {
        for j in 0..<BOARD_SIZE {
            piece := board[i][j]
            if piece == WHITE_PAWN || piece == WHITE_KING {
                white_pieces += 1
            } else if piece == BLACK_PAWN || piece == BLACK_KING {
                black_pieces += 1
            }
        }
    }

    if white_pieces == 0 {
        fmt.println("Black wins!")
        return true
    } else if black_pieces == 0 {
        fmt.println("White wins!")
        return true
    }

    // Check if current player has any valid moves

    for i in 0..<BOARD_SIZE {
        for j in 0..<BOARD_SIZE {
            pos := Position{i, j}
            if is_current_player_piece(player, board[i][j]) {
                // Check simple moves
                simple_moves := get_possible_simple_moves(board, player, pos)
                if len(simple_moves) > 0 {
                    return false
                }

                // Check captures
                if has_captures(board, player, pos) {
                    return false
                }
            }
        }
    }

    fmt.printf("%s wins by blocking!\n", player == WHITE_PAWN ? "Black" : "White")
    return true
}

// Main game loop

main :: proc() {
    fmt.println("Welcome to 10x10 Draughts (Checkers)!")
    fmt.println("You are playing as White (○) against the computer (Black ●)")
    fmt.println("White pieces: ○ (moves up)")
    fmt.println("Black pieces: ● (moves down)")
    fmt.println("Kings are represented by Ⓞ and ⓿")
    fmt.println("Enter moves in algebraic notation (e.g., 'a3 b5')")
    fmt.println("You must make captures when available.\n")

    gs := init_game()

    for !gs.game_over {
        print_board(gs.board)
        fmt.printf("\nCurrent player: %s\n", gs.current_player == WHITE_PAWN ? "White (○)" : "Black (●)")

        gs.game_over = is_game_over(gs.board, gs.current_player)
        if gs.game_over do break

        if gs.current_player == WHITE_PAWN {

            // Human player's turn (White)

            valid_move := false
            from, to: Position

            for !valid_move {
                // Get from position

                for {
                    fmt.print("Enter piece to move (e.g., a4): ")
                    input: string
                    fmt.scanln(&input)

                    if pos, ok := notation_to_pos(input); ok {
                        if is_current_player_piece(WHITE_PAWN, gs.board[pos.row][pos.col]) {
                            must_capture := player_has_captures(gs.board, WHITE_PAWN)

                            if !must_capture || has_captures(gs.board, WHITE_PAWN, pos) {
                                from = pos
                                break
                            } else {
                                fmt.println("You must make a capture with one of your pieces!")
                            }
                        } else {
                            fmt.println("That's not your piece!")
                        }
                    } else {
                        fmt.println("Invalid position!")
                    }
                }

                // Get to position

                for {
                    fmt.print("Enter destination (e.g., b5): ")
                    input: string
                    fmt.scanln(&input)

                    if pos, ok := notation_to_pos(input); ok {
                        move := Move{from, pos}

                        if is_capture_move(move) {
                            if is_valid_capture_move(gs.board, WHITE_PAWN, move) {
                                to = pos
                                valid_move = true
                                break
                            } else {
                                fmt.println("Invalid capture move!")
                            }
                        } else {
                            must_capture := player_has_captures(gs.board, WHITE_PAWN)
                            if must_capture {
                                fmt.println("You must make a capture move!")
                            } else if is_valid_simple_move(gs.board, WHITE_PAWN, move) {
                                to = pos
                                valid_move = true
                                break
                            } else {
                                fmt.println("Invalid move!")
                            }
                        }
                    } else {
                        fmt.println("Invalid position!")
                    }
                }
            }

            // Make the move

            additional_capture := make_move(&gs, Move{from, to})

            // Handle multiple captures

            for additional_capture != nil {
                print_board(gs.board)
                fmt.println("You must continue capturing with the same piece!")

                valid_move = false
                new_to: Position

                for !valid_move {
                    fmt.print("Enter additional capture (e.g., d8): ")
                    input: string
                    fmt.scanln(&input)

                    if pos, ok := notation_to_pos(input); ok {
                        move := Move{additional_capture.?, pos}
                        if is_capture_move(move) && is_valid_capture_move(gs.board, WHITE_PAWN, move) {
                            new_to = pos
                            valid_move = true
                        } else {
                            fmt.println("Invalid additional capture!")
                        }
                    } else {
                        fmt.println("Invalid position!")
                    }
                }

                additional_capture = make_move(&gs, Move{additional_capture.?, new_to})
            }

            // Switch player

            gs.current_player = BLACK_PAWN
        } else {
            // Computer's turn (Black)

            make_random_move(&gs)
        }
    }
}
