#pragma once

#include <stdbool.h>
#include <stdint.h>

const char *localsendcore_version(void);
bool localsendcore_is_available(void);
const char *localsendcore_last_error(void);
void localsendcore_clear_last_error(void);
void localsendcore_string_free(char *pointer);
char *localsendcore_discovered_devices_json(void);
void localsendcore_refresh_discovery(void);
int32_t localsendcore_set_receive_directory(const char *path);
int32_t localsendcore_set_receive_pin(const char *pin);
int32_t localsendcore_configure_tls_identity(const char *directory, const char *common_name);
char *localsendcore_pending_receive_json(void);
char *localsendcore_receive_progress_json(void);
char *localsendcore_send_progress_json(void);
int32_t localsendcore_decide_receive(const char *request_id, bool accepted);
void localsendcore_cancel_send(void);
void localsendcore_cancel_receive(void);
int32_t localsendcore_send_files_json(
    const char *target_ip,
    uint16_t target_port,
    const char *target_protocol,
    const char *target_alias,
    const char *target_pin,
    const char *sender_alias,
    uint16_t sender_port,
    const char *sender_protocol,
    const char *sender_device_model,
    uint8_t sender_device_type,
    const char *sender_token,
    const char *files_json
);
int32_t localsendcore_send_file(
    const char *target_ip,
    uint16_t target_port,
    const char *target_protocol,
    const char *sender_alias,
    uint16_t sender_port,
    const char *sender_device_model,
    uint8_t sender_device_type,
    const char *sender_token,
    const char *file_path,
    const char *file_name,
    const char *file_type
);
int32_t localsendcore_start_server(
    uint16_t port,
    const char *alias,
    const char *device_model,
    uint8_t device_type,
    const char *token,
    bool use_tls
);
void localsendcore_stop_server(void);
bool localsendcore_is_server_running(void);
