`timescale 1ns / 1ps

module taiko_main(
    input wire clk,
    input wire start,pause,reset,right,left,
    input wire[15:0] sw,
    output wire [3:0]  an,
    output wire [6:0]  sseg,
    output wire [15:0] led
    );
        //FSM Outputs
        wire gameCounter_ld, gameCounter_clr;
        wire score_ld, score_clr;
        wire score_decrement, score_shift;
        wire noteNum_select, noteNum_ld, noteNum_clr;
        wire sseg_ld, sseg_clr, sseg_finish;
        wire led_s0, led_s1;
        wire speed_we, speed_clr;
        
        //FSM Inputs
        wire ss0_b, ss0_c, GC_lt, GC_eq;
        
        //Other Wires
        wire newNote;
        wire[1:0] speed_led;
        wire[1:0] speed_set;
        wire[15:0] score;
        wire[6:0] ss3,ss2,ss1,ss0;
        
        //Clock Signals
        wire slowClk;
        wire time_mux_out;
        //Clock Reset Signal (Happens after FSM resets)
        wire clk_reset;
        
        //Seven Seg
        clkdiv  sevenSegClk(.clk(clk), .reset(clk_reset), .divInput(16), .clk_out(time_mux_out)); 
        
        sevenSeg_display sseg_displayVal(.clk(time_mux_out), .ss3(ss3), .ss2(ss2), .ss1(ss1), .ss0(ss0),
                         .anode(an), .sevenSeg(sseg));
        
        //Game
        clk_select currentClk(.clk(clk), .reset(clk_reset), .select(speed_set), .clk_out(slowClk));
        
        gameStateMachine fsm(.clk(slowClk),
                            .start_raw(start), .pause_raw(pause), .reset(reset), .right_raw(right), .left_raw(left),
                            .ss0_b(ss0_b), .ss0_c(ss0_c), .GC_lt(GC_lt), .GC_eq(GC_eq),
                            .gameCounter_ld(gameCounter_ld),
                            .gameCounter_clr(gameCounter_clr),
                            .score_ld(score_ld),
                            .score_clr(score_clr),
                            .score_decrement(score_decrement),
                            .score_shift(score_shift),
                            .noteNum_select(noteNum_select),
                            .noteNum_ld(noteNum_ld),
                            .noteNum_clr(noteNum_clr),
                            .sseg_ld(sseg_ld),
                            .sseg_clr(sseg_clr),
                            .sseg_finish(sseg_finish),
                            .led_s0(led_s0),
                            .led_s1(led_s1),
                            .speed_clr(speed_clr),
                            .speed_set(speed_set),
                            .speed_led(speed_led),
                            .clk_reset(clk_reset)
                            );
        
        gameCounter gameCount(.clk(slowClk), .GC_ld(gameCounter_ld), .GC_clr(gameCounter_clr),
                    .GC_less_than(GC_lt), .GC_equal(GC_eq));
                    
        noteNum noteNumber(.clk(slowClk), .NN_select(noteNum_select), .NN_ld(noteNum_ld), .NN_clr(noteNum_clr),
                .switchInput(sw), .newNote(newNote));
        
        score sc(.clk(slowClk), .sc_decrement(score_decrement), .sc_shift(score_shift), .sc_ld(score_ld), .sc_clr(score_clr),
              .score(score));
        
        sevenSeg ssegVal(.clk(slowClk), .newNote(newNote), .ss_ld(sseg_ld), .ss_clr(sseg_clr), .ss_finish(sseg_finish),
                 .sevenSeg3(ss3), .sevenSeg2(ss2), .sevenSeg1(ss1), .sevenSeg0(ss0), .sevenSeg0b(ss0_b), .sevenSeg0c(ss0_c));
              
        led ledVal(.speed_led(speed_led), .score(score), .led_s0(led_s0), .led_s1(led_s1),
            .led(led));
        
        
endmodule
