{{! sara 11/4/26: three braces, two braces escaped < > & into &lt; &gt; &amp; and the verilog did not compile }}
{{! Sara (11/4): clk_count started as x, so rst never dropped and the stopping condition never held, the sim ran forever }}
`timescale 1ns/1ps

module {{{name}}}
   {{#parameters}}
     #( 
      {{{parameters}}}
     ){{/parameters}}();

   reg clk;
   reg rst;
   integer clk_count;

    initial begin
       rst = 1;
       clk = 0;
       clk_count = 0;
       forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
       clk_count <= clk_count + 1;
       if (clk_count > 1)
          rst <= 0;
       // Stopping condition:
       if ({{{stopping_condition}}})
          $finish();
    end
		   
   {{{signals}}}

   {{{submodules}}}

   {{{initial_assignments}}}
   
   {{{continuous_assignments}}}

   {{{always_comb_assignments}}}

   {{{always_ff_assignments}}}
     
endmodule
