package btb;

import BRAMCore :: *;

`define BTB_SIZE 256
`define BTB_DATA 35
`define BTB_TAG 22
`define BTB_VAL 12
`define PC_SIZE 32
`define NUM_WAYS 4
`define READ False
`define WRITE True

typedef Bit#(TLog#(`BTB_SIZE)) Gv_btb_addr;
typedef Bit#(`BTB_DATA) Gv_btb_data;
typedef Bit#(`BTB_TAG) Gv_btb_tag;
typedef Bit#(`BTB_VAL) Gv_btb_val;
typedef Bit#(TLog#(`NUM_WAYS)) Gv_ways;
typedef Bit#(`PC_SIZE) Gv_pc;
typedef struct{Bool hit;Gv_ways way_num;Gv_pc branch_pc;} Gv_return deriving(Bits);

//for debugging
String file_way1="way1.dump";
String file_way2="way2.dump";
String file_way3="way3.dump";
String file_way4="way4.dump";
String file_repl="repl.dump";
//

//functions
//compares each tag of respective BTB entry with incoming pc bits
function Bit#(1) fn_compare(Gv_btb_tag x,Gv_btb_tag y);
	return (x==y)?1:0;
endfunction 

//interface
interface Ifc_btb;
	//method to enter pc value into btb
	method Action ma_put(Gv_pc pc);
	//method to get branch target pc from btb & way number & whether hit or miss
	method Gv_return mn_get;
	//method to update the btb
	method Action ma_update(Gv_pc pc,Gv_btb_val branch_imm,Gv_ways way_num);
	//method to flush btb
	method Action ma_flush;
endinterface


