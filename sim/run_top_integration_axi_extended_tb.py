
from pathlib import Path                                  
from vunit import VUnit                                  
                                  
ROOT = Path(__file__).parent / "../"                                  
                                  
VU = VUnit.from_argv()                                  
VU.add_vhdl_builtins()
VU.add_random()
VU.add_verification_components()
                                  
LIB = VU.add_library("lib")         
LIB.add_source_files( ROOT / "src" / "*.vhd")     
LIB.add_source_files( ROOT / "src" / "conf" / "top_integration_extended_pkg.vhd")              
LIB.add_source_files( ROOT /"tb" / "top_integration_axi_extended_tb.vhd")                                  
                                  
VU.set_sim_option('modelsim.init_files.after_load', [str(ROOT / 'sim' / 'wave_top_integration_tb.do')])
VU.set_sim_option('modelsim.vsim_flags', ["-voptargs=\"+acc\""])

VU.main()
