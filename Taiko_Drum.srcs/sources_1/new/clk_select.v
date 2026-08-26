`timescale 1ns / 1ps
module clk_select(
    input  wire       clk,
    input  wire       reset,
    input  wire [1:0] select,
    output wire       clk_out
);
    reg [4:0] divInput;

    always @(*) begin
        case (select)
            2'd0:    divInput = 5'd1;
            2'd1:    divInput = 5'd23; //24 or 1
            2'd2:    divInput = 5'd22; //25 or 2
            2'd3:    divInput = 5'd21; //26 or 3
            default: divInput = 5'd23; //24 or 1
        endcase
    end

    clkdiv divided_clk(.clk(clk), .reset(reset), .divInput(divInput), .clk_out(clk_out));
endmodule