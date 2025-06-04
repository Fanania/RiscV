# RISC-V Pipelined Processor (Verilog)

This is a modular, pipelined implementation of a RISC-V processor in Verilog, designed for simulation and future synthesis. It supports the classic 5-stage pipeline architecture and is structured for scalability and extensibility.

## Features

- 5-Stage Pipeline:
  - IF – Instruction Fetch
  - ID – Instruction Decode
  - EXE – Execute
  - MEM – Memory Access
  - WB – Write Back

- Modular design – each stage implemented as a separate Verilog module
- Control unit with full instruction decoding
- Hazard detection unit:
  - Data forwarding (bypass)
  - Pipeline stalling
  - Flush logic for branch/jump instructions
- Load/Store control logic

## Current Setup (Simulation)

- Instruction memory loaded using Verilog's `readmemh` function and `.hex` files
- Data memory modeled as a non-synthesizable RAM (to be replaced)

## Planned Improvements

- Replace instruction & data memory with dedicated synthesizable IP cores
- Add a branch predictor for improved control flow performance
- Implement CSR (Control and Status Register) support

## Project Structure
