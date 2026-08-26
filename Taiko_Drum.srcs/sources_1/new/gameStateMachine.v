`timescale 1ns / 1ps

module gameStateMachine(
    input wire clk,
    input wire start_raw,pause_raw,reset,right_raw,left_raw,
    input wire ss0_b, ss0_c, GC_lt, GC_eq, 
    output wire gameCounter_ld, gameCounter_clr,
    output wire score_ld, score_clr,
    output wire score_decrement, score_shift,
    output wire noteNum_select, noteNum_ld, noteNum_clr,
    output wire sseg_ld, sseg_clr, sseg_finish,
    output wire led_s0, led_s1,
    output wire speed_clr,
    output wire[1:0] speed_set,
    output wire[1:0] speed_led,
    output wire clk_reset
    );
    
    reg gameCounter_ld_reg, gameCounter_clr_reg;
    reg score_ld_reg, score_clr_reg;
    reg score_decrement_reg, score_shift_reg;
    reg noteNum_select_reg, noteNum_ld_reg, noteNum_clr_reg;
    reg sseg_ld_reg, sseg_clr_reg, sseg_finish_reg;
    reg led_s0_reg, led_s1_reg;
    reg speed_clr_reg;
    reg[1:0] speed_set_reg, speed_led_reg;
    reg clk_reset_reg;
    
    assign gameCounter_ld  = gameCounter_ld_reg;
    assign gameCounter_clr = gameCounter_clr_reg;
    assign score_ld        = score_ld_reg;
    assign score_clr       = score_clr_reg;
    assign score_decrement = score_decrement_reg;
    assign score_shift     = score_shift_reg;
    assign noteNum_select  = noteNum_select_reg;
    assign noteNum_ld      = noteNum_ld_reg;
    assign noteNum_clr     = noteNum_clr_reg;
    assign sseg_ld         = sseg_ld_reg;
    assign sseg_clr        = sseg_clr_reg;
    assign sseg_finish     = sseg_finish_reg;
    assign led_s0          = led_s0_reg;
    assign led_s1          = led_s1_reg;
    assign speed_clr       = speed_clr_reg;
    assign speed_set       = speed_set_reg;
    assign speed_led       = speed_led_reg;
    assign clk_reset       = clk_reset_reg;
    
    wire start, pause, right, left;
    
    rising_edge_detector r(.clk(clk), .reset(reset), .signal(right_raw), .outedge(right));
    rising_edge_detector p(.clk(clk), .reset(reset), .signal(pause_raw), .outedge(pause));
    rising_edge_detector l(.clk(clk), .reset(reset), .signal(left_raw), .outedge(left));
    rising_edge_detector s(.clk(clk), .reset(reset), .signal(start_raw), .outedge(start));
    
    localparam OFF = 4'b0000;
    localparam speed1 = 4'b0001;
    localparam speed2 = 4'b0010;
    localparam speed3 = 4'b0011;
    localparam gameStart = 4'b0100;
    localparam game1 = 4'b0101;
    localparam game2 = 4'b0110;
    localparam game3_scoreInc = 4'b0111;
    localparam game4_scoreDec = 4'b1000;
    localparam pauseGame = 4'b1001;
    localparam finish = 4'b1010;
    localparam init = 4'b1011;
    
    reg[3:0] state = init, nextState;
    reg[1:0] game_clk_sel;
    
    //Handling inputs
    reg right_pending = 1'b0, left_pending = 1'b0;
    wire hit_right = right_pending | right;
    wire hit_left  = left_pending  | left;

    always @(posedge clk) begin
        if (reset || state == gameStart || state == OFF || state == speed1 || state == speed2|| state == speed3) begin
            right_pending <= 1'b0;
            left_pending  <= 1'b0;
        end else if (state == game2) begin
            right_pending <= 1'b0;
            left_pending  <= 1'b0;
        end else begin
            if (right)begin 
                right_pending <= 1'b1; 
                left_pending  <= 1'b0;
            end
            if (left) begin  
                right_pending <= 1'b0; 
                left_pending  <= 1'b1;
            end
        end
    end
    
    //State Transitions
    always @(*)begin
        nextState = state;
        case(state)
            init:
                                nextState = OFF;    
            OFF: begin
                if(right)       nextState = speed1;
                else if(start)  nextState = gameStart;
            end
            speed1: begin
                if(right)       nextState = OFF;
                else if(left)   nextState = speed2;
            end
            speed2: begin
                if(right)       nextState = OFF;
                else if(left)   nextState = speed3;
            end
            speed3: begin
                if(right)       nextState = OFF;
                else if(left)   nextState = speed1;
            end
            gameStart:
                                nextState = game1;
            game1: begin
                if(reset)       nextState = OFF;
                else if(pause)  nextState = pauseGame;
                else            nextState = game2;
            end
            game2:begin
                if(GC_eq)       nextState = finish;
                else if(reset)  nextState = OFF;
                else if(pause)  nextState = pauseGame;
                else if(((hit_right && !hit_left && !ss0_b) || (hit_left && !hit_right && !ss0_c)) && GC_lt)
                                nextState = game3_scoreInc;
                else            nextState = game4_scoreDec;
            end
            game3_scoreInc:begin
                if(reset)       nextState = OFF;
                else if(pause)  nextState = pauseGame;
                else            nextState = game1;
            end
            game4_scoreDec:begin
                if(reset)       nextState = OFF;
                else if(pause)  nextState = pauseGame;
                else            nextState = game1;
            end
            pauseGame:begin
                if(reset)       nextState = OFF;
                else if(pause)  nextState = game1;
            end
            finish:begin
                if(reset)       nextState = OFF;
            end
            default: nextState = OFF;
        endcase
    end
    
    //Outputs
    always @(*)begin
        gameCounter_ld_reg  = 0; gameCounter_clr_reg = 0;
        score_ld_reg        = 0; score_clr_reg       = 0;
        score_decrement_reg = 0; score_shift_reg     = 0;
        noteNum_select_reg  = 0; noteNum_ld_reg      = 0; noteNum_clr_reg     = 0;
        sseg_ld_reg         = 0; sseg_clr_reg        = 0; sseg_finish_reg     = 0;
        led_s0_reg          = 0; led_s1_reg          = 0;
        speed_clr_reg       = 0;
        case(state)
            init: begin
                speed_set_reg = 0;
                speed_clr_reg = 1;
            end
            OFF: begin
                speed_set_reg = 0;
                speed_led_reg = 0;
                sseg_clr_reg = 1;
                led_s1_reg = 1;
                noteNum_clr_reg = 1;
            end
            speed1: begin
                speed_led_reg = 1;
                led_s0_reg = 1;
            end
            speed2: begin
                speed_led_reg = 2;
                led_s0_reg = 1;
            end
            speed3: begin
                speed_led_reg = 3;
                led_s0_reg = 1;  
            end
            gameStart: begin
                speed_set_reg = game_clk_sel;
                noteNum_select_reg = 1; 
                noteNum_ld_reg = 1;
                score_clr_reg = 1;
                gameCounter_clr_reg = 1;
            end
            game1: begin
                noteNum_ld_reg = 1;
                score_ld_reg = 1;
                gameCounter_ld_reg = 1;
            end
            game2: begin
                sseg_ld_reg = 1;
            end
            game3_scoreInc: begin
                score_ld_reg = 1;
                score_shift_reg = 1;
            end
            game4_scoreDec: begin
                score_ld_reg = 1;
                score_decrement_reg = 1;
            end
            finish: begin
                sseg_finish_reg = 1;
                sseg_ld_reg = 1;
            end
            default:;
        endcase
    end
    
    //Sequential Block to remember speed_clk_reg
    always @(posedge clk) begin
        case(state)
            init:   game_clk_sel = 1;
            speed1: game_clk_sel = 1;
            speed2: game_clk_sel = 2;
            speed3: game_clk_sel = 3;
        endcase
    end
    
    //State Engine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= OFF;
        end
        else
            state      <= nextState;
    end
endmodule
