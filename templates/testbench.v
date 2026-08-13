`timescale 1ns/1ps

module {{name}}
   {{#parameters}}
     #( 
      {{parameters}}
     ){{/parameters}}();

   reg clk;
   reg rst;
   integer clk_count;

    initial begin
       rst = 1;
       clk = 0;
       forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
       clk_count <= clk_count + 1;
       if (clk_count > 1)
          rst <= 0;
       // Stopping condition:
       if ({{stopping_condition}})
          $finish();
    end
		   
   {{signals}}

   {{submodules}}

   {{initial_assignments}}
   
   {{continuous_assignments}}

   {{always_comb_assignments}}

   {{always_ff_assignments}}
     
endmodule
