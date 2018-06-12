package Testbench;

import btb :: *;
//import Utils :: *;

(*synthesize*)
module mkTestbench(Empty);
	Ifc_btb btb <- mkbtb;
	Reg#(Bit#(2)) rg_state	<- mkReg(0);
	Reg#(Gv_ways) rg_way_num <- mkReg(0);
	Reg#(Bit#(3)) rg_count <- mkReg(0);

	rule rl_input(rg_state==0);
		Gv_pc pc=65536;
		btb.ma_put(pc);
		rg_state<=1;
	endrule
	
	rule rl_output(rg_state==1);
		Gv_return lv_val= btb.mn_get();
		rg_way_num<= lv_val.way_num;
		rg_state<=2;
		//rg_count<= rg_count+1;
	endrule

	rule rl_update(rg_state==2);
		Gv_pc pc=65536;
		Gv_btb_val val=0;
		btb.ma_update(pc,val,rg_way_num);
		rg_state<= 0;
		rg_count<= rg_count+1;
	endrule
		
	rule rl_end(rg_count==4);
		$finish;
	endrule

endmodule	
endpackage
