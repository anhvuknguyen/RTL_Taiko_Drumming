`timescale 1ns / 1ps

module sevenSeg(
    input wire clk,
    input wire newNote,
    input wire ss_ld,ss_clr,ss_finish,
    output wire[6:0] sevenSeg3, sevenSeg2, sevenSeg1, sevenSeg0,
    output wire sevenSeg0b, sevenSeg0c
    );
    
    //ss[6:0] = a,b,c,d,e,f,g
    reg[6:0] ss3,ss2,ss1,ss0;
    assign sevenSeg3 = ss3;
    assign sevenSeg2 = ss2;
    assign sevenSeg1 = ss1;
    assign sevenSeg0 = ss0;
    
    assign sevenSeg0b = ss0[5];
    assign sevenSeg0c = ss0[4];
    
    always @(posedge clk)begin
        if(ss_ld)begin
            if(ss_finish) begin
                ss3 <= 7'b1000010;
                ss2 <= 7'b1100010;
                ss1 <= 7'b1101010;
                ss0 <= 7'b0110000;
            end
            else begin
                ss3[1] <= !newNote;
                ss3[2] <= newNote;
                ss3[5] <= ss3[1];
                ss3[4] <= ss3[2];
                
                ss2[1] <= ss3[5];
                ss2[2] <= ss3[4];
                ss2[5] <= ss2[1];
                ss2[4] <= ss2[2];
                
                ss1[1] <= ss2[5];
                ss1[2] <= ss2[4];
                ss1[5] <= ss1[1];
                ss1[4] <= ss1[2];
                
                ss0[1] <= ss1[5];
                ss0[2] <= ss1[4];
                ss0[5] <= ss0[1];
                ss0[4] <= ss0[2];
            end
        end
        else if (ss_clr)begin
            ss3 <= 7'b1111111;
            ss2 <= 7'b1111111;
            ss1 <= 7'b1111111;
            ss0 <= 7'b1111111;
        end
    end
    
endmodule