//module
//4 way set associative btb
(*synthesize*)
module mkbtb(Ifc_btb);
	BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_data) bram_way1 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way1,True);
	BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_data) bram_way2 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way2,True);
	BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_data) bram_way3 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way3,True);
	BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_data) bram_way4 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way4,True);
	BRAM_DUAL_PORT#(Gv_btb_addr,Gv_ways) bram_replacement <- mkBRAMCore2Load(`BTB_SIZE,False,file_repl,True);

	//outputs from the btb ways and the replacement bits bank
	Wire#(Gv_btb_data) wr_way1_out <- mkWire;
	Wire#(Gv_btb_data) wr_way2_out <- mkWire;
	Wire#(Gv_btb_data) wr_way3_out <- mkWire;
	Wire#(Gv_btb_data) wr_way4_out <- mkWire;
	Wire#(Gv_ways) wr_replacement_bits <- mkWire;	
	//number of the way to be replaced
	Wire#(Gv_ways) wr_way_num <- mkWire;

	//final branch pc in case of hit= sum of value stored in btb & current pc
	Wire#(Gv_pc) wr_branch_pc <- mkWire;
	//tells if there is a hit
	Wire#(Bool) wr_hit <- mkWire;

	//local copy of pc for use in rules
	Wire#(Gv_pc) rg_pc_copy <- mkReg(0);
	//control flushing operation
	Wire#(Bool) rg_flush <- mkReg(False);
	//address while flushing
	Wire#(Bit#(TAdd#(TLog#(`BTB_SIZE),1))) rg_flush_addr <- mkReg(0);
		
	//reads bram outputs onto wires; 
	rule rl_read_ways;
		wr_way1_out<= bram_way1.a.read();
		wr_way2_out<= bram_way2.a.read();
		wr_way3_out<= bram_way3.a.read();
		wr_way4_out<= bram_way4.a.read();
		wr_replacement_bits<= bram_replacement.a.read();
	endrule

	//reads outputs from brams;compares tag of each way with upper 22 pc bits and puts branch target pc onto wr_branch_pc
	rule rl_compare;
		Gv_btb_data lv_way1_out= wr_way1_out;
		Gv_btb_data lv_way2_out= wr_way2_out;
		Gv_btb_data lv_way3_out= wr_way3_out;
		Gv_btb_data lv_way4_out= wr_way4_out;

		Bit#(20) lv_gnd=0;

		Bit#(1) lv_compare1= fn_compare(lv_way1_out[34:13],rg_pc_copy[31:10]);
		Bit#(1) lv_compare2= fn_compare(lv_way2_out[34:13],rg_pc_copy[31:10]);
		Bit#(1) lv_compare3= fn_compare(lv_way3_out[34:13],rg_pc_copy[31:10]);
		Bit#(1) lv_compare4= fn_compare(lv_way4_out[34:13],rg_pc_copy[31:10]);

		Bool lv_valid1= unpack(lv_way1_out[0]);
		Bool lv_valid2= unpack(lv_way2_out[0]);
		Bool lv_valid3= unpack(lv_way3_out[0]);
		Bool lv_valid4= unpack(lv_way4_out[0]);

		Gv_ways lv_replacement= bram_replacement.a.read();

		case({lv_compare1,lv_compare2,lv_compare3,lv_compare4})

		4'b1000:
		begin
			if(lv_valid1)
			begin
				wr_branch_pc<= {lv_gnd,lv_way1_out[12:1]}+rg_pc_copy;
				wr_hit<= True;
				wr_way_num<= ?;
			end
			
			else
			begin
				wr_branch_pc<= ?;
				wr_hit<= False;
				wr_way_num<= 2'b00;
			end
		end
		
		4'b0100:
		begin
			if(lv_valid2)
			begin
				wr_branch_pc<= {lv_gnd,lv_way2_out[12:1]}+rg_pc_copy;
				wr_hit<= True;
				wr_way_num<= ?;
			end
			
			else
			begin
				wr_branch_pc<= ?;
				wr_hit<= False;
				wr_way_num<= 2'b01;
			end
		end
			
		4'b0010:
		begin
			if(lv_valid3)
			begin
				wr_branch_pc<= {lv_gnd,lv_way3_out[12:1]}+rg_pc_copy;
				wr_hit<= True;
				wr_way_num<= ?;
			end
		
			else
			begin
				wr_branch_pc<= ?;
				wr_hit<= False;
				wr_way_num<= 2'b10;
			end
		end
		
		4'b0001:
		begin
			if(lv_valid4)
			begin
				wr_branch_pc<= {lv_gnd,lv_way4_out[12:1]}+rg_pc_copy;
				wr_hit<= True;
				wr_way_num<= ?;
			end

			else
			begin
				wr_branch_pc<= ?;
				wr_hit<= False;
				wr_way_num<= 2'b11;
			end
		end

		4'b0000:
		begin
			wr_branch_pc<= ?;
			wr_hit<= False;
			wr_way_num<= lv_replacement;
		end
		endcase

	endrule
			
	//rule to flush btb
	rule rl_flush(rg_flush);
		Gv_btb_data lv_btb_flush=0;
		Gv_ways lv_replacement_flush=0;

		if(rg_flush_addr[8]==0)
		begin
			bram_way1.b.put(`WRITE,rg_flush_addr[7:0],lv_btb_flush);
			bram_way2.b.put(`WRITE,rg_flush_addr[7:0],lv_btb_flush);
			bram_way3.b.put(`WRITE,rg_flush_addr[7:0],lv_btb_flush);
			bram_way4.b.put(`WRITE,rg_flush_addr[7:0],lv_btb_flush);
			bram_replacement.b.put(`WRITE,rg_flush_addr[7:0],lv_replacement_flush);
			rg_flush_addr<= rg_flush_addr+1;
		end

		else
			rg_flush<=False;
	endrule

	//issues read requests to all ways using bits 9 to 2 of pc as index
	method Action ma_put(Gv_pc pc);
		bram_way1.a.put(`READ,pc[9:2],?);
		bram_way2.a.put(`READ,pc[9:2],?);
		bram_way3.a.put(`READ,pc[9:2],?);
		bram_way4.a.put(`READ,pc[9:2],?);
		bram_replacement.a.put(`READ,pc[9:2],?);
		rg_pc_copy<= pc;
	endmethod

	//returns branch target pc,the way to be replaced
	method Gv_return mn_get;
		Gv_return return_vals;
		return_vals.hit= wr_hit;
		return_vals.way_num= wr_way_num;
		return_vals.branch_pc= wr_branch_pc;
		return return_vals;
	endmethod

	//updates in case of miss
	method Action ma_update(Gv_pc pc,Gv_btb_val branch_imm,Gv_ways way_num) if (!rg_flush);
		case(way_num)
		//way1
		2'b00:
		begin
			bram_way1.b.put(`WRITE,pc[9:2],{pc[31:10],branch_imm,1'b1});
			bram_replacement.b.put(`WRITE,pc[9:2],way_num+1);
		end
		//way2
		2'b01:
		begin
			bram_way2.b.put(`WRITE,pc[9:2],{pc[31:10],branch_imm,1'b1});
			bram_replacement.b.put(`WRITE,pc[9:2],way_num+1);
		end
		//way3
		2'b10:
		begin
			bram_way3.b.put(`WRITE,pc[9:2],{pc[31:10],branch_imm,1'b1});
			bram_replacement.b.put(`WRITE,pc[9:2],way_num+1);
		end
		//way4
		2'b11:
		begin
			bram_way4.b.put(`WRITE,pc[9:2],{pc[31:10],branch_imm,1'b1});
			bram_replacement.b.put(`WRITE,pc[9:2],way_num+1);
		end
		endcase
	endmethod

	//method to flush the btb
	method Action ma_flush if(!rg_flush);
		rg_flush<= True;
		rg_flush_addr<= 0;
	endmethod	

endmodule
endpackage
