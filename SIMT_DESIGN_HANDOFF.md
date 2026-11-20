# Four-warp RISC-V SIMT processor — design handoff

Ethan Scott · November 19, 2026 · Architecture planning

Ethan is adapting the SystemVerilog processor in `eckscott/custom-gpu` into a four-warp SIMT processor. His main goal is a **one-clock handoff from a stalled warp to another ready warp**. He owns the architectural decisions and will explicitly request implementation. The repository instructions call for SystemVerilog and both BYU coding standards. A proposed departure from those standards requires his approval. [Repository instructions][agents] · [ECEN 423 standard][byu423] · [ECEN 320 standard][byu320]

## Design decisions to carry forward

- The planned directory is `simt-proc/`. The repository instructions describe the later scalar processor with forwarding and branch prediction. Ethan chose to start from a copy of **Lab 8’s basic five-stage pipeline**, keep pipelining, and drop branch prediction and datapath forwarding. Lab 8 advances fetch by four until a taken `beq` redirects it, and its assembly inserts NOPs to cover hazards. The new front end and interlocks must handle these cases in hardware. Lab 9 introduced forwarding. Lab 11 is a reference for jump targets and link writeback. [Lab 8 fetch][lab8-if] · [Lab 8 branch resolution][lab8-branch] · [Lab 8 NOP assumptions][lab8-nops] · [Lab 9 forwarding][lab9] · [Lab 11 jumps][lab11-jumps]
- Build **one shared instruction fetch and decode path feeding four physical execution lanes**. Each lane retains EX, MEM, and WB functions. Four resident warps of four threads give 16 logical threads. The top level owns PC selection, scheduling, and instruction decode. Register numbers are decoded centrally, and operand values are read locally in each lane.
- Use **hardware-only, equal-PC grouping within a warp**, inspired by Simty. Branch outcomes and indirect targets come from the issuing threads’ actual register values. The program can use ordinary RISC-V branches and jumps without compiler-selected convergence addresses or inserted split/join instructions.

## Where state lives and how instructions move

| Scope | State or hardware | What happens on issue |
|---|---|---|
| One core | Instruction memory interface, fetch, decode, scheduler | Select one warp and one PC. Broadcast one decoded instruction to its enabled lanes. The proposed front end issues at most one such instruction per cycle. |
| Four warps | Scheduling state and pending dependencies | Each warp can advance or wait independently, even when all four start the same kernel at the same PC. |
| Sixteen threads | Each thread’s next PC, live state, and architectural registers | The working model stores four PCs per warp, or 512 bits for all sixteen 32-bit PCs. One fetch port serves the selected PC. |
| Four physical lanes | Operand reads, ALU, branch comparison, address and store-data generation | Lane 2 serves thread position 2 of whichever warp is issuing. Switching warps selects a different resident context. |
| Each in-flight instruction | Valid bit, originating warp ID, issue PC, lane mask, destination register, and controls | These travel through the pipeline alongside lane-specific data. At writeback the original warp and mask select the destinations. |
| Data memory | Shared address space with lane-specific requests and responses | A shared arbiter could serialize four addresses over one port. Port count and arbitration remain open. |

For example, warp 2 issuing `add x5,x1,x2` with mask `0101` enables lanes 0 and 2 (bit 0 is lane 0). Each reads its own warp-2 operands and writes its own warp-2 `x5`. Both execute the same instruction and can produce different results. At the same time, an older warp’s instruction can be further down the pipeline.

## Branches, jumps, and opportunistic reconvergence

The working rule is to select a ready warp, choose one eligible lane’s resolved PC, and form the issue mask from **all live, eligible lanes in that warp with the same PC**. Only those lanes advance or produce side effects for this instruction. Other ready subgroups can run on later cycles. A rotating choice of lane was proposed to give both sides of a split opportunities to run.

