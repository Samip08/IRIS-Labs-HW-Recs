# Data Processing Block: Design Specification

## 1. Interface Definition
This module implements a streaming `valid/ready` handshake to process sensor data.

### Signals
- **Inputs:**
  - `pixel_in [7:0]`: Raw 8-bit data from the Producer.
  - `valid_in`: Logic high when `pixel_in` is stable and valid.
  - `ready_in`: Logic high when the Consumer is ready to receive data.
  - `kernel [71:0]`: 72-bit register holding nine 8-bit convolution coefficients.
- **Outputs:**
  - `pixel_out [7:0]`: The processed 8-bit result.
  - `ready_out`: Logic high when this block can accept a new input pixel.
  - `valid_out`: Logic high when `pixel_out` is processed and stable.

---

## 2. Implementation Logic (The 3 Steps)

### Step 1: Reset & State Control
- **Reset State:** When `rstn` is pulled low, all internal valid signals must be cleared (`0`), and `ready_out` should be set to `1` to indicate the system is ready for the first pixel.
- **State Transition:** Data only moves when a handshake occurs (`valid && ready` == 1).

### Step 2: Combinatorial Operation (The Math)
The module calculates the output based on the `mode` input. This logic prepares the result as soon as data arrives, regardless of the output's readiness.
- **Bypass (00):** `pixel_out = pixel_in`.
- **Invert (01):** `pixel_out = ~pixel_in`.
- **Convolution (10):** `pixel_out = Sum(Window_Pixels[0:8] * Kernel_Coefficients[0:8])`.



### Step 3: Handshake Synchronizer (The Gatekeeper)
This block manages the flow control and backpressure.
- **Backpressure Check:** The module must check `ready_in`. If `ready_in` is low, the module **must stall**, holding the current `pixel_out` and keeping `valid_out` high.
- **Input Flow:** `ready_out` should only be asserted if the current output has been successfully taken by the consumer or if the pipeline is empty.



---

## 3. Register Map (Memory Mapped)
These addresses are used by the RISC-V SoC to control the block:
- `0x00`: Mode Register (R/W)