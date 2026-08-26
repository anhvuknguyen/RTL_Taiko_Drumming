`timescale 1ns / 1ps
//=====================================================================
// tb_gameplay.v
//
// Debug harness for the gameplay loop:
//   OFF -> gameStart -> game1 -> game2 -> game3_scoreInc / game4_scoreDec
//                          ^                    |
//                          +--------------------+
//   with pauseGame and finish as exits.
//
// This is an INSTRUMENT, not a pass/fail suite. It traces every state
// change together with the datapath, and if the FSM sits in one state
// it prints that state's exit conditions and the live value of every
// signal in them.
//
// Required sources: gameStateMachine.v rising_edge_detector.v
//                   gameCounter.v noteNum.v score.v sevenSeg.v led.v
//
//   Vivado : add as a simulation source, set as top, Run Simulation
//   Icarus : iverilog -o sim.out -s tb_gameplay tb_gameplay.v \
//              gameStateMachine.v rising_edge_detector.v gameCounter.v \
//              noteNum.v score.v sevenSeg.v led.v
//            vvp sim.out
//
// Knobs:
//   VERBOSE     1 = print every clock, 0 = print only on state change
//   STALL_LIMIT cycles in one state before the stall report fires
//   NOTE_PATTERN the switch value loaded as the note track
//=====================================================================

module tb_gameplay;

    localparam VERBOSE      = 0;
    localparam STALL_LIMIT  = 8;
    localparam NOTE_PATTERN = 16'b1011010011010110;

    // ---------------- clock / inputs ----------------
    reg clk   = 1'b0;
    reg reset = 1'b0;
    reg start_raw = 1'b0, pause_raw = 1'b0, right_raw = 1'b0, left_raw = 1'b0;
    reg [15:0] sw = NOTE_PATTERN;

    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer cycle = 0;
    always @(posedge clk) cycle = cycle + 1;

    // ---------------- interconnect ----------------
    wire gameCounter_ld, gameCounter_clr;
    wire score_ld, score_clr, score_decrement, score_shift;
    wire noteNum_select, noteNum_ld, noteNum_clr;
    wire sseg_ld, sseg_clr, sseg_finish;
    wire led_s0, led_s1;
    wire speed_clr;
    wire [1:0] speed_set;

    wire ss0_b, ss0_c, GC_lt, GC_eq;
    wire newNote;
    wire [15:0] score_val;
    wire [6:0]  ss3, ss2, ss1, ss0;
    wire [15:0] led_bus;

    // ---------------- state encodings ----------------
    localparam OFF            = 4'b0000;
    localparam SPEED1         = 4'b0001;
    localparam SPEED2         = 4'b0010;
    localparam SPEED3         = 4'b0011;
    localparam GAMESTART      = 4'b0100;
    localparam GAME1          = 4'b0101;
    localparam GAME2          = 4'b0110;
    localparam GAME3_SCOREINC = 4'b0111;
    localparam GAME4_SCOREDEC = 4'b1000;
    localparam PAUSEGAME      = 4'b1001;
    localparam FINISH         = 4'b1010;
    localparam INIT           = 4'b1011;

    // ---------------- DUT: same wiring as taiko_main ----------------
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
        .clk(clk), .NN_select(noteNum_select), .NN_ld(noteNum_ld), .NN_clr(noteNum_clr),
        .switchInput(sw), .newNote(newNote)
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

    led led_dut (
        .speed_led(speed_set), .score(score_val),
        .led_s0(led_s0), .led_s1(led_s1), .led(led_bus)
    );

    // ---------------- names ----------------
    function [8*14-1:0] stateName;
        input [3:0] s;
        begin
            case (s)
                OFF:            stateName = "OFF";
                SPEED1:         stateName = "speed1";
                SPEED2:         stateName = "speed2";
                SPEED3:         stateName = "speed3";
                GAMESTART:      stateName = "gameStart";
                GAME1:          stateName = "game1";
                GAME2:          stateName = "game2";
                GAME3_SCOREINC: stateName = "game3_INC";
                GAME4_SCOREDEC: stateName = "game4_DEC";
                PAUSEGAME:      stateName = "pauseGame";
                FINISH:         stateName = "finish";
                INIT:           stateName = "init";
                default:        stateName = "??";
            endcase
        end
    endfunction

    // ---------------- trace ----------------
    // Sampled on negedge so every value has settled.
    reg [3:0] prev_state = 4'bxxxx;

    task trace_line;
        begin
            $display("%6d  %-10s | GC=%2d lt=%b eq=%b | note=%b nn=%b | ss0=%b b=%b c=%b | score=%0d | ld:GC=%b sc=%b nn=%b ss=%b | inc=%b dec=%b",
                     cycle, stateName(fsm.state),
                     gc.gameCount, GC_lt, GC_eq,
                     newNote, nn.noteNum,
                     ss0, ss0_b, ss0_c,
                     score_val,
                     gameCounter_ld, score_ld, noteNum_ld, sseg_ld,
                     score_shift, score_decrement);
        end
    endtask

    always @(negedge clk) begin
        if (VERBOSE) trace_line;
        else if (fsm.state !== prev_state) trace_line;
        prev_state <= fsm.state;
    end

    // ---------------- stall detector ----------------
    reg        stall_armed = 1'b0;
    reg [3:0]  stall_ref   = 4'bxxxx;
    integer    stall_count = 0;
    reg        stall_shown = 1'b0;
    integer    stalls      = 0;

    always @(negedge clk) begin
        if (!stall_armed) begin
            stall_count = 0;
            stall_shown = 1'b0;
            stall_ref   = fsm.state;
        end else if (fsm.state !== stall_ref) begin
            stall_ref   = fsm.state;
            stall_count = 0;
            stall_shown = 1'b0;
        end else begin
            stall_count = stall_count + 1;
            if (stall_count >= STALL_LIMIT && !stall_shown) begin
                stall_shown = 1'b1;
                stalls      = stalls + 1;
                report_stall;
            end
        end
    end

    task report_stall;
        begin
            $display("");
            $display("  *** STUCK in %0s for %0d cycles (cycle %0d, t=%0t)",
                     stateName(fsm.state), stall_count, cycle, $time);
            $display("      buttons after edge detect : start=%b pause=%b right=%b left=%b  (reset=%b)",
                     fsm.start, fsm.pause, fsm.right, fsm.left, reset);
            $display("      gameCounter               : gameCount=%0d GC_lt=%b GC_eq=%b",
                     gc.gameCount, GC_lt, GC_eq);
            $display("      sevenSeg                  : ss3=%b ss2=%b ss1=%b ss0=%b  ss0_b=%b ss0_c=%b",
                     ss3, ss2, ss1, ss0, ss0_b, ss0_c);
            $display("      noteNum / score           : noteNum=%b newNote=%b p_score=%0d",
                     nn.noteNum, newNote, sc.p_score);
            // Restates the exit conditions from your own source, so you can
            // see at a glance which term is not being satisfied.
            case (fsm.state)
                GAMESTART:
                    $display("      exit: unconditional -> game1");
                GAME1:
                    $display("      exit: reset -> OFF | pause -> pauseGame | else -> game2");
                GAME2: begin
                    $display("      exit: GC_eq -> finish | reset -> OFF | pause -> pauseGame |");
                    $display("            ((right & !left & !ss0_b) | (left & !right & !ss0_c)) & GC_lt -> game3_INC |");
                    $display("            else -> game4_DEC");
                end
                GAME3_SCOREINC,
                GAME4_SCOREDEC:
                    $display("      exit: reset -> OFF | pause -> pauseGame | else -> game1");
                PAUSEGAME:
                    $display("      exit: reset -> OFF | pause -> game1   (needs a NEW pause edge)");
                FINISH:
                    $display("      exit: reset -> OFF only");
                OFF:
                    $display("      exit: right -> speed1 | start -> gameStart");
                default:
                    $display("      exit: see the case statement for this state");
            endcase
            $display("");
        end
    endtask

    // ---------------- button helpers ----------------
    // A raw press must span two posedges for rising_edge_detector to emit
    // exactly one pulse.
    task press_start;
        begin
            @(negedge clk); start_raw = 1'b1;
            repeat (2) @(negedge clk); start_raw = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task press_right;
        begin
            @(negedge clk); right_raw = 1'b1;
            repeat (2) @(negedge clk); right_raw = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task press_pause;
        begin
            @(negedge clk); pause_raw = 1'b1;
            repeat (2) @(negedge clk); pause_raw = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); reset = 1'b1;
            repeat (3) @(negedge clk); reset = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    // Back to OFF and straight into a new game, so gameCounter starts at 0.
    task restart_game;
        begin
            stall_armed = 1'b0;
            do_reset;
            stall_armed = 1'b1;
            press_start;
        end
    endtask

    // Bounded wait. Sets wait_failed instead of hanging the sim.
    reg wait_failed = 1'b0;
    integer wcount;

    task wait_for_state;
        input [3:0] target;
        input integer max_cycles;
        begin
            wait_failed = 1'b0;
            wcount = 0;
            while (fsm.state !== target && wcount < max_cycles) begin
                @(negedge clk);
                wcount = wcount + 1;
            end
            if (fsm.state !== target) begin
                wait_failed = 1'b1;
                $display("  (gave up waiting for %0s after %0d cycles -- sitting in %0s)",
                         stateName(target), max_cycles, stateName(fsm.state));
            end
        end
    endtask

    // Time a button so its one-cycle pulse lands while game2 is active.
    // The raw signal has to go high one cycle BEFORE game2 is entered.
    task hit_right_on_game2;
        begin
            wait_for_state(GAME1, 200);
            if (!wait_failed) begin
                right_raw = 1'b1;
                repeat (2) @(negedge clk);   // enter game2 with the pulse live, then branch
                right_raw = 1'b0;
                repeat (1) @(negedge clk);
            end
        end
    endtask

    task hit_left_on_game2;
        begin
            wait_for_state(GAME1, 200);
            if (!wait_failed) begin
                left_raw = 1'b1;
                repeat (2) @(negedge clk);
                left_raw = 1'b0;
                repeat (1) @(negedge clk);
            end
        end
    endtask

    // ---------------- stimulus ----------------
    integer i;

    initial begin
        $dumpfile("tb_gameplay.vcd");
        $dumpvars(0, tb_gameplay);

        $display("");
        $display("=========================================================================");
        $display(" gameplay loop trace     note pattern = %b", NOTE_PATTERN);
        $display("=========================================================================");
        $display("%6s  %-10s | %-18s | %-24s | %-22s | %-9s | %-27s | %s",
                 "cycle", "state", "gameCounter", "noteNum", "sevenSeg0", "score", "loads", "score ops");

        //---------------------------------------------------------- boot
        $display("\n--- [1] reset, then pick a speed so speed_set is not X ---");
        do_reset;
        press_right;                 // OFF -> speed1
        press_right;                 // speed1 -> OFF
        stall_armed = 1'b1;

        //---------------------------------------------------------- launch
        // A whole game is only 24 loop iterations, so each scenario below
        // restarts from OFF to get a fresh gameCounter.
        $display("\n--- [2] press start, then 6 loops with no buttons (all missed) ---");
        press_start;
        repeat (18) @(negedge clk);

        //---------------------------------------------------------- play
        $display("\n--- [3] 6 timed hits, alternating right / left ---");
        for (i = 0; i < 6; i = i + 1) begin
            if (i[0]) hit_left_on_game2;
            else      hit_right_on_game2;
        end

        //---------------------------------------------------------- pause
        $display("\n--- [4] fresh game, then pause / hold / unpause ---");
        restart_game;
        repeat (6) @(negedge clk);
        press_pause;
        stall_armed = 1'b0;          // parking in pauseGame here is intended
        repeat (10) @(negedge clk);
        $display("  held in %0s for 10 cycles, gameCount frozen at %0d",
                 stateName(fsm.state), gc.gameCount);
        stall_armed = 1'b1;
        press_pause;
        repeat (6) @(negedge clk);

        //---------------------------------------------------------- run out
        $display("\n--- [5] fresh game, free-run to finish ---");
        restart_game;
        stall_armed = 1'b0;          // finish parks on purpose; do not report it
        wait_for_state(FINISH, 400);
        if (!wait_failed)
            $display("  reached finish at cycle %0d with gameCount=%0d score=%0d",
                     cycle, gc.gameCount, score_val);
        repeat (5) @(negedge clk);

        //---------------------------------------------------------- exit
        $display("\n--- [6] reset out of finish ---");
        do_reset;
        $display("  final state = %0s", stateName(fsm.state));

        //---------------------------------------------------------- summary
        $display("");
        $display("=========================================================================");
        $display(" cycles simulated : %0d", cycle);
        $display(" stall reports    : %0d", stalls);
        $display(" final gameCount  : %0d", gc.gameCount);
        $display(" final score      : %0d", score_val);
        $display("=========================================================================");
        $display("");
        $finish;
    end

    // hard stop so a real deadlock cannot hang the run
    initial begin
        #200000;
        $display("\n  *** TIMEOUT -- parked in %0s at cycle %0d\n",
                 stateName(fsm.state), cycle);
        $finish;
    end

endmodule