| RV32 instruction | Hardware behavior for the issuing mask `M` |
|---|---|
| Conditional branch | Compute the target `PC + signed branch offset` and fall-through `PC + 4` once. Each lane evaluates the comparison on its own operands. The taken mask is `M & condition` and the fall-through mask is `M & ~condition`. Each participating lane gets the corresponding next PC. |
| `jal` | All issuing lanes take the same PC-relative target. Each writes `PC + 4` to its own `rd` if `rd` is nonzero. |
| `jalr`, including `ret` | Each issuing lane’s target is `(rs1_value + sign_extended_imm) & ~1`. The same link-write rule applies. A single `ret` can yield four distinct targets because the lanes can hold different return addresses. Two fixed PC slots per warp would be insufficient. |

The examples assume four-byte instructions. [RISC-V jump semantics][rv-jumps] · [RISC-V conditional branches][rv-branches]

**Worked example.** At `0x100`, lanes 1 and 3 take a `beq` to `0x108`. The four next PCs, in lane order, become `[0x104, 0x108, 0x104, 0x108]`. If the scheduler selects `0x104`, mask `0101` executes an `addi` and advances to `0x108`. Now mask `1111` can issue together. If lanes 1 and 3 run ahead, the shared tail can instead execute under separate masks. PC equality creates an opportunity to share issue. A warp-wide barrier would need its own participation and arrival rules.

### The Simty RTL to study

The inspected public VHDL source is `FPGAML/simty` at `c5dd689`.

| Question | What the RTL actually does |
|---|---|
| How does a branch split? | The branch unit intersects the valid lane mask with lane comparison results. It produces default and taken/replay path records containing a PC and a mask, and marks empty paths invalid. [Branch masks and target selection][simty-branch] · [Output path records][simty-paths] |
| How does an indirect jump handle several targets? | Simty picks an active leader’s actual target, compares every lane’s target to it, and replays the unmatched active lanes at the jump PC. This is a concrete alternative to writing all four resolved targets into the individual PC slots at once. [Indirect-target comparison and replay][simty-branch] |
| Where do paths rejoin? | The inspected top level instantiates the context-table tracker. Its compaction logic compares valid path PCs, ORs masks for equal PCs, and invalidates redundant records. Hardware recognizes paths that have arrived at the same address. [Top-level instance][simty-top] · [Context-table tracker][simty-ct] · [Equal-PC mask merge][simty-merge] |
| Where can I see the simple per-thread PC idea? | The repository also contains a per-lane-PC tracker. Its membership unit stores PC rows indexed by warp and enables each live lane whose PC equals the selected PC. This is the closest reference for our proposed four-lane implementation. Simty’s separate fetch-steering unit supports speculative PCs. Ethan’s design selects resolved PCs. [Per-lane PC update][simty-vector] · [PC storage and membership comparison][simty-membership] · [Fetch steering][simty-fetch] |

Two other open-source designs informed the choice. **FGPU** runs the smaller divergent group first, saves the other PC and lane enables on stacks, and can resume deferred work on return. Its designers show a common tail executing twice under different masks. **Vortex** computes lane masks and uses a per-warp divergence stack to switch paths and restore the original mask. Software supplies explicit split and join instructions. Both provide examples of mask handling. Simty provides the model selected for this project. [FGPU scheduler][fgpu] · [FGPU design, §3.4 and Fig. 3.3][fgpu-design] · [Vortex split/join RTL][vortex-rtl] · [Vortex instruction intrinsics][vortex-isa]

## Register files on an FPGA

The proposed physical organization is **four register-file modules, one per lane**. Each holds four threads’ register contexts in an ordinary **128-word × 32-bit bank**. In the logical expression `regs[warp][lane][reg]`, the lane selects the physical bank and the seven-bit word address is `{warp_id[1:0], reg_number[4:0]}`. Warps 0 through 3 occupy rows 0–31, 32–63, 64–95, and 96–127 respectively. Total logical capacity is 2 KiB including the reserved `x0` rows.

