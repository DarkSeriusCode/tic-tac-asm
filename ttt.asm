%define CELLS_IN_A_ROW 3
%define ROW_COUNT 3

%define CELL_SIZE 80
%define LINES_THINNESS 7
%define PADDING 25
%define GAME_FIELD_SIZE PADDING * 2 + LINES_THINNESS * 2 + CELL_SIZE * CELLS_IN_A_ROW

%define WINDOW_SIZE GAME_FIELD_SIZE

%define MSG_HEIGHT CELL_SIZE + LINES_THINNESS * 2
%define MSG_Y_POS (WINDOW_SIZE - MSG_HEIGHT) / 2
%define MSG_FONT_SIZE 36

%define BG_COLOR 0xFFACBD14
%define LINE_COLOR 0xDD161616
%define X_COLOR 0xFF0000FF
%define O_COLOR 0xFFFF0000
%define MSG_BG_COLOR 0x991E1E1E

%define RESTART_KEY_CODE 82

%macro fn_prologue 0
    push rbp
    mov rbp, rsp
%endmacro

%macro fn_epilogue 0
    mov rsp, rbp
    pop rbp
%endmacro

%macro to_float 2
    mov eax, %2
    cvtsi2ss %1, eax
%endmacro

%macro check_win 3
    mov rdi, %1
    mov rsi, %2
    mov rdx, %3
    call checkWin
%endmacro

%macro show_msg 1
    mov rdi, %1
    call showMsg
%endmacro

;; ------------------------------------------------------------------------------------------------

section .text
    global main
    extern _exit, printf
    extern InitWindow, CloseWindow
    extern WindowShouldClose
    extern BeginDrawing
    extern EndDrawing
    extern ClearBackground
    extern DrawRectangle
    extern DrawLineEx, DrawRing
    extern GetMouseX, GetMouseY, IsMouseButtonPressed
    extern TextLength, DrawText, MeasureText
    extern IsKeyPressed

;; rdi - cell index
setCell:
    fn_prologue
    mov rdi, rax

    movzx rcx, byte [game_field+rax]
    cmp rcx, 0
    jne .setted

    cmp byte [curr_player], 1
    jne .player_O
    .player_X:
        mov byte [game_field+rax], 1
        mov byte [curr_player], 2
        jmp .setted
    .player_O:
        mov byte [game_field+rax], 2
        mov byte [curr_player], 1
    .setted:
    fn_epilogue
ret

;; rdi, rsi, rdx - cells to check
checkWin:
    fn_prologue
    movzx rbx, byte [game_field+rsi]
    cmp byte [game_field+rdi], bl
    jne .not_equal
    cmp byte [game_field+rdx], bl
    jne .not_equal
    cmp rbx, 0
    je .not_equal
    mov rax, 1
    jmp .done

    .not_equal:
        mov rax, 0
    .done:
    fn_epilogue
ret

checkWinAllCases:
    fn_prologue
    mov rcx, 0
    check_win 0, 1, 2
    or rcx, rax
    check_win 3, 4, 5
    or rcx, rax
    check_win 6, 7, 8
    or rcx, rax
    check_win 0, 3, 6
    or rcx, rax
    check_win 1, 4, 7
    or rcx, rax
    check_win 2, 5, 8
    or rcx, rax
    check_win 0, 4, 8
    or rcx, rax
    check_win 2, 4, 6
    or rcx, rax
    mov rax, rcx
    fn_epilogue
ret

isGameFieldFull:
    fn_prologue
    mov rcx, 0
    .loop:
        movzx rbx, byte [game_field+rcx]
        cmp rbx, 0
        je .not_full
        mov rax, 0
        inc rcx
        cmp rcx, 9
        jl .loop
    mov rax, 1
    jmp .done

    .not_full:
        mov rax, 0

    .done:
    fn_epilogue
ret

