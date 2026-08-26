`timescale 1ns / 1ps
//=====================================================================
// tb_startonly.v
//
// Minimal harness: reset, press start, then let it run untouched.
// No other buttons are ever pressed.
//
// The point is the waveform. Two signals are built for it:
//     state_str      current state, as text
//     nextState_str  where it is about to go, as text
// Add those to the wave window and set Radix -> ASCII and you can read
// the state names directly instead of decoding 4-bit numbers.
//
// Required sources: gameStateMachine.v rising_edge_detector.v
//                   gameCounter.v noteNum.v score.v sevenSeg.v
//
//   Vivado : add as a simulation source, set as top, Run Simulation.
//            In Scopes pick tb_startonly, drag state_str from Objects
//            into the wave, right-click -> Radix -> ASCII, then
//            restart + run all.
//   Icarus : iverilog -o sim.out -s tb_startonly tb_startonly.v \
//              gameStateMachine.v rising_edge_detector.v gameCounter.v \
//              noteNum.v score.v sevenSeg.v
//            vvp sim.out && gtkwave tb_startonly.vcd
//=====================================================================

module tb_startonly;

    localparam RUN_CYCLES  = 250;                 // how long to free-run
    localparam NOTE_TRACK  = 16'b1011010011010110;

    // ---------------- stimulus ----------------
    reg clk   = 1'b0;
    reg reset = 1'b0;
    reg start_raw = 1'b0;
    reg pause_raw = 1'b0;                         // never pressed
    reg right_raw = 1'b0;                         // never pressed
    reg left_raw  = 1'b0;                         // never pressed
    reg [15:0] sw = NOTE_TRACK;

    always #5 clk = ~clk;                         // 10 ns period

    integer cycle = 0;
    always @(posedge clk) cycle = cycle + 1;

    // ---------------- interconnect ----------------
    wire gameCounter_ld, gameCounter_clr;
    wire score_ld, score_clr, score_decrement, score_shift;
    wire noteNum_select, noteNum_ld, noteNum_clr;
    wire sseg_ld, sseg_clr, sseg_finish;
    wire led_s0, led_s1, speed_clr;
    wire [1:0] speed_set;

    wire ss0_b, ss0_c, GC_lt, GC_eq;
    wire newNote;
    wire [15:0] score_val;
    wire [6:0]  ss3, ss2, ss1, ss0;

    // ---------------- design ----------------
    gameStateMachine fsm (
        .clk(clk),
        .start_raw(start_raw), .pause_raw(pause_raw), .reset(reset),
        .right_raw(right_raw), .left_raw(left_raw),
        .ss0_b(ss0_b), .ss0_c(ss0_c), .GC_lt(GC_lt), .GC_eq(GC_eq),
        .gameCounter_ld(gameCounter_ld), .gameCounter_clr(gameCounter_clr),
        .score_ld(score_ld), .score_clr(score_clr),
        .score_decrement(score_decrement), .score_shift(score_shift),
        .noteNum_select(noteNum_select), .noteNum_ld(noteNum_ld), .noteNum_clr(noteNum_clr),
        .sseg_ld(sseg_ld), .sseg_clr(sseg_clr), .sseg_finish(sseg_finish),
        .led_s0(led_s0), .led_s1(led_s1),
        .speed_clr(speed_clr), .speed_set(speed_set)
    );

    gameCounter gc (
        .clk(clk), .GC_ld(gameCounter_ld), .GC_clr(gameCounter_clr),
        .GC_less_than(GC_lt), .GC_equal(GC_eq)
    );

    noteNum nn (
        .clk(clk), .NN_select(noteNum_select), .NN_ld(noteNum_ld),
        .NN_clr(noteNum_clr), .switchInput(sw), .newNote(newNote)
    );

    score sc (
        .clk(clk), .sc_decrement(score_decrement), .sc_shift(score_shift),
        .sc_ld(score_ld), .sc_clr(score_clr), .score(score_val)
    );

    sevenSeg ss (
        .clk(clk), .newNote(newNote),
        .ss_ld(sseg_ld), .ss_clr(sseg_clr), .ss_finish(sseg_finish),
        .sevenSeg3(ss3), .sevenSeg2(ss2), .sevenSeg1(ss1), .sevenSeg0(ss0),
        .sevenSeg0b(ss0_b), .sevenSeg0c(ss0_c)
    );

    // ---------------- readable state for the waveform ----------------
    function [8*14-1:0] stateName;
        input [3:0] s;
        begin
            case (s)
                4'b0000: stateName = "OFF";
                4'b0001: stateName = "speed1";
                4'b0010: stateName = "speed2";
                4'b0011: stateName = "speed3";
                4'b0100: stateName = "gameStart";
                4'b0101: stateName = "game1";
                4'b0110: stateName = "game2";
                4'b0111: stateName = "game3_INC";
                4'b1000: stateName = "game4_DEC";
                4'b1001: stateName = "pauseGame";
                4'b1010: stateName = "finish";
                4'b1011: stateName = "init";
                default: stateName = "BAD_STATE";
            endcase
        end
    endfunction

    // Drag these into the wave window, Radix -> ASCII.
    wire [3:0] state_num = fsm.state;
    wire [3:0] next_num  = fsm.nextState;

    reg [8*14-1:0] state_str;
    reg [8*14-1:0] nextState_str;

    always @(*) state_str     = stateName(fsm.state);
    always @(*) nextState_str = stateName(fsm.nextState);

    // Handy companions for the wave window.
    wire [4:0]  wave_gameCount = gc.gameCount;
    wire [15:0] wave_score     = score_val;
    wire [15:0] wave_noteNum   = nn.noteNum;

    // ---------------- console trace ----------------
    reg [3:0] prev_state = 4'bxxxx;
    integer   dwell = 0;

    always @(negedge clk) begin
        if (fsm.state !== prev_state) begin
            $display("%7d ns  cycle %4d   %-10s  ->  next %-10s | GC=%2d lt=%b eq=%b | ss0_b=%b ss0_c=%b | score=%0d",
                     $time, cycle, stateName(fsm.state), stateName(fsm.nextState),
                     gc.gameCount, GC_lt, GC_eq, ss0_b, ss0_c, score_val);
            dwell = 0;
        end else begin
            dwell = dwell + 1;
            if (dwell == 20)
                $display("%7d ns  cycle %4d   ... sitting in %-10s (next = %0s)",
                         $time, cycle, stateName(fsm.state), stateName(fsm.nextState));
        end
        prev_state <= fsm.state;
    end

    // ---------------- run ----------------
    initial begin
        $dumpfile("tb_startonly.vcd");
        $dumpvars(0, tb_startonly);

        $display("");
        $display("---------------------------------------------------------------");
        $display(" start-only run: reset, press start, then hands off");
        $display("---------------------------------------------------------------");

        // reset
        @(negedge clk) reset = 1'b1;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        repeat (3) @(negedge clk);

        // the one and only button press
        $display("\n>>> pressing start\n");
        @(negedge clk) start_raw = 1'b1;
        repeat (2) @(negedge clk);
        start_raw = 1'b0;

        // hands off from here
        repeat (RUN_CYCLES) @(negedge clk);

        $display("");
        $display("---------------------------------------------------------------");
        $display(" ended in %0s after %0d cycles", stateName(fsm.state), cycle);
        $display("   gameCount = %0d   score = %0d   noteNum = %b",
                 gc.gameCount, score_val, nn.noteNum);
        $display("---------------------------------------------------------------");
        $display("");
        $finish;
    end

endmodule