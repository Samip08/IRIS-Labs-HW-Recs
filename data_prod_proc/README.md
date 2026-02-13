System Architecture
The design is split into three primary stages to maximize efficiency and timing closure:

Data Producer (Sensor Domain - 200MHz): Simulates high-speed pixel streaming from a CMOS sensor.

Async FIFO (The Bridge): A LIFO-inspired asynchronous buffer using Gray Code pointers for safe, low-latency Clock Domain Crossing (CDC).

Data Processor (Processing Domain - 100MHz): A sliding-window convolution engine using line buffers for real-time stream processing.

Execution & Compatibility
Notice
Primary Verification: The system was initially verified in Icarus Verilog. If you encounter discrepancies in simulation, please refer to the integrated source files used in the Icarus environment.

Quartus Standards: For hardware synthesis, use the files located in the quartus_execution_modules folder. These have been modularized for professional EDA toolchains.

Important: Testbench Configuration
The provided testbench includes an explicit image.hex generation block.

Warning: If you are using a custom image.hex for validation, you must comment out the generation block in the testbench, or your custom file will be overwritten at runtime.

Benefits of this design
1. Gray-Coded Async FIFO 
Our model utilizes Gray Code pointers to guarantee that values are transported safely with minimum latency.

One-Bit Toggling: By ensuring only one bit changes per transition, we eliminate the need for traditional synchronization delays. The system inherently knows if a value is a continuation of the past or a fresh update.

Handshake Mechanism: Optimizing clock cycles in this uesecase(200MHz/100MHz) provides a robust handshake that ensures the latest value updated with the toggled Gray bit is picked up immediately by the slower processing clock.

2. Stream Processing & Line Buffering
Instead of wasting massive amounts of on-chip memory (BRAM) to store an entire image, this processor uses a sliding window technique.

Line Buffers: The processor stores only two rows of pixels at a time.

Sliding Window: Once three vertical pixels are available, the 3x3 window "slides" across the stream, multiplying by the kernel and summing the results instantly.

3. Maximum Throughput (Zero Pixel Loss)
Clock Independence: Your sensor runs at its max native speed (200MHz) while your processor runs at a stable 100MHz.
The processor stalls until it recieves all the pits to prevent any garbage output , further incase a complex filter slows down the processor, the producer is made to pause to ensure safety of data.