getClickedCellIndex:
    fn_prologue
    sub rsp, 8+2

    call GetMouseX
    mov dword [rsp], eax
    call GetMouseY
    mov dword [rsp+4], eax

    ;; Find click X-pos
    mov rax, PADDING
    mov rbx, PADDING + CELL_SIZE
    mov rcx, 3
    mov edx, dword [rsp] ;; mouse X pos
    .findXLoop:
        ;; Bounds check
        cmp rdx, 25
        jle .out_of_bounds
        cmp rdx, PADDING + CELL_SIZE * CELLS_IN_A_ROW + LINES_THINNESS * 3
        jge .out_of_bounds
        ;;If mouseX >= rax && mouseX <= rbx
        cmp rdx, rax
        jl .not_betweenX
        cmp rdx, rbx
        jg .not_betweenX
        mov rax, 3
        sub rax, rcx
        mov byte [rsp+8], al
        jmp .findXLoop_after

        .not_betweenX:
        add rax, CELL_SIZE + LINES_THINNESS
        add rbx, CELL_SIZE + LINES_THINNESS
    loop .findXLoop
    .findXLoop_after:

    ;; Find click Y-pos
    mov rax, PADDING
    mov rbx, PADDING + CELL_SIZE
    mov rcx, 3
    mov edx, dword [rsp+4] ;; mouse Y pos
    .findYLoop:
        ;; Bounds check
        cmp rdx, 25
        jle .out_of_bounds
        cmp rdx, PADDING + CELL_SIZE * CELLS_IN_A_ROW + LINES_THINNESS * 3
        jge .out_of_bounds
        ;;If mouseY >= rax && mouseY <= rbx
        cmp rdx, rax
        jl .not_betweenY
        cmp rdx, rbx
        jg .not_betweenY
        mov rax, 3
        sub rax, rcx
        mov byte [rsp+8+1], al
        jmp .findYLoop_after

        .not_betweenY:
        add rax, CELL_SIZE + LINES_THINNESS
        add rbx, CELL_SIZE + LINES_THINNESS
    loop .findYLoop
    .findYLoop_after:

    ;; Calc Index
    movzx rax, byte [rsp+8+1]
    mov rbx, ROW_COUNT
    mul rbx
    movzx rbx, byte [rsp+8]
    add rax, rbx
    jmp .done

    .out_of_bounds:
    mov rax, -1

    .done:
    add rsp, 8+2
    fn_epilogue
ret

restartGame:
    fn_prologue
    mov byte [curr_player], 1
    mov byte [is_draw], 0
    mov byte [game_over], 0

    mov rcx, 0
    .loop:
        mov byte [game_field+rcx], 0
        inc rcx
        cmp rcx, 9
        jl .loop

    fn_epilogue
ret

drawLines:
    fn_prologue
    ;; HORIZONTAL
    mov rdi, PADDING
    mov rsi, PADDING + CELL_SIZE
    mov rdx, GAME_FIELD_SIZE - PADDING * 2
    mov rcx, LINES_THINNESS
    mov r8, LINE_COLOR
    call DrawRectangle

    mov rdi, PADDING
    mov rsi, PADDING + CELL_SIZE * 2
    mov rdx, GAME_FIELD_SIZE - PADDING * 2
    mov rcx, LINES_THINNESS
    mov r8, LINE_COLOR
    call DrawRectangle

    ;; VERTICAL
    mov rdi, PADDING + CELL_SIZE
    mov rsi, PADDING
    mov rdx, LINES_THINNESS
    mov rcx, GAME_FIELD_SIZE - PADDING * 2
    mov r8, LINE_COLOR
    call DrawRectangle

    mov rdi, PADDING + CELL_SIZE * 2
    mov rsi, PADDING
    mov rdx, LINES_THINNESS
    mov rcx, GAME_FIELD_SIZE - PADDING * 2
    mov r8, LINE_COLOR
    call DrawRectangle
    fn_epilogue
ret

;; rdi - cell index
drawX:
    fn_prologue
    sub rsp, 16
    ;; offset = PADDING + X cell pos * CELL_SIZE + LINES_THINNESS * X cell pos
    ;; calc X
    mov rdx, 0
    mov rax, rdi
    mov rbx, ROW_COUNT
    div rbx ;; rdx is the X cell pos

    mov rcx, PADDING + LINES_THINNESS * 2
    mov rax, CELL_SIZE
    mul rdx
    add rcx, rax

    mov rax, LINES_THINNESS
    mul rdx
    add rcx, rax
    to_float xmm0, ecx
    movss dword [rsp], xmm0

    ;; calc Y
    mov rdx, 0
    mov rax, rdi
    mov rbx, ROW_COUNT
    div rbx ;; rdx is the X cell pos
    mov rdx, rax

    mov rcx, PADDING + LINES_THINNESS * 2
    mov rax, CELL_SIZE
    mul rdx
    add rcx, rax

    mov rax, LINES_THINNESS
    mul rdx
    add rcx, rax
    to_float xmm0, ecx
    movss dword [rsp+4], xmm0

    ;; Calc end point
    to_float xmm0, CELL_SIZE - LINES_THINNESS * 3
    movss xmm1, dword [rsp]
    addss xmm1, xmm0
    movss dword [rsp+8], xmm1

    to_float xmm0, CELL_SIZE - LINES_THINNESS * 3
    movss xmm1, dword [rsp+4]
    addss xmm1, xmm0
    movss dword [rsp+12], xmm1

    movsd xmm0, [rsp]
    movsd xmm1, [rsp+8]
    to_float xmm2, LINES_THINNESS
    mov rdi, X_COLOR
    call DrawLineEx

    movss xmm0, [rsp]
    movss xmm1, [rsp+8]
    movss dword [rsp], xmm1
    movss dword [rsp+8], xmm0

    movsd xmm0, [rsp]
    movsd xmm1, [rsp+8]
    to_float xmm2, LINES_THINNESS
    mov rdi, X_COLOR
    call DrawLineEx

    add rsp, 16
    fn_epilogue
ret

