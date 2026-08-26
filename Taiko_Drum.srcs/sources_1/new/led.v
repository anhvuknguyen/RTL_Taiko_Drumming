`timescale 1ns / 1ps

module led(
    input wire[1:0] speed_led,
    input wire[15:0] score,
    input wire led_s0, led_s1,
    output wire[15:0] led
    );
    
    reg[15:0] led_reg;
    assign led = led_reg;
    
    always @(*)begin
        if(led_s1)
            led_reg = 0;
        else if(led_s0)
            case(speed_led)
                2'd1:    led_reg=1;
                2'd2:    led_reg=3;
                2'd3:    led_reg=7;
                default: led_reg=1;
            endcase
        else
            led_reg = score;
    end
endmodule
