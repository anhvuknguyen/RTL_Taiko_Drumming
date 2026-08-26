module rising_edge_detector(
    input  wire clk,
    input  wire reset,
    input  wire signal,
    output wire outedge
);
    reg s0, s1;
    always @(posedge clk) begin
        if (reset) begin
            s0 <= 1'b0;
            s1 <= 1'b0;
        end else begin
            s0 <= signal;   // sync/sample the button
            s1 <= s0;       // delay one more cycle
        end
    end
    assign outedge = s0 & ~s1;   // high for exactly one clk when signal goes 0->1
endmodule