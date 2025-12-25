# 🐍 MIPS Snake: Hardware-Level Arcade Classic
A fully functional, real-time implementation of the classic **Snake** game written entirely in **MIPS Assembly Language**. This project demonstrates high-performance software engineering within the constraints of a RISC instruction set, bypassing high-level libraries to interface directly with simulated hardware.

---

## 🎮 Project Overview

Developed within the **MARS (MIPS Assembler and Runtime Simulator)** environment, this system demonstrates the transition from abstract game logic to low-level hardware interaction. The architecture utilizes **Memory Mapped I/O (MMIO)** to facilitate real-time communication between the user's keyboard and a bitmap display, providing a responsive gaming experience.

### Key Technical Highlights:

* 
**Queue-Based Movement:** Snake coordinates are managed using an efficient queue-based data structure at the register level, allowing for  movement updates.
* 
**MMIO Interface:** Real-time directional control via 'W-A-S-D' polling of hardware registers (`0xFFFF0000` and `0xFFFF0004`).
* 
**Dynamic Rendering:** A 256x256 pixel bitmap display (32x32 logical grid) mapped to heap memory base address `0x10008000`.
* 
**Collision Detection:** Integrated logic for detecting boundary breaches, self-collisions, and static obstacles.
* 
**Persistent Storage:** High-score tracking is achieved through binary File I/O system calls, interfacing directly with the host file system.
* 
**Progressive Difficulty:** Three difficulty levels that scale in complexity as the game continues.

  
---


## 🛠️ Technology Stack
* 
**Language:** MIPS Assembly (RISC Architecture).
* 
**Simulator:** MARS 4.5 (MIPS Assembler and Runtime Simulator).
* 
**Graphics:** MARS Bitmap Display Tool.
* 
**Input:** Keyboard and Display MMIO Simulator.
* 
**Memory Management:** Heap memory for display buffer and queue management.



---

## 📐 System Architecture

The software follows a modular procedural approach, ensuring efficient CPU execution cycles and minimal graphical flickering.

### Module Breakdown:
1. 
**Input Handling:** Polls MMIO registers to detect user input and updates direction vectors while preventing illegal 180-degree turns.
2. 
**Core Engine:** Manages snake position via parallel arrays, updating "head" and "tail" pointers rather than shifting entire data sets.
3. 
**Collision Logic:** A hierarchical checking strategy validating boundary conditions, self-collision, and obstacle collision in order of performance optimization.
4. 
**Rendering Engine:** Direct manipulation of memory addresses to write pixel data to the display buffer.



---

## 🚀 Getting Started

### 1. MARS Configuration

To run this game correctly, configure the **Bitmap Display** tool in MARS as follows:
* 
**Unit Width/Height:** 8 
* 
**Display Width/Height:** 256 
* 
**Base Address:** `0x10008000` (heap) 


### 2. Execution

1. Open `snake_game.asm` in MARS.
2. Assemble the code (`F3`).
3. Connect the **Bitmap Display** and **Keyboard and Display MMIO Simulator** from the *Tools* menu.
4. Run the program (`F5`).
5. Use **W-A-S-D** keys in the MMIO text area to control the snake.



---

## 📖 Theoretical Foundation

This project serves as a practical implementation of core principles detailed in:

* 
*Digital Design and Computer Architecture* by Harris & Harris.

* 
*Computer Organization and Design: The Hardware/Software Interface* by Patterson & Hennessy.

* 
*Computer Organization and Architecture* by Stallings.
