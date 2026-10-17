UART Register Bridge

A reusable RTL module providing UART-based access to registers through a custom communication protocol.

1. Overview

Features

Architecture overview

2. Hardware Interface

Top-level interfaces

Configuration parameters

Clock and reset

3. UART Communication Protocol

UART configuration

Common framing and CRC

AXI Compact Mode

AXI Extended Mode

Register Bank Compact Mode

Commands, responses and error handling

4. Integration

RTL instantiation

Register address mapping

AXI and direct register bank integration

5. Simulation and Validation

Testbench and simulation

FPGA hardware validation (DE0)

Performance and throughput

6. Repository Structure

RTL sources

Simulation and testbench

FPGA reference design

Scripts