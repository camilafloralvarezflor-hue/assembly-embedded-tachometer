This project features a high-precision digital tachometer implemented entirely in HC08 Assembly. It measures frequency/RPM using hardware interrupts and displays the result on a multiplexed 4-digit 7-segment display.

🚀 Technical Highlights
Unlike standard high-level implementations, this project focuses on low-level hardware optimization:

Interrupt-Driven Architecture: Uses Input Capture (IC) for pulse detection and Timer Overflow (TOF) to manage a precise 1.0s sampling window.

Double Dabble Algorithm: Efficient Binary-to-BCD conversion implemented from scratch to handle data processing without high-level math libraries.

Dynamic Multiplexing: Software-controlled refresh rate for 7-segment displays using NPN transistors to ensure flicker-free visualization.

Scalability: Supports dual-scale logic (x1 and x10) to measure up to 99,999 RPM.

🛠 Hardware Specifications
MCU: Freescale/NXP MC68HC908JL8.

Display: 4-Digit 7-Segment (Common Cathode/Anode).

Input: Signal generator (Arduino-based for testing).

Timing: 1.0s time base managed via internal Timer registers.

🧠 Engineering Challenges & Solutions
The Sampling Synchronization Problem
Issue: Initial measurements were inconsistent because pulse counting and time-window calculations were tightly coupled, leading to race conditions. Solution: I implemented a dedicated variable PULSOS_CAP. The ISR_IC (Interrupt Service Routine) only increments this counter, while the ISR_OVF handles the 1s logic, transfers the final value, and resets the counter. This decoupling eliminated measurement errors.

Memory Optimization
Working with limited RAM on the HC08 required careful register management. I optimized the Double Dabble routine to use minimal memory addresses, ensuring the stack remained stable during nested interrupts.

📂 Project Structure
/src: Contains the .asm source code with detailed comments.

/docs: Technical report (PDF) and schematics.

/sim: (Optional) Proteus simulation files or waveforms.
