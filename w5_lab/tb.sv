typedef struct {
  bit [3:0] src;
  bit [3:0] dst;
  bit [7:0] data[];
} rt_packet_t;

interface rt_interface ;
  logic clock;
  logic reset_n;
  logic [15:0]  din;
  logic [15:0]  frame_n;
  logic [15:0]  valid_n;
  logic [15:0]  dout;   
  logic [15:0]  valido_n;
  logic [15:0]  busy_n;
  logic [15:0]  frameo_n ;
endinterface

module rt_stimulator(
  rt_interface intf
);
   typedef enum {IDLE,RESET,ADDR,DATA,PADO} state_t;
   state_t dbg_state;
   byte unsigned dbg_data;
   rt_packet_t pkts[$];
   int src_chnl_status [int];

  function void put_pkts(input rt_packet_t p);
    pkts.push_back(p);
  endfunction

   initial begin : drive_reset_proc
     drive_reset();
   end
   task drive_reset();
     @(negedge intf.reset_n);
     dbg_data<=8'b0;
     dbg_state<=RESET;
     intf.din <= 0;
     intf.frame_n <= '1;
     intf.valid_n <= '1;
   endtask
// end

//drive channle0 - channle15 (din[0:15])data = '{8'h33,8'h77};
   initial begin : drive_chnl0_proc
   //  rt_packet_t pkt;
    @(negedge intf.reset_n);
      repeat(10) @(posedge intf.clock);
      forever begin 
            automatic rt_packet_t p; 
        wait (pkts.size()>0);
        p = pkts.pop_front();
        fork 
          begin
        wait_src_chnl_avail(p);
            drive_chnl(p.src,p.dst,p.data);
            set_src_chnl_avail(p);
          end
      join_none
      end
//drive_chnl(0,3,'{8'h33,8'h77});
//drive_chnl(0,5,'{8'h55,8'h66});
   end

   task automatic wait_src_chnl_avail(rt_packet_t p);
        if (!src_chnl_status.exists(p.src))
          src_chnl_status[p.src] = p.dst;
        else if (src_chnl_status[p.src]>=0)
          wait(src_chnl_status[p.src] == -1);
   endtask

   function automatic set_src_chnl_avail(rt_packet_t p);
     src_chnl_status[p.src] = -1;
   endfunction
 //  initial begin : drive_chnl3_proc
 //   @(negedge reset_n);
 //     repeat(10) @(posedge clock);
 //    drive_chnl(3,6,'{8'h77,8'h88,8'h22});
 //  end

   task automatic drive_chnl(bit [3:0] saddr , bit [3:0] daddr, byte unsigned data[]);
    $display ("@%0t: [DRV] src_chinal[%0d] & dest_chianl[%0d] dtat_trans started",$time,saddr,daddr);
      //drive address phase
      for (int i=0; i<4; i++) begin
        @(posedge intf.clock);

         dbg_state<=ADDR;
         intf.din[saddr]<=daddr[i];
         intf.valid_n[saddr]<=$urandom_range(0,1);
         intf.frame_n[saddr]<=0;
      end
      //drive pad phase
      for (int i=0; i<5; i++) begin
        @(posedge intf.clock);
        
         dbg_state<=PADO;
         intf.din[saddr]<=1;
         intf.valid_n[saddr]<=1;
         intf.frame_n[saddr]<=0;
      end
      //drive data phase
      foreach (data[id]) begin
      for (int i=0; i<8; i++) begin
        @(posedge intf.clock);
          dbg_state<=DATA;
        dbg_data<=data[id];
        intf.din[saddr] <= data[id][i];
        intf.valid_n[saddr] <= 1'b0;
        intf.frame_n[saddr] <= (id == data.size()-1 && i==7)? 1'b1:1'b0;
      end
    end

    @(posedge intf.clock);
    dbg_state<=IDLE;
    dbg_data<=8'b0;
    intf.din[saddr]<=1'b0;
    intf.valid_n[saddr]<=1'b1;
    intf.frame_n[saddr]<=1'b1;
    $display ("@%0t: [DRV] src_chinal[%0d] & dest_chinal[%0d] date trans [%0p] finished ",$time,saddr,daddr,data);
  endtask
