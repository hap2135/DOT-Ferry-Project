# AT client test firmware: exposes the nRF9151 modem's AT interface on the
# console UART (COM port, 115200 8N1) for bring-up and SIM/connectivity checks.
# Based on Circuit Dojo's samples/at_client; main.c comes from NCS.
cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(dot_ferry_at_client)

target_sources(app PRIVATE
	${ZEPHYR_NRF_MODULE_DIR}/samples/cellular/at_client/src/main.c
	src/startup.c
)
