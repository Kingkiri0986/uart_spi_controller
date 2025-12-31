# UART to SPI Controller

A hardware/firmware implementation that bridges UART and SPI protocols, enabling control of SPI devices through a simple UART interface.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Hardware Requirements](#hardware-requirements)
- [Pin Configuration](#pin-configuration)
- [Installation](#installation)
- [Usage](#usage)
- [Command Protocol](#command-protocol)
- [Examples](#examples)
- [Technical Specifications](#technical-specifications)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project implements a UART to SPI controller that acts as an SPI master, allowing you to communicate with SPI slave devices using simple UART commands. Perfect for debugging, testing, and interfacing with SPI peripherals through a serial terminal or USB-to-serial adapter.

## ✨ Features

- **UART Interface**
  - Configurable baud rates: 9600, 19200, 38400, 57600, 115200
  - 8 data bits, 1 stop bit, no parity (8N1)
  - Command-based protocol for easy control

- **SPI Master Mode**
  - Configurable clock speeds
  - Support for all SPI modes (0, 1, 2, 3)
  - CPOL and CPHA configuration
  - Multi-slave support via chip select

- **Additional Features**
  - Data buffering for reliable transmission
  - Error detection and reporting
  - Status feedback
  - Reset and initialization commands

## 🔧 Hardware Requirements

- Microcontroller/FPGA (specify: e.g., Arduino Uno, STM32, Xilinx FPGA)
- USB-to-UART adapter (if not built-in)
- SPI slave device(s) for testing
- Connecting wires/breadboard

## 📌 Pin Configuration

| Function | Pin | Description |
|----------|-----|-------------|
| UART RX  | [Pin #] | Receive data from host |
| UART TX  | [Pin #] | Transmit data to host |
| SPI MOSI | [Pin #] | Master Out Slave In |
| SPI MISO | [Pin #] | Master In Slave Out |
| SPI SCK  | [Pin #] | Serial Clock |
| SPI CS   | [Pin #] | Chip Select (active low) |
| GND      | [Pin #] | Ground |
| VCC      | [Pin #] | Power supply |

## 💿 Installation

### Prerequisites
```bash
# List any required software, libraries, or tools
# For example:
- Arduino IDE 1.8+ (for Arduino)
- Python 3.x (for test scripts)
- [Specific toolchain for your platform]
```

### Setup Steps

1. **Clone the repository**
```bash
   git clone https://github.com/yourusername/uart_spi_controller.git
   cd uart_spi_controller
```

2. **Open the project**
```bash
   # Instructions specific to your platform
```

3. **Configure settings** (if applicable)
   - Edit `config.h` to set baud rate and SPI parameters
   - Adjust pin mappings if needed

4. **Upload to device**
```bash
   # Upload instructions
```

## 🚀 Usage

### Basic Connection

1. Connect your SPI slave device to the controller's SPI pins
2. Connect the controller to your computer via UART
3. Open a serial terminal (PuTTY, Arduino Serial Monitor, minicom, etc.)
4. Set baud rate to 115200 (or your configured rate)

### Quick Start Example
```bash
# Initialize SPI with mode 0, 1MHz clock
> INIT 0 1000000

# Write single byte (0xAA) to SPI device
> WRITE AA

# Read 4 bytes from SPI device
> READ 4

# Write multiple bytes
> WRITE 01 02 03 04 05
```

## 📡 Command Protocol

### Command Format
Commands are sent as ASCII strings terminated by newline (`\n` or `\r\n`).

### Available Commands

| Command | Format | Description | Example |
|---------|--------|-------------|---------|
| `INIT` | `INIT <mode> <clock>` | Initialize SPI with mode and clock frequency | `INIT 0 1000000` |
| `WRITE` | `WRITE <hex_bytes>` | Write bytes to SPI device | `WRITE AA BB CC` |
| `READ` | `READ <count>` | Read specified number of bytes | `READ 4` |
| `TRANSFER` | `TRANSFER <hex_bytes>` | Full-duplex transfer (write and read) | `TRANSFER 01 02 03` |
| `CS` | `CS <0|1>` | Control chip select (0=active, 1=inactive) | `CS 0` |
| `CONFIG` | `CONFIG <param> <value>` | Configure parameters | `CONFIG MODE 3` |
| `STATUS` | `STATUS` | Get controller status | `STATUS` |
| `RESET` | `RESET` | Reset controller to default state | `RESET` |

### Response Format
```
OK: <response_data>
ERROR: <error_message>
```

### SPI Modes

| Mode | CPOL | CPHA | Description |
|------|------|------|-------------|
| 0    | 0    | 0    | Clock idle low, sample on leading edge |
| 1    | 0    | 1    | Clock idle low, sample on trailing edge |
| 2    | 1    | 0    | Clock idle high, sample on leading edge |
| 3    | 1    | 1    | Clock idle high, sample on trailing edge |

## 💡 Examples

### Example 1: Reading from an EEPROM
```bash
# Initialize SPI Mode 0, 1MHz
> INIT 0 1000000
OK: SPI initialized

# Activate chip select
> CS 0
OK: CS active

# Send READ command (0x03) followed by address (0x000000)
> TRANSFER 03 00 00 00 00 00 00 00
OK: FF FF FF FF AA BB CC DD

# Deactivate chip select
> CS 1
OK: CS inactive
```

### Example 2: Writing to SPI Flash
```bash
# Initialize
> INIT 0 2000000
OK: SPI initialized

# Enable write
> CS 0
> WRITE 06
OK: Wrote 1 bytes
> CS 1

# Write data
> CS 0
> WRITE 02 00 10 00 48 65 6C 6C 6F
OK: Wrote 9 bytes
> CS 1
```

### Example 3: Communicating with an ADC
```bash
# Initialize SPI
> INIT 1 500000
OK: SPI initialized

# Read ADC value (12-bit)
> CS 0
> READ 2
OK: 0F A3
> CS 1
```

## 📊 Technical Specifications

- **UART**
  - Baud rate range: 9600 - 115200 bps
  - Data format: 8N1
  - Buffer size: 256 bytes

- **SPI**
  - Clock frequency: up to X MHz
  - Supported modes: 0, 1, 2, 3
  - Max transfer size: X bytes
  - Number of CS lines: X

- **Performance**
  - Command response time: < X ms
  - Maximum throughput: X kbps

## 🐛 Troubleshooting

### Issue: No response from controller
- Check UART connection and baud rate settings
- Verify power supply
- Try sending `RESET` command

### Issue: SPI communication errors
- Verify SPI mode matches slave device requirements
- Check clock frequency compatibility
- Ensure proper wiring and signal integrity
- Verify chip select timing

### Issue: Incorrect data received
- Check endianness requirements
- Verify SPI mode (CPOL/CPHA)
- Ensure adequate delays between commands

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## 👤 Author

**Your Name**
- GitHub: [@Kingkiri0986](https://github.com/Kingkiri0986)
- Email: paramtap0809@gmail.com