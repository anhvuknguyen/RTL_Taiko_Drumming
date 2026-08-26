`timescale 1ns / 1ps

module score(
    input wire clk,
    input wire sc_decrement, sc_shift, sc_ld, sc_clr,
    output wire[15:0] score
    );
    
    reg[16:0] p_score; //p_score[16:1] is what is displayed
    assign score = p_score[16:1];
    
    always @(posedge clk)begin
        if(sc_clr)
            p_score <= 0;
        else if(sc_ld)begin
            if(sc_decrement)
                p_score <= p_score - 1;
            else if(sc_shift)
                p_score <= p_score << 1;
            else
                p_score <= p_score + 1;
        end
    end
endmodule
