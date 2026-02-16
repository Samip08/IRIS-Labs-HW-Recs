Project Progress Status
=======================
[!CAUTION]
----------
* Current Issue (Frameline Sync): The engine is bleeding pixels from previous modes into the new frame or losing synchronization at the line boundaries of the 1024-pixel image. also mode1 is not working perfectly

How it Works
==============
The SoC operates by passing pixel data from a Producer (sensor emulator) through an Async FIFO into the Data Processor.

* Memory Mapping: The CPU controls the engine via MMIO at address 0x0200_000C.


* Pull-Back: To prevent the CPU from reading garbage data during a mode switch, the valid_out signal is de-asserted for a 5-cycle "blanking period."

Frameline Buffer: The module uses two 1024-word line buffers (lb1, lb2) to store previous rows of the image for 3x3 kernel calculations.

How to Run
----------
Follow these steps to compile the hardware and run the simulation using Icarus Verilog.

1. Compile the Design
Use the following command to compile all source files into a simulation executable. The -s uart_tb flag specifies the top-level testbench.

2. Execute Simulation
Run the generated .vvp file to start the simulation and view the logs:

Frameline Debugging
-------------------
* If you are seeing shifted pixels or "stuttering" in the output, check the following in data_proc.v:

* Pointer Reset: Ensure ptr (the line buffer index) resets to 0 exactly every 1024 pixels. If it drifts, the 3x3 kernel will align pixels from different columns.

* Warm-up Limit: Convolution (Mode 10) requires 2 full lines plus 3 pixels (2051 cycles) to fill the buffers. Ensure valid_out stays low until pixel_count >= 2051.

* FIFO Overflow: Check if ready_out in data_proc is properly back-pressuring the FIFO; if the FIFO overflows during a line change, you will lose a "frameline," causing the image to tilt.

Files in the package 
--------------------
* final_test.v: Top-level Testbench.

* rvsoc_wrapper.v: Connects the SoC to the outside world (Flash/UART).

* rvsoc.v: The main System-on-Chip bus and peripheral interconnect.

* data_proc.v: (Stage 2 Focus) The image processing engine logic.

* picorv32.v: The RISC-V CPU core.