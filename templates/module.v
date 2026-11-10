{{! sara 11/4/26: three braces, two braces escaped < > & into &lt; &gt; &amp; and the verilog did not compile }}
`timescale 1ns/1ps

module {{{name}}}
   {{#parameters}}
     #( 
      {{{parameters}}}
     ){{/parameters}}(
   {{{ports}}}
   );
   {{{signals}}}
   {{{submodules}}}
   {{{initial_assignments}}}
   {{{continuous_assignments}}}
   {{{always_comb_assignments}}}
   {{{always_ff_assignments}}}
endmodule
