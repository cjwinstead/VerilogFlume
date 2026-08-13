module VerilogFlume

using YAML,OrderedCollections,Mustache

boards         = Dict{String}{Dict}()
schema         = OrderedDict{String}{Any}()
selected_board = String("basys3")     # default 

function __init__()
    board_dir = joinpath(@__DIR__,"..","boards")
    board_files = readdir(board_dir;join=true)
    for b in board_files
        if splitext(b)[2] == ".yaml"
            board_name=basename(splitext(b)[1])
            boards[board_name] = YAML.load_file(b;dicttype=OrderedDict{String,Any})
        end
    end
    schema_file = joinpath(@__DIR__,"..","schema.yaml")
    schema = YAML.load_file(schema_file;dicttype=OrderedDict{String,Any})

    ###########################################################
    # Meta-definition for constructing new project objects
    ###########################################################
    for k in keys(schema)
        parms=""
        for p in keys(schema[k])
            parms *= "$(p)=true,"
        end
        str="function new_$(k)(;$(parms) )\n"
        str*="  d=OrderedDict{String,Any}()\n"
        for p in keys(schema[k])
            str*="   if typeof($(p))!=Bool\n   d[\"$(p)\"]=$(p)\nelseif $(p)\n d[\"$(p)\"]=$(schema[k][p]) end\n"
        end
        str*="  return d\nend\n"


        println("Generated from schema: ", str)
        eval(Meta.parse(str))

        str="\nfunction $(k)_yaml_template()\n"
        str*="   m=new_$(k)()\n"
        str*="   YAML.write(m)\nend\n"
        println("Generated from schema: ", str)
        p=Meta.parse(str)
        
        eval(p)
        
        if isfile("templates/$(k).v")
            str="\nfunction generate_$(k)_source(prj::String)\n"
            str*="   generate_$(k)_source(YAML.load(prj))\nend\n"
            println("Generated from schema: ", str)
            eval(Meta.parse(str))
            str="function generate_$(k)_source(prj::OrderedDict)\n"
            str*="   Mustache.render_from_file(\"templates/$(k).v\",prj)\nend\n"
            eval(Meta.parse(str))
        end
    end
    ###########################################################
end




"""
      resources_available()
"""
function resources_available()
    return boards[selected_board]["resources"]["available"]
end


"""
      pmods_available()
"""
function pmods_available()
    return boards[selected_board]["pmods"]
end



"""
      ip_available()
"""
function ip_available()
    return boards[selected_board]["ip"]
end



"""
      parse_parameter_declaration(s)
"""
function parse_parameter_declaration(s)
    r=r"parameter[[:space:]]+(signed)?[[:space:]]*([a-zA-Z_0-9]+)([[:space:]]*=[[:space:]]*[^[:space:],;]+)?"
    m=match(r,s,1)
    if (m != nothing)
        parsigned=m.captures[1]
        parname=m.captures[2]

        p=match(r"=?[[:space:]]*(.*)",m.captures[3])
        if (p != nothing)
            pardef=p.captures[1]
        else
            pardef=nothing
        end

        d=OrderedDict{String,Union{Nothing,String}}(
            "name"=>parname,
            "signed"=>parsigned,
            "default"=>pardef
        )
        return d
    end
end


"""
      parse_port_declaration(s)
"""
function parse_port_declaration(s)
    r=r"(input|output)[[:space:]]+(reg)?[[:space:]]*(signed)?[[:space:]]*(reg)?[[:space:]]*(\[[^[:space:]]+\])?[[:space:]]*([^[:space:],\[\]);]+)(\[[^,]+\])?[,;)]*[[:space:]]*(//.*)?"
    m=match(r,s,1)

    if (m != nothing)
        portdirection=m.captures[1]
        portsigned=m.captures[3]
        portbits=m.captures[5]
        portname=m.captures[6]
        portdepth=m.captures[7]
        cmt=m.captures[8]

        d=Dict{String,Union{Nothing,String}}(
            "direction"=>portdirection,
            "name"=>portname,
            "signed"=>portsigned,
            "width"=>portbits,
            "depth"=>portdepth,
            "comment"=>cmt
        )
        return d
    else
        return nothing
    end
end


"""
      is_port_declaration(line)
"""
function is_port_declaration(line)
    m=match(r"^[[:space:]]*(module)?[[:space:]]*([a-zA-Z_]+[[:space:]]*\()?[[:space:]]*(input|output)",line,1)
    if (m==nothing)
        return false
    else
        return true
    end
end


"""
      is_parameter_declaration(line)
"""
function is_parameter_declaration(line)
    m=match(r"^[[:space:]]*(module)?[[:space:]]*([a-zA-Z_]+[[:space:]]*#\()?[[:space:]]*(parameter)",line,1)
    if (m==nothing)
        return false
    else
        return true
    end
end


"""
      scan_module_header(s)
"""
function scan_module_header(s)
    data=OrderedDict{String,Any}(
        "ports"=>Vector{OrderedDict{String,Union{Nothing,String}}}(),
        "parameters"=>Vector{OrderedDict{String,Union{Nothing,String}}}()
    )

        for line in eachline(IOBuffer(s))
            m=match(r"^[[:space:]]*module[[:space:]]+([a-zA-Z_]+)",line,1)
            if (m != nothing)
                data["name"]=m.captures[1]
            end

            if (is_port_declaration(line))
                d=parse_port_declaration(line)
                push!(data["ports"],d)
            elseif (is_parameter_declaration(line))
                d=parse_parameter_declaration(line)
                push!(data["parameters"],d)
            end
        end

    return data
