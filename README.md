# RISC-V Pipelined Processor (Verilog)

This repository contains a modular, pipelined implementation of a **RISC-V processor** written in **Verilog**, designed primarily for simulation and future synthesis.  
The design follows the classic **5-stage pipeline architecture** and is structured for scalability and extensibility.

---

##  Features

###  5-Stage Pipeline Architecture

- **IF** – Instruction Fetch  
- **ID** – Instruction Decode  
- **EXE** – Execute  
- **MEM** – Memory Access  
- **WB** – Write Back  

Each pipeline stage is implemented as a **separate Verilog module**, enabling clean design and easier debugging.

---

###  Control & Execution

- Control Unit with **full instruction decoding**
- ALU with dedicated **ALU control logic**
- Load/Store control logic

---

###  Hazard Handling

- **Data forwarding (bypass)**
- **Pipeline stalling**
- **Flush logic** for branch and jump instructions

---

##  Current Setup (Simulation)

- Instruction memory initialized using Verilog’s `readmemh` and `.hex` files
- Data memory modeled as a **non-synthesizable RAM** (temporary simulation model)
- Waveform-based debugging using **Synopsys Verdi**

---

##  Planned Improvements

- Replace instruction and data memory with **dedicated synthesizable IP cores**
- Add a **branch predictor** for improved control flow performance
- Implement **CSR (Control and Status Register)** support

---

##  Notes

This project is part of an academic dissertation and is currently focused on:
- correctness
- readability
- verification and debug clarity

Synthesis and FPGA/ASIC targeting are considered future steps.

---

## 👤 Author

**Florin Anania-Enache**  
Dissertation Project – 2026
