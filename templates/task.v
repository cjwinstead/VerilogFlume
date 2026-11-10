{{! sara 11/4/26: three braces, two braces escaped < > & into &lt; &gt; &amp; and the verilog did not compile }}
task {{#automatic}}automatic{{/automatic}} {{{name}}};
   
{{{ports}}}

{{{signals}}}

begin
{{{behavior}}}
end
endtask   
