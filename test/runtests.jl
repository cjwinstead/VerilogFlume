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
    
end
