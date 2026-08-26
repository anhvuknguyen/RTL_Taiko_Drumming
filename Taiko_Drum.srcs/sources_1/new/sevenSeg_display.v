`timescale 1ns / 1ps

module sevenSeg_display(
    input wire clk,
    input wire[6:0] ss3,ss2,ss1,ss0,
    output wire[3:0] anode,
    output wire[6:0] sevenSeg
    );
    
    reg[3:0] an;
    assign anode = an;
    reg[6:0] ss_out;
    assign sevenSeg = ss_out;
    
    reg [1:0] state = 2'b00, next_state;

    // State transition.
    always @(*) begin
        case (state)
            2'b00: next_state = 2'b01;
            2'b01: next_state = 2'b10;
            2'b10: next_state = 2'b11;
            2'b11: next_state = 2'b00;
    
            default: next_state = 2'b00;
        endcase
    end
    
    // Output multiplexer (segments).
    always @(*) begin
        case (state)
            2'b00: ss_out = ss0;
            2'b01: ss_out = ss1;
            2'b10: ss_out = ss2;
            2'b11: ss_out = ss3;
    
            default: ss_out = 7'b1111111; // all segments off (active-low)
        endcase
    end
    
    // Output decoder (active-low anodes).
    always @(*) begin
        case (state)
            2'b00: an = 4'b1110;
            2'b01: an = 4'b1101;
            2'b10: an = 4'b1011;
            2'b11: an = 4'b0111;
    
            default: an = 4'b1111;
        endcase
    end
    
    // State register with async reset.
    always @(posedge clk) begin
        state <= next_state;
    end
    
endmodule