Preserve the existing register file’s two synchronous reads and write-first behavior. Reads use the decode-stage warp ID. Writes use the writeback warp ID and that lane’s write enable. For example, warp 2 reading `x5` addresses row 69, while warp 0 writing `x5` addresses row 5. The write-first comparison must include all seven address bits. The `x0` write guard tests only the five-bit register number so every warp’s `x0` stays zero. [Current register file][regfile]

Four RTL banks can map to several FPGA memory primitives. A common implementation of two reads plus one write per clock mirrors writes to two block-RAM copies per lane, with one copy serving each read port. Vivado may choose distributed LUTRAM. The resource count and memory type require a synthesis report. Lab 8’s existing synthesis target is the Artix-7 `xc7a35tcpg236-1`. [Synthesis target][lab8-synth]

## Pipelining and the one-cycle scheduling goal

The working design lets independent instructions from one warp overlap. The earlier suggestion of **one outstanding instruction per warp** was a bring-up simplification. Ethan challenged that restriction and favored keeping pipelining with forwarding disabled. For example, `add x5,x1,x2` and `xor x6,x3,x4` can issue consecutively. A following `sub x7,x5,x6` waits until both results are readable in that thread’s register file. Another ready warp can issue while the consumer waits.

A proposed scoreboard records pending destination registers per warp. An unresolved control transfer can hold the affected warp until its successor PCs are available. To test the **one-cycle handoff**, arrange for warp 0 to block at cycle N while warp 1 has an instruction ready and the issue port is available. Look for a ready warp issuing at N+1 and for warp 0’s eventual response reaching its own lanes. This timing target awaits an RTL trace.

## Decisions still open

| Topic | Decision for Ethan |
|---|---|
| Warp scheduling | Choose warp and subgroup arbitration, fairness, and what makes a fetched instruction ready. Define the exact stall and issue events used to measure the one-cycle handoff. |
| PC update and hazards | Choose the stage that reserves or advances each next-issue PC and the stage that resolves branches. Define scoreboard granularity, same-cycle writeback/read timing, and ordering of writes when a load returns late. |
| Memory and lane completion | Choose physical memory ports, how masked requests are issued exactly once, how replies identify warp and lane, and whether a partial response holds the whole warp. |
| Control-flow scope | Choose the first branch/jump subset, direct per-lane target updates versus indirect-jump replay, and launch/exit conventions. Barriers or collectives would need additional semantics if introduced. |
| Validation | Choose a usable simulator for the new testbench and check actual FPGA RAM inference in synthesis. Candidate directed tests include a 2/2 split with masked stores, a four-target `jalr`, simultaneous reads and writes to different warps’ `x5`, and switching warps during an outstanding load. |

## Questions Ethan has been working through

- **How can sixteen logical register files still infer FPGA RAM?** This was Ethan’s latest question. Use the row-69/row-5 example to trace two synchronous read ports and one write port on a single lane. Show what determines the number of RTL banks, then check the FPGA primitive count in an actual Vivado report when one becomes available.
- **Where do the warps come in?** Walk one physical lane across two cycles with different warp IDs. Show which thread’s registers it reads each time. Ethan asked about the three stages versus the four lane instances and where the 16 thread contexts live.
- **Which threads execute the same instruction?** Trace two warps at different PCs and then a single warp split into two masks. Show what is shared at decode and what remains thread-private through writeback.
- **Does one in flight mean giving up pipelining?** Draw a short EX/MEM/WB timing table for the `add`, `xor`, and dependent `sub` above, with another warp filling the available issue slot.
- **Do both branch paths need their own PC counters?** Use the four-PC example to distinguish saved next addresses from fetch hardware. Trace both possible issue orders to show when lanes reunite and when they run the common instruction separately.

## Cloud environment context

