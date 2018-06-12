# BTB
Branch Target Buffer in Bluespec

Author:Ram Srivathsa Sankar

Mentor:Rahul Bodduna

The 'btb' folder contains the .bsv file for the BTB. It is a 4 way set associative cache with each way having 256 entries for now(subject to change after further analysis). Round robin algorithm is followed for entry replacement. The 'Testbench' folder contains the .bsv file for the testbench, the .dump files for testing the Dhrystone benchmark and the .dump files for initializing the ways.

The 'verilog' folder contains the .v files for the project while the 'vivado' folder contains the vivado project file as well as the syn_area.txt and syn_timing.txt files that provide the utilization and timing reports respectively.

Results: 

On testing the BTB(4 way set associative,256 entries each) with the Dhrystone benchmark, 8 misses were reported for the first 1000 cache accesses which corresponds to a hit rate of 99.2%. The same 8 misses were reported for the first 100 as well as for the first 50 accesses which corresponds to hit rates of 92% and 84% respectively.

In Vivado, the design was found to have a maximum operating frequency of 377MHz on an Artix 7 board. The utilization reports may be found in the 'vivado' folder.
