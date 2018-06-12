package Testbench;

import btb :: *;
import Utils :: *;
import BRAMCore :: *;

`define READ False

String gv_file1="branch_pc.dump";
String gv_file2="branch_taken.dump";
String gv_file3="branch_imm.dump";

(*synthesize*)
module mkTestbench(Empty);
	Ifc_btb btb <- mkbtb;
	BRAM_PORT#(Bit#(16),Bit#(40)) bram_pc <- mkBRAMCore1Load(64000,False,gv_file1,False);
	BRAM_PORT#(Bit#(16),Bit#(32)) bram_taken <- mkBRAMCore1Load(64000,False,gv_file2,True);
	BRAM_PORT#(Bit#(16),Bit#(64)) bram_imm <- mkBRAMCore1Load(64000,False,gv_file3,False);
	Reg#(Bit#(3)) rg_state	<- mkReg(0);
	Reg#(Gv_ways) rg_way_num <- mkReg(0);
	Reg#(Bit#(3)) rg_count <- mkReg(0);
	Reg#(Bit#(16)) rg_total <- mkReg(0);
	Reg#(Bit#(16)) rg_miss_count <- mkReg(0);
	Reg#(Bit#(40)) rg_pc <- mkReg(0);
	Reg#(Bit#(64)) rg_imm <- mkReg(0);
	Reg#(Bit#(32)) rg_taken <- mkReg(0);
	Reg#(Bit#(16)) rg_wait <- mkReg(0);
	Reg#(Bool) rg_hit <- mkReg(False);
	
	Reg#(Bit#(16)) rg_pc_addr <- mkReg(0);
	Reg#(Bit#(16)) rg_taken_addr <- mkReg(0);
	Reg#(Bit#(16)) rg_imm_addr <- mkReg(0);

	Wire#(Bit#(40)) wr_pc <- mkWire;
	Wire#(Bit#(32)) wr_taken <- mkWire;
	Wire#(Bit#(64)) wr_imm <- mkWire;
	Wire#(Gv_return) wr_get <- mkWire;

	rule rl_flush(rg_state==0);
		btb.ma_flush();
		rg_state<=1;
	endrule
	
	rule rl_wait(rg_state==1);
		rg_wait<=rg_wait+1;
		if(rg_wait==300)
			rg_state<=2;
	endrule

	rule rl_fetch(rg_state==2);
		//$display("2");
		bram_pc.put(`READ,rg_pc_addr,?);
		bram_taken.put(`READ,rg_taken_addr,?);
		rg_pc_addr<= rg_pc_addr+1;
		rg_taken_addr<= rg_taken_addr+1;
		rg_state<=3;
	endrule
	
	rule rl_read(rg_state==3);
		wr_pc<= bram_pc.read();
		wr_taken<= bram_taken.read();
	endrule
		
	rule rl_decide(rg_state==3);
		//$display("3");
		if(wr_taken[0]==1)
		begin
			btb.ma_put(wr_pc[31:0]);
			rg_total<= rg_total+1;
			rg_pc<= wr_pc;
		end
		rg_taken<= wr_taken;
		rg_state<= 4;
	endrule

	rule rl_get(rg_state==4);
		wr_get<= btb.mn_get();
	endrule

	rule rl_check_hit(rg_state==4);
		//$display("4");	
		//Gv_return lv_get= btb.mn_get();
		rg_way_num<= wr_get.way_num;
		if(rg_taken[0]==1)
		begin
			//$display("In");
			if(!wr_get.hit)
			begin
				//$display("Miss");
				bram_imm.put(`READ,rg_imm_addr,?);
				rg_imm_addr<= rg_imm_addr+1;
				rg_state<= 5;
				rg_miss_count<= rg_miss_count+1;
			end
			else
				rg_state<= 2;
	
		end
		else
			rg_state<= 2;
	endrule

	rule rl_read_imm(rg_state==5);
		wr_imm<= bram_imm.read();
		//$display("Here");
	endrule	

	rule rl_update(rg_state==5);
		//$display("5");
		//Bit#(64) lv_imm= wr_imm;
		btb.ma_update(rg_pc[31:0],wr_imm[11:0],rg_way_num);
		rg_state<= 2;
	endrule


	rule rl_end(rg_total==30);
		$display("%0d:%0d",rg_total,rg_miss_count);
		$finish;
	endrule

endmodule	
endpackage