The earlier onboarding session inspected `eckscott/custom-gpu` on `main` at `7c32242015f9c05e28a2927a36a0b446ff6b4de9`. In that instance the bundled RARS 1.6 assembled Lab 11, the Fibonacci run matched the expected `s0` and eight memory rows, Lab 11 RTL lint completed with warnings, and the existing register-file testbench passed. Verilator’s Python package 5.48.0 and GitPython 3.1.46 were installed in `/workspace/.custom-gpu-tools/venv`. These results describe the **existing labs**. The SIMT processor is still in planning.

Full Lab 11 simulation remained blocked. The official Make target stopped at the missing Vivado executable `xvlog`. Verilator rejected the testbench package’s `$readmemh` into a dynamic array. That earlier Make run generated `lab11/final_{text,data}.mem` and `lab11/final_{text,data}_debug.txt`. Onboarding stopped before the assistant saved setup instructions or published an environment. The last inspected draft was named `custom-gpu` with empty install and startup instructions. Publishing in environment settings is the step that snapshots the prepared workspace for future tasks. [Lab 11 Makefile][lab11-make] · [Testbench construct][tb-memory]

[agents]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/AGENTS.md
[byu423]: https://byu-cpe.github.io/ecen423/03-coding-standards/
[byu320]: https://byu-cpe.github.io/ecen320/coding-standard/#system-verilog-coding-standards
[lab8-if]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab08/riscv_basic_pipeline.sv#L75-L101
[lab8-branch]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab08/riscv_basic_pipeline.sv#L368-L375
[lab8-nops]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab08/pipeline_nop.s#L3-L10
[lab9]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab09/riscv_forwarding_pipeline.sv#L376-L400
[lab11-jumps]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab11/riscv_final.sv#L547-L562
[regfile]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab03/regfile.sv#L24-L56
[lab8-synth]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab08/synth_riscv_basic_pipeline.tcl#L22
[lab11-make]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/lab11/makefile#L4-L16
[tb-memory]: https://github.com/eckscott/custom-gpu/blob/7c32242015f9c05e28a2927a36a0b446ff6b4de9/include/tb_riscv_pkg.sv#L766-L779
[rv-jumps]: https://github.com/riscv/riscv-isa-manual/blob/b818fc57467b3d50e06c495dca7babba9092cc68/src/unpriv/rv32.adoc#L398-L431
[rv-branches]: https://github.com/riscv/riscv-isa-manual/blob/b818fc57467b3d50e06c495dca7babba9092cc68/src/unpriv/rv32.adoc#L527-L532
[simty-branch]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/branch.vhd#L44-L72
[simty-paths]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/branch.vhd#L89-L112
[simty-top]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/simty.vhd#L234-L275
[simty-ct]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/convergence_tracker_ct.vhd#L115-L149
[simty-merge]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/context_compact_sort.vhd#L119-L147
[simty-vector]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/convergence_tracker.vhd#L74-L85
[simty-membership]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/membership.vhd#L58-L103
[simty-fetch]: https://github.com/FPGAML/simty/blob/c5dd68997e193426de4737225489a84115f1eed2/fetch_steering.vhd#L12-L24
[fgpu]: https://github.com/CEatBTU/FGPU/blob/488f4a59e6607724d406719e7d6a99aa90654529/RTL/db/cu_scheduler.vhd#L742-L808
[fgpu-design]: https://github.com/CEatBTU/FGPU/blob/488f4a59e6607724d406719e7d6a99aa90654529/old_docs/Dissertation.pdf
[vortex-rtl]: https://github.com/vortexgpgpu/vortex/blob/01d0ac75059c50b191c646379df65ce14cf53636/hw/rtl/core/VX_split_join.sv#L40-L81
[vortex-isa]: https://github.com/vortexgpgpu/vortex/blob/01d0ac75059c50b191c646379df65ce14cf53636/sw/kernel/include/vx_intrinsics.h#L147-L164
