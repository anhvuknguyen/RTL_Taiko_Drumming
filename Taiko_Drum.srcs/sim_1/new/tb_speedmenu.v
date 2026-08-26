`timescale 1ns / 1ps
//=====================================================================
// tb_speedMenu.v
//
// Self-checking testbench for the speed-menu portion of gameStateMachine:
//   OFF -> speed1 -> speed2 -> speed3 -> speed1 (wrap) -> OFF
//
// Required sources: gameStateMachine.v, rising_edge_detector.v, led.v
//
//   Vivado : add as a simulation source, set as top, Run Simulation
//   Icarus : iverilog -o sim.out -s tb_speedMenu tb_speedMenu.v \
//                     gameStateMachine.v rising_edge_detector.v led.v
//            vvp sim.out
//=====================================================================

module tb_speedMenu;

    // ---------------- DUT connections ----------------
    reg clk   = 1'b0;
    reg reset = 1'b0;
    reg start_raw = 1'b0, pause_raw = 1'b0, right_raw = 1'b0, left_raw = 1'b0;
    reg ss0_b = 1'b0, ss0_c = 1'b0, GC_lt = 1'b0, GC_eq = 1'b0;

    wire gameCounter_ld, gameCounter_clr;
    wire score_ld, score_clr, score_decrement, score_shift;
    wire noteNum_select, noteNum_ld, noteNum_clr;
    wire sseg_ld, sseg_clr, sseg_finish;
    wire led_s0, led_s1;
    wire speed_clr;
    wire [1:0] speed_set;

    wire [15:0] led_bus;          // what the board would actually light up

    // ---------------- bookkeeping ----------------
    integer errors   = 0;
    integer warnings = 0;
    integer checks   = 0;

    // ---------------- state encodings (mirror of the DUT) ----------------
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

    // ---------------- clock ----------------
    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------- DUT ----------------
    gameStateMachine dut (
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
        .speed_clr(speed_clr),
        .speed_set(speed_set)
    );

    // Same connection taiko_main makes, so the LED pattern is checked too.
    led led_dut (
        .speed_led(speed_set),
        .score(16'hBEEF),          // sentinel: should never appear in the menu
        .led_s0(led_s0), .led_s1(led_s1),
        .led(led_bus)
    );

    // ---------------- helpers ----------------
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
                GAME3_SCOREINC: stateName = "game3_scoreInc";
                GAME4_SCOREDEC: stateName = "game4_scoreDec";
                PAUSEGAME:      stateName = "pauseGame";
                FINISH:         stateName = "finish";
                INIT:           stateName = "init";
                default:        stateName = "??";
            endcase
        end
    endfunction

    // Press and release a button. The rising_edge_detector needs the raw
    // signal high across two posedges to emit exactly one pulse.
    task press_right;
        begin
            @(negedge clk); right_raw = 1'b1;
            repeat (2) @(negedge clk);
            right_raw = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task press_left;
        begin
            @(negedge clk); left_raw = 1'b1;
            repeat (2) @(negedge clk);
            left_raw = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task press_start;
        begin
            @(negedge clk); start_raw = 1'b1;
            repeat (2) @(negedge clk);
            start_raw = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); reset = 1'b1;
            repeat (3) @(negedge clk);
            reset = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task check_state;
        input [3:0]      expected;
        input [8*40-1:0] label;
        begin
            checks = checks + 1;
            if (dut.state !== expected) begin
                errors = errors + 1;
                $display("  FAIL  %0s -- state=%0s, expected %0s   (t=%0t)",
                         label, stateName(dut.state), stateName(expected), $time);
            end else begin
                $display("  pass  %0s -- state=%0s", label, stateName(expected));
            end
        end
    endtask

    task check_bus;
        input [15:0]     actual;
        input [15:0]     expected;
        input [8*40-1:0] label;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("  FAIL  %0s -- got %0d (%b), expected %0d   (t=%0t)",
                         label, actual, actual, expected, $time);
            end else begin
                $display("  pass  %0s -- %0d", label, expected);
            end
        end
    endtask

    task warn;
        input [8*80-1:0] msg;
        begin
            warnings = warnings + 1;
            $display("  WARN  %0s", msg);
        end
    endtask

    // Full check of one speed state: FSM state, speed_set, menu LED flags,
    // and the LED bar pattern that led.v produces from them.
    task check_speed_state;
        input [3:0]      st;
        input [1:0]      expected_speed;
        input [15:0]     expected_led;
        input [8*40-1:0] label;
        begin
            check_state(st, label);
            check_bus({14'd0, speed_set}, {14'd0, expected_speed}, "  speed_set");
            check_bus({15'd0, led_s0},    16'd1,                   "  led_s0 asserted");
            check_bus({15'd0, led_s1},    16'd0,                   "  led_s1 deasserted");
            check_bus(led_bus,            expected_led,            "  LED bar");
        end
    endtask

    // ---------------- stimulus ----------------
    integer i;

    initial begin
        $dumpfile("tb_speedMenu.vcd");
        $dumpvars(0, tb_speedMenu);

        $display("\n==================================================");
        $display(" speed menu testbench");
        $display("==================================================");

        //-------------------------------------------------- 1
        $display("\n[1] reset -> OFF");
        do_reset;
        check_state(OFF, "after reset");
        check_bus({15'd0, led_s1}, 16'd1,  "  led_s1 (menu blanked)");
        check_bus(led_bus,         16'd0,  "  LED bar cleared");
        if (speed_set === 2'bxx)
            warn("speed_set is X out of reset -- speed_set_reg is an unreset latch");
        else
            $display("  note  speed_set out of reset = %0d", speed_set);

        //-------------------------------------------------- 2
        $display("\n[2] OFF --right--> speed1");
        press_right;
        check_speed_state(SPEED1, 2'd1, 16'd1, "speed1");

        //-------------------------------------------------- 3
        $display("\n[3] speed1 --left--> speed2");
        press_left;
        check_speed_state(SPEED2, 2'd2, 16'd3, "speed2");

        //-------------------------------------------------- 4
        $display("\n[4] speed2 --left--> speed3");
        press_left;
        check_speed_state(SPEED3, 2'd3, 16'd7, "speed3");

        //-------------------------------------------------- 5
        $display("\n[5] speed3 --left--> speed1 (wrap)");
        press_left;
        check_speed_state(SPEED1, 2'd1, 16'd1, "speed1 after wrap");

        //-------------------------------------------------- 6
        $display("\n[6] two more full laps of the menu");
        for (i = 0; i < 2; i = i + 1) begin
            press_left; check_speed_state(SPEED2, 2'd2, 16'd3, "lap: speed2");
            press_left; check_speed_state(SPEED3, 2'd3, 16'd7, "lap: speed3");
            press_left; check_speed_state(SPEED1, 2'd1, 16'd1, "lap: speed1");
        end

        //-------------------------------------------------- 7
        $display("\n[7] right exits to OFF from every speed state");
        press_right;
        check_state(OFF, "speed1 --right--> OFF");
        press_right; press_left;                 // OFF -> speed1 -> speed2
        check_state(SPEED2, "back in speed2");
        press_right;
        check_state(OFF, "speed2 --right--> OFF");
        press_right; press_left; press_left;     // OFF -> speed1 -> 2 -> 3
        check_state(SPEED3, "back in speed3");
        press_right;
        check_state(OFF, "speed3 --right--> OFF");

        //-------------------------------------------------- 8
        $display("\n[8] speed setting survives the trip back to OFF");
        // We left the menu from speed3, so speed_set should still read 3.
        check_bus({14'd0, speed_set}, {14'd0, 2'd3}, "speed_set retained in OFF");
        check_bus(led_bus, 16'd0, "  LED bar cleared in OFF");

        //-------------------------------------------------- 9
        $display("\n[9] holding right down still gives exactly one transition");
        @(negedge clk); right_raw = 1'b1;
        repeat (20) @(negedge clk);              // hold it for a long time
        check_state(SPEED1, "still speed1 while held");
        right_raw = 1'b0;
        repeat (4) @(negedge clk);
        check_state(SPEED1, "still speed1 after release");

        //-------------------------------------------------- 10
        $display("\n[10] start is ignored inside the menu");
        press_start;
        check_state(SPEED1, "start pressed in speed1");
        press_right;                             // back out to OFF
        check_state(OFF, "right --> OFF");
        // gameStart is a pass-through state, so it has to be sampled on the
        // transition edge rather than after the button is released.
        @(negedge clk); start_raw = 1'b1;
        repeat (2) @(negedge clk);
        check_state(GAMESTART, "start from OFF");
        start_raw = 1'b0;
        repeat (2) @(negedge clk);
        check_state(GAME2, "gameStart auto-advances");

        //-------------------------------------------------- 11
        $display("\n[11] reset from inside the menu");
        do_reset;
        press_right; press_left;                 // OFF -> speed1 -> speed2
        check_state(SPEED2, "in speed2");
        do_reset;
        check_state(OFF, "reset --> OFF");
        check_bus({14'd0, speed_set}, {14'd0, 2'd2},
                  "speed_set after reset (expect stale 2)");

        //-------------------------------------------------- summary
        $display("\n==================================================");
        $display(" checks run : %0d", checks);
        $display(" failures   : %0d", errors);
        $display(" warnings   : %0d", warnings);
        if (errors == 0) $display(" RESULT: PASS");
        else             $display(" RESULT: FAIL");
        $display("==================================================\n");
        $finish;
    end

    // safety net so the sim can never hang
    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end

endmodule