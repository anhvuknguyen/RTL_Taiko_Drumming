`timescale 1ns / 1ps

module noteNum(
    input wire clk,
    input wire NN_select, NN_ld, NN_clr,
    input wire[15:0] switchInput,
    output wire newNote
    );
    
    reg[16:0] noteNum;
    assign newNote = noteNum[0];
    
    always @(posedge clk)begin
        if(NN_ld)begin
            case(NN_select)
                1'b0: noteNum <= noteNum >> 1;
                1'b1: noteNum[16:1] <= switchInput;
            endcase
        end
        else if(NN_clr)begin
            noteNum <= 0;
        end
    end
endmodule