;; rdi - cell index
drawO:
    fn_prologue
    sub rsp, 2+8

    mov rax, rdi
    mov rbx, ROW_COUNT
    mov rdx, 0
    div rbx
    mov byte [rsp], dl   ;; X - pos cell
    mov byte [rsp+1], al ;; Y - pos cell

    ;; center = PADDING + X cell pos * (LINES_THINNESS / 2 + CELL_SIZE) + CELL_SIZE / 2
    ;; calc X
    mov rcx, PADDING

    movzx rax, byte [rsp]
    mov rbx, LINES_THINNESS / 2 + CELL_SIZE
    mul rbx
    add rcx, rax

    mov rax, CELL_SIZE
    mov rbx, 2
    mov rdx, 0
    div rbx
    add rcx, rax
    to_float xmm0, ecx
    movss dword [rsp+2], xmm0

    ;; calc Y
    mov rcx, PADDING

    movzx rax, byte [rsp+1]
    mov rbx, LINES_THINNESS / 2 + CELL_SIZE
    mul rbx
    add rcx, rax

    mov rax, rbx
    mov rbx, 2
    mov rdx, 0
    div rbx
    add rcx, rax
    to_float xmm0, ecx
    movss dword [rsp+2+4], xmm0

    movsd xmm0, [rsp+2]
    to_float xmm1, CELL_SIZE / 2 - LINES_THINNESS * 2
    to_float xmm2, 35
    to_float xmm3, 0
    to_float xmm4, 360
    mov rdi, 16
    mov rsi, O_COLOR
    call DrawRing

    add rsp, 2+8
    fn_epilogue
ret

;; rdi - cell index
drawCellValue:
    fn_prologue

    movzx rax, byte [game_field+rdi]
    cmp rax, 0
    je .done
    cmp rax, 1
    jne .drawX
    call drawO
    .drawX:
    call drawX

    .done:
    fn_epilogue
ret

;; rdi - message to show
showMsg:
    fn_prologue
    mov r12, rsi
    mov r14, rdi

    mov rdi, 0
    mov rsi, MSG_Y_POS
    mov rdx, WINDOW_SIZE
    mov rcx, MSG_HEIGHT
    mov r8, MSG_BG_COLOR
    call DrawRectangle

    ;; Getting a width of chars
    mov rdi, r14
    mov rsi, MSG_FONT_SIZE
    call MeasureText
    mov r13, rax

    mov rax, WINDOW_SIZE
    sub rax, r13
    mov rbx, 2
    mov rdx, 0
    div rbx

    mov rdi, r14
    mov rsi, rax
    mov rdx, (MSG_HEIGHT - MSG_FONT_SIZE) / 2 + MSG_Y_POS
    mov rcx, MSG_FONT_SIZE
    mov r8, 0xFFEEEEEE
    call DrawText

    fn_epilogue
ret

main:
    fn_prologue
    sub rsp, 16

    mov rdx, wndw_title
    mov rsi, WINDOW_SIZE
    mov rdi, WINDOW_SIZE
    call InitWindow
    .game_loop:
        call WindowShouldClose
        cmp rax, 1
        je .close_wndw

        mov rdi, RESTART_KEY_CODE
        call IsKeyPressed
        cmp rax, 1
        jne .after_keyboard_handler
        call restartGame
        .after_keyboard_handler:

        call BeginDrawing
        call drawLines
        mov word [rsp], 0
        .drawCellValue_loop:
            movzx rdi, word [rsp]
            call drawCellValue
            inc word [rsp]
            cmp word [rsp], ROW_COUNT * CELLS_IN_A_ROW
            jl .drawCellValue_loop

        cmp byte [game_over], 1
        jne .after_msg_drawing

        cmp byte [is_draw], 1
        jne .after_printing_draw_msg
        show_msg draw_msg
        jmp .after_msg_drawing
        .after_printing_draw_msg:

        cmp byte [curr_player], 2
        jne .X_wins
        show_msg o_wins_msg
        jmp .after_msg_drawing
        .X_wins:
        show_msg x_wins_msg
        .after_msg_drawing:

        mov edi, BG_COLOR
        call ClearBackground
        call EndDrawing

        cmp byte [game_over], 1
        je .game_loop
        mov rdi, 0
        call IsMouseButtonPressed
        cmp rax, 1
        jne .game_loop
        call getClickedCellIndex
        mov rdi, rax
        call setCell

        call checkWinAllCases
        cmp rax, 1
        jne .after_win_check
        mov byte [game_over], 1
        jmp .game_loop
        .after_win_check:

        call isGameFieldFull
        cmp rax, 1
        jne .after_draw_check
        mov byte [game_over], 1
        mov byte [is_draw], 1
        .after_draw_check:

        jmp .game_loop

    .close_wndw:
    call CloseWindow

    add rsp, 16
    fn_epilogue
    mov rdi, 0
    call _exit


section .data
    wndw_title db "Gay arch user", 0x0
    x_wins_msg db "X wins!", 0x0
    o_wins_msg db "O wins!", 0x0
    draw_msg db "Draw! ;-;", 0x0
    is_draw db 0
    curr_player db 1
    game_over db 0


section .bss
    game_field resb 9