endmodule

module rt_generate;
  rt_packet_t pkts[$];

  function void put_pkts(input rt_packet_t p);
    pkts.push_back(p);
  endfunction

  task  get_pkts(output rt_packet_t p);
    wait (pkts.size()>0)
    p= pkts.pop_front();
  endtask 

  //generate packets
  function void gen_pkts();
  endfunction
endmodule 

module rt_monitor(
  rt_interface intf
);
  rt_packet_t in_pkts[16][$];
  rt_packet_t out_pkts[16][$];

  initial begin : mon_chnl_in_proc
    foreach(in_pkts[i]) begin
      automatic int chid = i;
      fork
        mon_chnl_in(chid);
        mon_chnl_out(chid);
      join_none
    end
  end

  task automatic mon_chnl_in(bit[3:0] id);
    rt_packet_t pkt;
    forever begin
      //clear content for the same struct variable
    pkt.data.delete();
    pkt.src = id;
    // monitor specific channl_in data and put it into the queue
    // monitor address phase
    @(negedge intf.frame_n[id]);
    $display ("@%0t: [MON] CH_IN src_chinal[%0d] & dest_chinal[%0d] date_trans_started ",$time,pkt.src,pkt.dst);
    for(int i=0; i<4; i++) begin
      @(negedge intf.clock);
      pkt.dst[i] = intf.din[id];
    end
    //pass pad phase
    repeat(5) @(negedge intf.clock);
    do begin
     pkt.data = new[pkt.data.size + 1] (pkt.data);
      for (int i=0; i<8; i++) begin
        @(negedge intf.clock);
        pkt.data[pkt.data.size-1][i] = intf.din[id];
      end
    end while(!intf.frame_n[id]);
    in_pkts[id].push_back(pkt);
    $display ("@%0t: [MON] CH_IN src_chinal[%0d] & dest_chinal[%0d] date_trans[%0p]finished ",$time,pkt.src,pkt.dst,pkt.data);
  end
  endtask

  task automatic mon_chnl_out(bit[3:0] id);
    rt_packet_t pkt;
    forever begin
      pkt.data.delete();
      pkt.src = 0;
      pkt.dst = id;
      @(negedge intf.frameo_n[id]);
    $display ("@%0t: [MON] CH_OUT  dest_chinal[%0d] date_trans_started ",$time,pkt.dst);
      do begin
       pkt.data = new[pkt.data.size + 1] (pkt.data);
        for (int i=0; i<8; i++) begin
          @(negedge intf.clock iff !intf.valido_n[id] );
          pkt.data[pkt.data.size-1][i] = intf.dout[id];
        end
      end while(!intf.frameo_n[id]);
      out_pkts[id].push_back(pkt);
    $display ("@%0t: [MON] CH_OUT dest_chinal[%0d] date_trans[%0p]finished ",$time,pkt.dst,pkt.data);
    // monitor specific channl_out data and put it into the queue
  end
  endtask
  
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
     .frame_n(intf.frame_n),
     .valid_n(intf.valid_n),
     .din(intf.din),
     .dout(intf.dout),
     .busy_n(intf.busy_n),
     .valido_n(intf.valido_n),
     .frameo_n(intf.frameo_n)
   );

   rt_interface intf();

   assign intf.reset_n = rstn;
   assign intf.clock = clk;
   
   rt_stimulator inst1(intf);

   rt_monitor mon (intf);

   rt_generate gen();

   initial begin : generate_proc
     rt_packet_t p;
     gen.put_pkts('{0,3,'{8'h33,8'h77}});
     gen.put_pkts('{0,5,'{8'h55,8'h66}});
     gen.put_pkts('{3,6,'{8'h77,8'h88,8'h22}});
     gen.put_pkts('{4,7,'{8'haa,8'hcc,8'h33}});
   end

   initial begin : transmit_proc
     rt_packet_t p;
     forever begin
       gen.get_pkts(p);
       inst1.put_pkts(p);
     end
   end
     



   //generate and transmit packet ;

endmodule
