package Testbench;

import btb :: *;
import Utils :: *;
import BRAMCore :: *;

`define READ False

//Dhrystone traces
String gv_file1="branch_pc.dump";
String gv_file2="branch_taken.dump";
String gv_file3="branch_imm.dump";

(*synthesize*)
module mkTestbench(Empty);
	Ifc_btb btb <- mkbtb;
	BRAM_PORT#(Bit#(16),Bit#(40)) bram_pc <- mkBRAMCore1Load(64000,False,gv_file1,False);
	BRAM_PORT#(Bit#(16),Bit#(32)) bram_taken <- mkBRAMCore1Load(64000,False,gv_file2,True);
	BRAM_PORT#(Bit#(16),Bit#(64)) bram_imm <- mkBRAMCore1Load(64000,False,gv_file3,False);
	//state of the FSM
	Reg#(Bit#(3)) rg_state	<- mkReg(0);
	//count of the total number of taken branches
	Reg#(Bit#(16)) rg_total <- mkReg(0);
	//count of the total number of btb misses when the branch is taken
	Reg#(Bit#(16)) rg_miss_count <- mkReg(0);
	//copy of incoming Dhrystone data for updating btb etc
	Reg#(Bit#(40)) rg_pc <- mkReg(0);
	Reg#(Bit#(64)) rg_imm <- mkReg(0);
	Reg#(Bit#(32)) rg_taken <- mkReg(0);
	//to wait until flush is over
	Reg#(Bit#(16)) rg_wait <- mkReg(0);
	//tells if there was hit in btb
	Reg#(Bool) rg_hit <- mkReg(False);
	
	Reg#(Gv_ways) rg_way_num <- mkReg(0);
	
	//addr to control reading of files
	Reg#(Bit#(16)) rg_pc_addr <- mkReg(0);
	Reg#(Bit#(16)) rg_taken_addr <- mkReg(0);
	Reg#(Bit#(16)) rg_imm_addr <- mkReg(0);

	Wire#(Bit#(40)) wr_pc <- mkWire;
	Wire#(Bit#(32)) wr_taken <- mkWire;
	Wire#(Bit#(64)) wr_imm <- mkWire;
	Wire#(Gv_return_btb) wr_get <- mkWire;

	
	//initiate flush
	rule rl_flush(rg_state==0);
		btb.ma_flush();
		rg_state<=1;
	endrule
	
	//wait for flush to end
	rule rl_wait(rg_state==1);
		rg_wait<=rg_wait+1;
		if(rg_wait==256)
			rg_state<=2;
	endrule

	//fetch next pc from branch_pc and next taken value
	rule rl_fetch(rg_state==2);
		//$display("2");
		bram_pc.put(`READ,rg_pc_addr,?);
		bram_taken.put(`READ,rg_taken_addr,?);
		rg_pc_addr<= rg_pc_addr+1;
		rg_taken_addr<= rg_taken_addr+1;
		rg_state<=3;
	endrule
	
	//read brams onto wires
	rule rl_read(rg_state==3);
		wr_pc<= bram_pc.read();
		wr_taken<= bram_taken.read();
	endrule
		
	//decide if branch is taken or not
	rule rl_decide(rg_state==3);
		//$display("3");
		if(wr_taken[0]==1)
		begin
			btb.ma_put(wr_pc[31:0]);
			rg_total<= rg_total+1;
			rg_pc<= wr_pc;
			rg_taken<= wr_taken;
			rg_state<= 4;
		end
		else
			rg_state<= 2;
		
	endrule

	//get data from btb
	rule rl_get(rg_state==4);
		wr_get<= btb.mn_get();
	endrule

	//check if there was a hit; if not gotta update btb and increment miss counter
	rule rl_check_hit(rg_state==4);
		//$display("4");	
		Gv_return_btb lv_get= btb.mn_get();
		rg_way_num<= wr_get.way_num;
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
	endrule

	//read imm value 
	rule rl_read_imm(rg_state==5);
		wr_imm<= bram_imm.read();
		//$display("Here");
	endrule	

	//update btb
	rule rl_update(rg_state==5);
		//$display("5");
		Gv_update_btb lv_update;
		lv_update.pc=rg_pc[31:0];
		lv_update.branch_imm=wr_imm[11:0];
		lv_update.way_num=rg_way_num;
		
		btb.ma_update(lv_update);
		rg_state<= 2;
	endrule

	//stop simulation
	rule rl_end(rg_total==100);
		$display("%0d:%0d",rg_total,rg_miss_count);
		$finish;
	endrule

endmodule	
endpackage
