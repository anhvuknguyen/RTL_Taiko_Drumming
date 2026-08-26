`timescale 1ns / 1ps

module gameCounter(
        input wire clk,
        input wire GC_ld, GC_clr,
        output wire GC_less_than, GC_equal
    );
    
    reg[4:0] gameCount = 0;
    reg GC_lt, GC_eq = 0;
    
    assign GC_less_than = GC_lt;
    assign GC_equal = GC_eq;
    
    always @(posedge clk)begin
        if(GC_ld)begin
            gameCount <= gameCount + 1;
        end
        else if(GC_clr)begin
            gameCount <= 0;
        end
    end
    
    always @(*)begin
        if(gameCount == 24)begin
            GC_eq = 1;
            GC_lt = 0;
        end
        else if(gameCount <24)begin
            GC_eq = 0;
            GC_lt = 1;
        end
        else begin
            GC_eq = 0;
            GC_lt = 0;
        end
    end
    
endmodule
