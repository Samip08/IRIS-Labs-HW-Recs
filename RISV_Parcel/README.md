RISC-V IMPLEMENTATION OF PIXEL PROCESSING SYSTEM
================================================
* This repository contains a high-performance RISC-V System-on-Chip (SoC) tailored for real-time image processing. The architecture integrates a custom data processing unit with the PicoRV32 CPU.

* This design offloads computationally expensive tasks—such as 3x3 Convolution—directly into the hardware datapath, significantly reducing CPU cycles per pixel.

System Architecture & Datapath
------------------------------
* data_proc.v utilizes a triple-line-buffer architecture to enable real-time filtering without stalling the pixel stream.
* Line Buffers: Two 1024-deep SRAM buffers (lb1, lb2) store previous pixel rows to facilitate vertical neighborhood access.
* Sliding Window: A 9-register grid (p11 to p33) captures a full 3x3 pixel neighborhood on every clock cycle.

Processing Modes
----------------
Bypass (00): Direct data passthrough.Inversion (01): Pixel-wise subtraction (255 - Pin).Convolution (10): Parallel Multiply-Accumulate (MAC) operations using a 72-bit programmable kernel, followed by a fixed-point scaling division

Directory Structure
-------------------
* RISV_Parcel: All core development is contained within the RISV_Parcel directory. File heirarcy is mentioned below:

* data_proc.v: The primary hardware accelerator.
* rvsoc.v / rvsoc_wrapper.v: Top-level SoC integration and pin wrapping.
* picorv32.v: The RISC-V CPU implementation.
* uart_tb.v: The system testbench (Logic verification and logging).
* spiflash.v / simpleuart.v: External peripheral and communication modeling.Simulation and ValidationThe system is validated using Icarus Verilog.

* The simulation environment executes a sequential test of all processing modes, verifying the transition from simple bypass to complex convolution.

* Compilation CommandTo build the simulation environment, navigate to the RISV_Parcel directory and run:Bashcd RISV_Parcel
iverilog -s uart_tb -o uart_sim.vvp final_test.v rvsoc_wrapper.v rvsoc.v picorv32.v spimemio.v simpleuart.v spiflash.v data_proc.v

* ExecutionRun the compiled simulation object using vvp:Bashvvp uart_sim.vvp

Simulation PhasesBypass Phase
----------------------------
* Verifies the baseline datapath integrity (Pixels 0-50).Inversion Phase: Validates combinational logic transformations (Pixels 51-150).

* Convolution Phase: The engine enters "Warmup" mode. The testbench monitors the internal pixel_count and resumes logging at Pixel 2201, ensuring only mathematically accurate convolution results are recorded.

* output flow is in the format pixel no ____ pixel value ___ exepcted value

* mode 0 value lags by certain delay as expected due to handshake mechanism in mode 1 it might look like it leads but its because its in inverse so leading technically here also means lagging

Technical Specifications
------------------------
* PicoRV32 (RISC-V RV32IMC)Bus Interface: Memory-mapped I/O for Engine Control
* Supported Image Width: 1024 Pixels
* Kernel Support: 72-bit (9x8-bit coefficients)
* Toolchain: Icarus Verilog / GTKWave