end

"""
      declare_port_test_signals(data;clk::Bool=true,rst::Bool=true)
"""
function declare_port_test_signals(data;clk::Bool=true,rst::Bool=true)
    s=string("")
    d=get(data,"ports",nothing)
    if (d != nothing)
        for x in d
            if (
                (x["name"] != "clk" && x["name"] != "rst")
                || (clk && x["name"]=="clk")
                || (rst && x["name"]=="rst")
                )
                if (x["direction"]=="input")
                    s=string(s,"   reg ")
                else
                    s=string(s,"   wire ")
                end
                if (x["signed"] != nothing)
                    s=string(s,x["signed"]," ")
                end

                if (x["width"] != nothing)
                    s=string(s,x["width"]," ")
                end
                s=string(s,x["name"])
                if (x["depth"] != nothing)
                    s=string(s,x["depth"])
                end
                s=string(s,";\n")
            end
        end
    end
   return s
end


"""
      declare_module_instance(data::String)
"""
function declare_module_instance(data::String)
    declareModuleInstance(YAML.load(data))
end

"""
      declare_module_instance(data::OrderedDict)
"""
function declare_module_instance(data::OrderedDict)
    s=string("")
    s=string(s,"   ",data["name"]," ")
    p=get(data,"parameters",nothing)

    if (p != nothing && length(p)>0)
        s=string(s,"#(")
        for x in p
            n=string(x["name"])
            s=string(s,""".$(n)($(n))""")
            if (x == last(p))
                s=string(s,") ")
            else
                s=string(s,", ")
            end
        end
    end
    s=string(s,data["name"],"_inst (\n")
    for x in data["ports"]
        s=string(s,"      .",x["name"],"(",x["name"],")")
        if (x != last(data["ports"]))
            s=string(s,",\n")
        else
            s=string(s,"\n   );\n")
        end
    end
    return s
end


"""
      instantiate_module(data::String;clk::Bool=true,rst::Bool=true)
"""
function instantiate_module(data::String;clk::Bool=true,rst::Bool=true)
    instantiate_module(scan_module_header(data);clk=clk,rst=rst)
end

"""
      instantiate_module(data::Dict;clk::Bool=true,rst::Bool=true)
"""
function instantiate_module(data::OrderedDict;clk::Bool=true,rst::Bool=true)
    s=declare_port_test_signals(data;clk=clk,rst=rst)
    s=string(s,"\n", declare_module_instance(data))
    return s
end



"""
      append_to_key(data,key, text)
"""
function append_to_key(data,key, text)
    if !haskey(data,key)
        data[key]=""
    end
    data[key]=string(data[key],text)
end

"""
      prepend_to_key(data,key, text)
"""
function prepend_to_key(data,key, text)
    if !haskey(data,key)
        data[key]=""
    end
    data[key]=string(text,data[key])
end




"""
      generate_makefile(data::String)
"""
function generate_makefile(data::String)
    generate_makefile(YAML.load(data))
end

"""
      generate_makefile(data::Dict)
"""
function generate_makefile(data::OrderedDict)
    prj = data["project"]

    s="""
export PROJECT = $(prj)
export TOP     = top

#####################################################
# DO NOT EDIT BELOW THIS LINE
# unless you know what's going on
#####################################################

# include generic makefile for verilog projects
export ROOT:=\$(shell git rev-parse --show-toplevel)
include \$(ROOT)/resources/verilog.mk
"""
    return s
end







"""
      nada(x)
"""
function nada(x)
    if x == nothing
        return true
    else
        return isempty(x)
    end
end


"""
      generate_top(project::String)
"""
function generate_top(project::String)
    generate_top(YAML.load(project))
end



"""
      generate_xdc(data::String)
"""
function generate_xdc(data::String)
    generate_xdc(YAML.load(data))
end


"""
      generate_xdc(data::Dict)
"""
function generate_xdc(data::OrderedDict)
    s=""
    for x in data["resources"]
        s *= boards[selected_board]["xdc"][x] * "\n"
    end
    return s
end


###########################################################
# Meta-definition for listing project elements
###########################################################
for k in ["modules","testbenches","resources","ip","pmods"]
    str="""
function list_$(k)(s::String)
   list_$(k)(YAML.load(s))
end
       """
    eval(Meta.parse(str))

    str="""
function list_$(k)(d::OrderedDict)
   s=""
   if haskey(d,"$(k)")
        for m in d["$(k)"]
            s*=" \$(m)"
        end
    end
    strip(s)
end
    """
    eval(Meta.parse(str))

end
###########################################################




public resources_available
public pmods_available
public ip_available

export parse_port_declaration
export is_port_declaration
export scan_module_header
export declare_port_test_signals
export declare_module_instance

export instantiate_module
export generate_makefile
export generate_xdc

export list_modules
export list_testbenches
export list_ip
export list_pmods
export list_resources


end
