package btb;

import BRAMCore :: *;
import Vector :: *;
//import defined_types :: *;

`define BTB_SIZE 256
`define BTB_ADDR 8
`define BTB_DATA 35
`define BTB_TAG 22
`define BTB_VAL 12
`define PC_SIZE 32
`define NUM_WAYS 4
`define VRG_DEPTH 17
`define READ False
`define WRITE True

typedef Bit#(TLog#(`BTB_SIZE)) Gv_btb_addr;
typedef Bit#(`BTB_DATA) Gv_btb_data;
typedef Bit#(`BTB_TAG) Gv_btb_tag;
typedef Bit#(`BTB_VAL) Gv_btb_val;
typedef Bit#(`PC_SIZE) Gv_pc;
typedef Bit#(TLog#(`NUM_WAYS)) Gv_ways;

//structure for the value returned by the mn_get method
typedef struct{Bool hit_bram;Bool hit_vrg;Gv_ways way_num;Gv_pc branch_pc;} Gv_return_btb deriving(Bits, Eq, FShow);
//structure for the value used to update btb in case of miss
typedef struct{Bool conditional;Gv_pc pc;Gv_pc branch_imm;Gv_ways way_num;} Gv_update_btb deriving(Bits, Eq, FShow);
//structure for reg vector data
typedef struct{Gv_pc pc;Gv_pc branch_pc;} Gv_vrg_data deriving(Bits, Eq, FShow);
//structure for each btb entry
typedef struct{Gv_btb_tag tag;Gv_btb_val val;Bit#(1) valid;} Gv_btb_entry deriving(Bits);

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
	method Gv_return_btb mn_get;
	//method to update the btb
	method Action ma_update(Gv_update_btb update_val);
	//method to flush btb
	method Action ma_flush;
endinterface


//module
//4 way set associative btb
(*synthesize*)
module mkbtb(Ifc_btb);
	BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_entry) bram_way[`NUM_WAYS+1];	
	for(Integer i=1; i<=`NUM_WAYS;i=i+1)
		bram_way[i] <- mkBRAMCore2Load(`BTB_SIZE,False,file_way1,True);
	//BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_entry) bram_way1 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way1,True);
	//BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_entry) bram_way2 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way2,True);
	//BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_entry) bram_way3 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way3,True);
	//BRAM_DUAL_PORT#(Gv_btb_addr,Gv_btb_entry) bram_way4 <- mkBRAMCore2Load(`BTB_SIZE,False,file_way4,True);
	BRAM_DUAL_PORT#(Gv_btb_addr,Gv_ways) bram_replacement <- mkBRAMCore2Load(`BTB_SIZE,False,file_repl,True);

	//Reg Vector for unconditional branches
	Vector#(`VRG_DEPTH,Reg#(Gv_vrg_data)) vrg_uncond <- replicateM(mkRegU);		
	//Counter for round robin replacement in vreg
	Reg#(Bit#(TLog#(`VRG_DEPTH))) rg_rr_counter <- mkReg(0);

	
	//number of the way to be replaced
	Wire#(Gv_ways) wr_way_num <- mkWire;

	//final branch pc in case of hit= imm value in case of conditional branch and full pc in case of unconditional
	Wire#(Gv_pc) wr_branch_pc <- mkWire;
	//tells if there is a hit in brams
	Wire#(Bool) wr_hit_bram <- mkWire;
	//tells if there is a hit in reg vector
	Wire#(Bool) wr_hit_vrg <- mkWire;

	//local copy of pc for use in rules
	Wire#(Gv_pc) rg_pc_copy <- mkReg(0);
	//control flushing operation
	Wire#(Bool) rg_flush <- mkReg(False);
	//address while flushing
	Wire#(Bit#(TAdd#(TLog#(`BTB_SIZE),1))) rg_flush_addr <- mkReg(0);
		
	//reads outputs from brams;compares tag of each way with upper 22 pc bits and puts branch target pc onto wr_branch_pc if there is a hit in bram; if there is a hit in vrg, read from there
	rule rl_compare;
		Gv_pc branch_pc_bram=0;
		Gv_pc branch_pc_vrg=0;
		Bool hit_bram=False;
		Bool hit_vrg=False;
		
		case(`NUM_WAYS)
		//4 ways
		4:
		begin
			Gv_btb_entry lv_way1_out= bram_way[1].a.read();
			Gv_btb_entry lv_way2_out= bram_way[2].a.read();
			Gv_btb_entry lv_way3_out= bram_way[3].a.read();
			Gv_btb_entry lv_way4_out= bram_way[4].a.read();

			//Bit#(20) lv_gnd=0;

			Bit#(1) lv_compare1= fn_compare(lv_way1_out.tag,rg_pc_copy[`PC_SIZE-1:`PC_SIZE-`BTB_TAG]);
			Bit#(1) lv_compare2= fn_compare(lv_way2_out.tag,rg_pc_copy[`PC_SIZE-1:`PC_SIZE-`BTB_TAG]);
			Bit#(1) lv_compare3= fn_compare(lv_way3_out.tag,rg_pc_copy[`PC_SIZE-1:`PC_SIZE-`BTB_TAG]);
			Bit#(1) lv_compare4= fn_compare(lv_way4_out.tag,rg_pc_copy[`PC_SIZE-1:`PC_SIZE-`BTB_TAG]);

			Bool lv_valid1= unpack(lv_way1_out.valid);
			Bool lv_valid2= unpack(lv_way2_out.valid);
			Bool lv_valid3= unpack(lv_way3_out.valid);
			Bool lv_valid4= unpack(lv_way4_out.valid);

			Gv_ways lv_replacement= bram_replacement.a.read();

			case({lv_compare1,lv_compare2,lv_compare3,lv_compare4})

			4'b1000:
			begin
				if(lv_valid1)
				begin
					branch_pc_bram= signExtend(lv_way1_out.val);
					hit_bram= True;
					wr_way_num<= ?;
				end
			
				else
				begin
					hit_bram= False;
					wr_way_num<= 0;
				end
			end
		
			4'b0100:
			begin
				if(lv_valid2)
				begin
					branch_pc_bram= signExtend(lv_way2_out.val);
					hit_bram= True;
					wr_way_num<= ?;
				end
			
				else
				begin
					hit_bram= False;
					wr_way_num<= 1;
				end
			end
			
			4'b0010:
			begin
				if(lv_valid3)
				begin
					branch_pc_bram= signExtend(lv_way3_out.val);
					hit_bram= True;
					wr_way_num<= ?;
				end
		
				else
				begin
					hit_bram= False;
					wr_way_num<= 2;
				end
			end
		
			4'b0001:
			begin
				if(lv_valid4)
				begin
					branch_pc_bram= signExtend(lv_way4_out.val);
					hit_bram= True;
					wr_way_num<= ?;
				end

				else
				begin
					hit_bram= False;
					wr_way_num<= 3;
				end
			end

			4'b0000:
			begin
				branch_pc_bram= ?;
				hit_bram= False;
				wr_way_num<= lv_replacement;
			
			end
			endcase
		end
		//2 ways
		2:
		begin
			Gv_btb_entry lv_way1_out= bram_way[1].a.read();
			Gv_btb_entry lv_way2_out= bram_way[2].a.read();

			Bit#(1) lv_compare1= fn_compare(lv_way1_out.tag,rg_pc_copy[`PC_SIZE-1:`PC_SIZE-`BTB_TAG]);
			Bit#(1) lv_compare2= fn_compare(lv_way2_out.tag,rg_pc_copy[`PC_SIZE-1:`PC_SIZE-`BTB_TAG]);

			Bool lv_valid1= unpack(lv_way1_out.valid);
			Bool lv_valid2= unpack(lv_way2_out.valid);

			Gv_ways lv_replacement= bram_replacement.a.read();
			
			case({lv_compare1,lv_compare2})
			
			2'b10:
			begin
				if(lv_valid1)
				begin
					branch_pc_bram= signExtend(lv_way1_out.val);
					hit_bram= True;
					wr_way_num<= ?;
				end
			
				else
				begin
					hit_bram= False;
					wr_way_num<= 0;
				end
			end

			2'b01:
			begin
				if(lv_valid2)
				begin
					branch_pc_bram= signExtend(lv_way2_out.val);
					hit_bram= True;
					wr_way_num<= ?;
				end
			
				else
				begin
					hit_bram= False;
					wr_way_num<= 1;
				end
			end
			
			2'b00:
			begin
				branch_pc_bram= ?;
				hit_bram= False;
				wr_way_num<= lv_replacement;
			
			end
			endcase
		end
		endcase

		//check all entries in reg vector
		for(Integer i=0; i<`VRG_DEPTH; i=i+1)
		begin
			let vrg_entry= vrg_uncond[i];
			if(vrg_entry.pc==rg_pc_copy)
			begin
				branch_pc_vrg= vrg_entry.branch_pc;
				hit_vrg= True;
			end
		end	
			
		//hit in vrg; unconditional branch
		if(hit_vrg)
		begin
			wr_branch_pc<= branch_pc_vrg;
			wr_hit_vrg<= True;
			wr_hit_bram<= False;
		end

		//miss in vrg
		else
		begin
			//let branch_imm= branch_pc_bram[`BTB_VAL-1:0];
			wr_branch_pc<= rg_pc_copy+signExtend(branch_pc_bram[11:0]);
			if(hit_bram)
				wr_hit_bram<= True;
			else
				wr_hit_bram<= False;
			wr_hit_vrg<= False;
		end

	endrule

		
	//rule to flush btb
	rule rl_flush(rg_flush);
		Gv_btb_entry lv_btb_flush= Gv_btb_entry{tag:0,
						        val:0,
							valid:0};
		Gv_vrg_data lv_vrg_flush= Gv_vrg_data{pc:0,
						      branch_pc:0};
		Gv_ways lv_replacement_flush=0;

		if(rg_flush_addr[`BTB_ADDR]==0)
		begin
			if(`NUM_WAYS==4)
			begin
				bram_way[1].b.put(`WRITE,rg_flush_addr[`BTB_ADDR-1:0],lv_btb_flush);
				bram_way[2].b.put(`WRITE,rg_flush_addr[`BTB_ADDR-1:0],lv_btb_flush);
				bram_way[3].b.put(`WRITE,rg_flush_addr[`BTB_ADDR-1:0],lv_btb_flush);
				bram_way[4].b.put(`WRITE,rg_flush_addr[`BTB_ADDR-1:0],lv_btb_flush);
			end

			else
			begin
				if(`NUM_WAYS==2)
				begin
					bram_way[1].b.put(`WRITE,rg_flush_addr[`BTB_ADDR-1:0],lv_btb_flush);
					bram_way[2].b.put(`WRITE,rg_flush_addr[`BTB_ADDR-1:0],lv_btb_flush);
				end
			end
				
			bram_replacement.b.put(`WRITE,rg_flush_addr[`BTB_ADDR-1:0],lv_replacement_flush);
			rg_flush_addr<= rg_flush_addr+1;
		end

		else
			rg_flush<=False;
		
		for(Integer i=0; i<`VRG_DEPTH; i=i+1)
		begin
			vrg_uncond[i]<= lv_vrg_flush;
		end
		
	endrule

	//issues read requests to all ways using bits 9 to 2 of pc as index
	method Action ma_put(Gv_pc pc);
		if(`NUM_WAYS==4)
		begin
			bram_way[1].a.put(`READ,pc[`BTB_ADDR+1:2],?);
			bram_way[2].a.put(`READ,pc[`BTB_ADDR+1:2],?);
			bram_way[3].a.put(`READ,pc[`BTB_ADDR+1:2],?);
			bram_way[4].a.put(`READ,pc[`BTB_ADDR+1:2],?);
		end
		
		else
		begin
			if(`NUM_WAYS==2)
			begin
				bram_way[1].a.put(`READ,pc[`BTB_ADDR+1:2],?);
				bram_way[2].a.put(`READ,pc[`BTB_ADDR+1:2],?);
			end
		end

		bram_replacement.a.put(`READ,pc[`BTB_ADDR+1:2],?);
		rg_pc_copy<= pc;
	endmethod

	//returns branch target pc,the way to be replaced
	method Gv_return_btb mn_get;
		Gv_return_btb return_vals;
		return_vals.hit_bram= wr_hit_bram;
		return_vals.hit_vrg= wr_hit_vrg;
		return_vals.way_num= wr_way_num;
		return_vals.branch_pc= wr_branch_pc;
		return return_vals;
	endmethod

	//updates in case of miss
	method Action ma_update(Gv_update_btb update_val) if (!rg_flush);
		let way_num=update_val.way_num;
		let branch_imm=update_val.branch_imm;
		let pc=update_val.pc;
		let cond=update_val.conditional;
		Gv_btb_entry btb_entry= Gv_btb_entry{tag:pc[`PC_SIZE-1:`PC_SIZE-`BTB_TAG],
						     val:branch_imm[`BTB_VAL-1:0],
						     valid:1};
		Gv_vrg_data vrg_entry= Gv_vrg_data{pc:pc,
						   branch_pc:branch_imm};
		if(cond)
		begin
			case(`NUM_WAYS)	
			//4 ways
			4:
			begin
				case(way_num)
				//way1
				0:
				begin
					bram_way[1].b.put(`WRITE,pc[`BTB_ADDR+1:2],btb_entry);
					bram_replacement.b.put(`WRITE,pc[`BTB_ADDR+1:2],way_num+1);
				end
				//way2
				1:
				begin
					bram_way[2].b.put(`WRITE,pc[`BTB_ADDR+1:2],btb_entry);
					bram_replacement.b.put(`WRITE,pc[`BTB_ADDR+1:2],way_num+1);
				end
				//way3
				2:
				begin
					bram_way[3].b.put(`WRITE,pc[`BTB_ADDR+1:2],btb_entry);
					bram_replacement.b.put(`WRITE,pc[`BTB_ADDR+1:2],way_num+1);
				end
				//way4
				3:
				begin
					bram_way[4].b.put(`WRITE,pc[`BTB_ADDR+1:2],btb_entry);
					bram_replacement.b.put(`WRITE,pc[`BTB_ADDR+1:2],way_num+1);
				end
				endcase
			end
			//2 ways
			2:
			begin
				case(way_num)
				//way1
				0:
				begin
					bram_way[1].b.put(`WRITE,pc[`BTB_ADDR+1:2],btb_entry);
					bram_replacement.b.put(`WRITE,pc[`BTB_ADDR+1:2],way_num+1);
				end
				//way2
				1:
				begin
					bram_way[2].b.put(`WRITE,pc[`BTB_ADDR+1:2],btb_entry);
					bram_replacement.b.put(`WRITE,pc[`BTB_ADDR+1:2],way_num+1);
				end
				endcase
			end
			endcase
		end	
		
		else
		begin
			vrg_uncond[rg_rr_counter]<= vrg_entry;
			if(rg_rr_counter==`VRG_DEPTH-1)
				rg_rr_counter<= 0;
			else
				rg_rr_counter<= rg_rr_counter+1;
		end
		
	endmethod

	//method to flush the btb
	method Action ma_flush if(!rg_flush);
		rg_flush<= True;
		rg_flush_addr<= 0;
	endmethod	

endmodule
endpackage
