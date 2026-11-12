# AGENTS.md

## Repository Expectations

- You are NEVER to act unprompted. I will architect all decisions and prompt you when to implement changes to the codebase
- We are converting a fully functioning RISC-V processor implemented in SystemVerilog with full forwarding and branch prediction to be a SIMT processor that models NVIDIA GPU behavior, with 4 warps and 4 threads per warp
- The biggest goal of the project is not just parallelism, it's efficient hardware scheduling where like NVIDIA, we acheive only a 1 clock cycle penalty of rescheduling stalled warps

## Coding standards

- All HDL will be written in SystemVerilog
- Follow the [byu ecen 423 coding standard](https://byu-cpe.github.io/ecen423/03-coding-standards/) and the [byu ecen 320 coding standard](https://byu-cpe.github.io/ecen320/coding-standard/#system-verilog-coding-standards) for all HDL
- If you wish to do anything outside of that specified in this coding standard, ask for explicit permission, highlighting the coding standard violation, before executing


