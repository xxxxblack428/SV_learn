module rt_stimulator(
  input clock,
  input reset_n,
  output logic [15:0] din,
  output logic [15:0] frame_n,
  output logic [15:0] valid_n,
  input [15:0]  dout, valido_n, busy_n, frameo_n 
  
);
   typedef enum {IDLE,RESET,ADDR,DATA,PADO} state_t;
   state_t dbg_state;
   byte unsigned dbg_data;
   initial begin : drive_reset_proc
     drive_reset();
   end
   task drive_reset();
    @(negedge reset_n);
    dbg_data<=8'b0;
    dbg_state<=RESET;
    din <= 0;
    frame_n <= '1;
    valid_n <= '1;
   endtask
// end

//drive channle0 - channle15 (din[0:15])data = '{8'h33,8'h77};
   initial begin : drive_chnl0_proc
    @(negedge reset_n);
      repeat(10) @(posedge clock);
     drive_chnl(0,3,'{8'h33,8'h77});
     drive_chnl(0,5,'{8'h55,8'h66});
   end
   initial begin : drive_chnl3_proc
    @(negedge reset_n);
      repeat(10) @(posedge clock);
     drive_chnl(3,6,'{8'h77,8'h88,8'h22});
   end

   task automatic drive_chnl(bit [3:0] saddr , bit [3:0] daddr, byte unsigned data[]);
     $display ("src_chinal[%0d] & dest_chianl[%0d] dtat_trans started",saddr,daddr);
      //drive address phase
      for (int i=0; i<4; i++) begin
        @(posedge clock);

         dbg_state<=ADDR;
         din[saddr]<=daddr[i];
         valid_n[saddr]<=$urandom_range(0,1);
         frame_n[saddr]<=0;
      end
      //drive pad phase
      for (int i=0; i<5; i++) begin
        @(posedge clock);
        
         dbg_state<=PADO;
         din[saddr]<=1;
         valid_n[saddr]<=1;
         frame_n[saddr]<=0;
      end
      //drive data phase
      foreach (data[id]) begin
      for (int i=0; i<8; i++) begin
        @(posedge clock);
          dbg_state<=DATA;
        dbg_data<=data[id];
        din[saddr] <= data[id][i];
        valid_n[saddr] <= 1'b0;
        frame_n[saddr] <= (id == data.size()-1 && i==7)? 1'b1:1'b0;
      end
    end

    @(posedge clock);
    dbg_state<=IDLE;
    dbg_data<=8'b0;
    din[saddr]<=1'b0;
    valid_n[saddr]<=1'b1;
    frame_n[saddr]<=1'b1;
    $display ("src_chinal[%0d] & dest_chinal[%0d] date_trans_finished ",saddr,daddr);
  endtask
 //end
endmodule

module rt_test_top;

endmodule


module tb;

   bit  clk,rstn;
   
   logic [15:0] din, frame_n, valid_n;
   
   logic  [15:0] dout, valido_n, busy_n, frameo_n;
   
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
     .clock  (clk),
     .*
   );
   
   rt_stimulator inst1(
     .clock(clk),
     .reset_n(rstn),
     .*
   );

endmodule
