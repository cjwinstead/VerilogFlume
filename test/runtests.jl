using VerilogFlume,YAML,Logging
using Test

@testset "VerilogFlume" begin
    @testset "YAML templates" begin
        smod=module_yaml_template("mname")
        stst=testbench_yaml_template("arg")
        sprj=project_yaml_template("pname")

        dmod=YAML.load(smod)
        dtst=YAML.load(stst)
        dprj=YAML.load(sprj)

        @test length(keys(dmod)) == 9
        for x in [  "name",
                    "initial_assignments",
                    "parameters",
                    "submodules",
                    "always_comb_assignments",
                    "always_ff_assignments",
                    "ports",
                    "signals",
                    "continuous_assignments"
                    ]
            @test x ∈ keys(dmod)
        end
        @info "testbench template " dtst
        @test length(keys(dtst)) == 10
        for x in ["name",
                  "initial_assignments",
                  "parameters",
                  "submodules",
                  "stopping_condition",
                  "displays",                  
                  "always_comb_assignments",
                  "always_ff_assignments",
                  "signals",
                  "continuous_assignments"
                  ]
            @test x ∈ keys(dtst)
        end
        @test length(keys(dprj)) >= 4
        for x in ["project",
                  "pmods",
                  "ip",
                  "resources"
                  ]
            @test x ∈ keys(dprj)
        end

    end        

    @testset "port declarations" begin
        port_examples=["   input clk,",
                       " input [1:0] a,",
                       " output q",
                       "    output reg q,  ",
                       "  output reg [2:0] q,",
                       " output reg signed [7:0] qout     ",
                       "output signed reg [W-1:0]   result  ,",
                       " input signed [K-1:0] d  ,"
                       ]
        parse_results=Vector{Dict}()
        
        for x in port_examples
            @info "test string $(x)"
            @test is_port_declaration(x)
            d = parse_port_declaration(x)
            @info "parse result" d
            @test !isnothing(d)
            @test typeof(d) <: Dict
            @test length(keys(d)) == 6
            push!(parse_results,d)
        end

        for x in [1,3,4]
            @test isnothing(parse_results[x]["depth"])
            @test isnothing(parse_results[x]["width"])
        end
        for x in [1,2,8]
            @test parse_results[x]["direction"] == "input"
        end
        for x in 3:7
            @test parse_results[x]["direction"]=="output"
        end
        port_names=["clk","a","q","q","q","qout","result","d"]
        for idx in 1:length(port_names)
            @test parse_results[idx]["name"]==port_names[idx]
        end
        port_widths=[nothing,"[1:0]",nothing,nothing,"[2:0]","[7:0]","[W-1:0]","[K-1:0]"]
        for idx in 1:length(port_widths)
            @test parse_results[idx]["width"]==port_widths[idx]
        end
        for x in 1:5
            @test isnothing(parse_results[x]["signed"])
        end
        for x in 6:length(parse_results)
            @test parse_results[x]["signed"]=="signed"
        end
        
    end

    @testset "instantiation" begin

        src="""
      `timescale 1ns/1ps

       `define THING 123

       module abc #(
         parameter P=1
         )(
          input clk,
          input d,
          output q);
          
         assign q=d;
         
       endmodule
       """
       
        dmod=scan_module_header(src)
        @test length(dmod)==3
        @test length(dmod["parameters"])==1
        @test dmod["name"]=="abc"
        @test length(dmod["ports"]) == 3

        port_names=["clk","d","q"]
        for x in 1:3
            @test dmod["ports"][x]["name"]==port_names[x]
        end
        
        sprt=declare_port_test_signals(dmod)
        @test contains(sprt,"clk;")
        @test contains(sprt,"d;")
        @test contains(sprt,"q;")
        
        sprt=declare_port_test_signals(dmod;clk=false)
        @test !contains(sprt,"clk;")

        sinst=declare_module_instance(dmod)
        @info "declare_module_instance" sinst
        @test contains(sinst,"abc ")
        @test contains(sinst,"abc_inst")
        @test contains(sinst,".clk(clk),")
        @test contains(sinst,".q(q)")
    end

    # sara 11/5/26: the fixes from my review, one check each, and a real
    # compile and run when icarus is on the PATH
    @testset "generated verilog" begin
        m = new_module(name="dff", ports="input clk,\ninput d,\noutput reg q",
                       always_ff_assignments="always @(posedge clk) q <= d;")
        msrc = generate_module_source(m)
        @test contains(msrc, "q <= d;")            # was q &lt;= d;
        @test !contains(msrc, "&lt;")
        @test !contains(msrc, "#(")                # no parameters, no #( )
        tb = new_testbench(name="tb", stopping_condition="clk_count > 20",
                           signals="reg d;\nwire q;",
                           initial_assignments="initial d = 0;",
                           always_ff_assignments="always @(posedge clk) d <= ~d;",
                           submodules="dff u(.clk(clk), .d(d), .q(q));")
        tsrc = generate_testbench_source(tb)
        @test contains(tsrc, "clk_count > 20")
        @test contains(tsrc, "clk_count = 0;")
        @test !contains(tsrc, "#(")
        # the defaults alone have to work too
        @test contains(generate_testbench_source(new_testbench()), "clk_count > 100")
        @test contains(generate_module_source(module_yaml_template("m")), "module m")

        # the String methods
        @test contains(declare_module_instance("name: abc\nports:\n  - name: a\n"), ".a(a)")
        @test contains(generate_xdc("resources: [clk, led]\n"), "PACKAGE_PIN W5")
        @test list_resources("resources: [clk, led]\n") == "clk led"

        # digits in a module name, a parameter without a default
        h = scan_module_header("module adder4 #(\n  parameter W\n)(\n  input [W-1:0] a,\n  output q);\nendmodule\n")
        @test h["name"] == "adder4"
        @test h["parameters"][1]["name"] == "W"
        @test h["parameters"][1]["default"] === nothing
        @test length(h["ports"]) == 2

        @test length(VerilogFlume.schema) == 5

        iv = Sys.which("iverilog")
        if iv === nothing
            @info "iverilog not on the PATH, skipping the simulation"
        else
            mktempdir() do dir
                write(joinpath(dir, "dff.v"), msrc)
                write(joinpath(dir, "tb.v"), tsrc)
                vvp = joinpath(dir, "tb.vvp")
                @test success(`$iv -o $vvp $(joinpath(dir, "tb.v")) $(joinpath(dir, "dff.v"))`)
                out = read(`$(Sys.which("vvp")) $vvp`, String)
                @test contains(out, "\$finish called")
            end
        end
    end

end
