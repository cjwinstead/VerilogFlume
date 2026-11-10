# VerilogFlume
A Julia module for generating Verilog projects and source code.

<!-- sara 11/5/26: everything below is new. what works today, checked by
test/runtests.jl, and what is not finished yet. -->

You describe a Verilog module, a testbench, a task or a function as a handful of
text fields, and VerilogFlume fills a template with them. It also knows the
Basys3 board: which resources it has (`led`, `sw`, `sevensegment`, ...), the
port declaration for each one, and the matching XDC constraints.

## Install

```julia
using Pkg
Pkg.develop(path="path/to/VerilogFlume")   # or Pkg.activate on the folder
using VerilogFlume
```

Julia 1.11 or later (the source uses `public`).

## A module and its testbench in five lines

```julia
using VerilogFlume

m = new_module(name = "dff",
               ports = "input clk,\ninput d,\noutput reg q",
               always_ff_assignments = "always @(posedge clk) q <= d;")
write("dff.v", generate_module_source(m))

tb = new_testbench(name = "tb_dff",
                   stopping_condition = "clk_count > 20",
                   signals = "reg d;\nwire q;",
                   initial_assignments = "initial d = 0;",
                   always_ff_assignments = "always @(posedge clk) d <= ~d;",
                   submodules = "dff u(.clk(clk), .d(d), .q(q));")
write("tb_dff.v", generate_testbench_source(tb))
```

```
iverilog -o tb.vvp tb_dff.v dff.v && vvp tb.vvp
```

The testbench template already declares `clk` (10 ns period), `rst` (high for
the first few clocks) and an `integer clk_count`, and calls `$finish` when
`stopping_condition` becomes true.

Every field you leave out gets its default from `schema.yaml`. The same
description can also be YAML text: `generate_module_source(yaml_string)` works,
and `module_yaml_template("name")` prints a blank one to start from.

## The fields

Each field is pasted into the template as plain text, so it is ordinary Verilog.

| kind | fields |
|---|---|
| `module` | `name`, `ports`, `parameters`, `signals`, `submodules`, `initial_assignments`, `continuous_assignments`, `always_comb_assignments`, `always_ff_assignments` |
| `testbench` | `name`, `parameters`, `stopping_condition`, `signals`, `submodules`, `initial_assignments`, `continuous_assignments`, `always_comb_assignments`, `always_ff_assignments`, `displays`, `monitors` |
| `task` | `name`, `automatic`, `ports`, `behavior` |
| `function` | `name`, `width`, `inputs`, `behavior` |
| `project` | `name`, `board`, `resources`, `ip`, `pmods`, `modules`, `testbenches` |

For each kind there is `new_<kind>(; fields...)`, `<kind>_yaml_template(name)`
and, except `project`, `generate_<kind>_source(description)`.

Note: `displays` and `monitors` are accepted but the testbench template does not
use them yet.

## Reading an existing module

```julia
h = scan_module_header(read("adder4.v", String))
h["name"]                  # "adder4"
h["ports"]                 # direction, name, width, signed, depth, comment
print(instantiate_module(h))   # reg/wire for every port, then an instance
```

`instantiate_module(h; clk=false, rst=false)` leaves out the `clk` and `rst`
declarations when the testbench template already has them.

## The board

```julia
VerilogFlume.resources_available()       # what the Basys3 offers (public, not exported)
print(generate_xdc("resources: [clk, led, sw]"))
```

Board files live in `boards/`. `selected_board` is `"basys3"`, the only one so
far.

## Status

Works and is tested: the module, testbench, task and function sources, the YAML
templates, `scan_module_header`, `instantiate_module`, `generate_xdc` and the
`list_*` helpers.

Not finished:

- `generate_top` is declared but has no body yet.
- `generate_makefile` expects a `project:` key that `schema.yaml` does not have
  (it has `name:`), and the makefile it writes includes
  `resources/verilog.mk`, which is not in this repository.
- `ip` and `pmods` are listed for the board but nothing generates them yet.

## Tests

```
julia --project=. test/runtests.jl
```

With Icarus Verilog on the PATH the tests also compile and run a generated
module and testbench.
