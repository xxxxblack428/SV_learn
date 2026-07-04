module tb;

bit  clk,rstn;

//generate clk
initial begin
  forever #5ns clk<=!clk;
end
//generate reset
initial begin
  #2ns  rstn <= 1;
  #10ns rstn <= 0;
  #10ns rstn <= 1;
end

router dut(
  .reset_n(rstn),
  .clock  (clk)
);

endmodule
