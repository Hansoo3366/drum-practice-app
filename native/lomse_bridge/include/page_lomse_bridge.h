#ifndef PAGE_A_DIDDLE_LOMSE_BRIDGE_H_
#define PAGE_A_DIDDLE_LOMSE_BRIDGE_H_

// Stable C ABI between the piano Flutter flavor and the Lomse C++ runtime.
// Do not expose Lomse headers, Imo* pointers, std::string, or STL containers
// through this header. The implementation owns all native objects and memory.

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PAGE_LOMSE_BRIDGE_ABI_VERSION 1u

typedef void* page_lomse_session_t;

typedef enum page_lomse_status {
  PAGE_LOMSE_STATUS_OK = 0,
  PAGE_LOMSE_STATUS_INVALID_ARGUMENT = 1,
  PAGE_LOMSE_STATUS_NOT_LOADED = 2,
  PAGE_LOMSE_STATUS_PARSE_ERROR = 3,
  PAGE_LOMSE_STATUS_EDIT_ERROR = 4,
  PAGE_LOMSE_STATUS_NO_HISTORY = 5,
  PAGE_LOMSE_STATUS_INTERNAL_ERROR = 6,
  PAGE_LOMSE_STATUS_UNSUPPORTED_COMMAND = 7,
} page_lomse_status_t;

// Returns the ABI version expected by the Dart FFI bindings.
uint32_t page_lomse_bridge_abi_version(void);

// Creates an empty, single-threaded session. The caller must serialize all
// calls for a given handle and eventually call page_lomse_session_dispose().
page_lomse_session_t page_lomse_session_create(void);

// All byte ranges are UTF-8 and are not required to be NUL terminated.
page_lomse_status_t page_lomse_session_load_musicxml(
    page_lomse_session_t session,
    const uint8_t* musicxml,
    size_t musicxml_size,
    uint64_t* out_revision);

// The JSON command contains AppElementId/EventLocator plus musical values.
// LDP/LMD conversion and Lomse command construction stay inside the bridge.
page_lomse_status_t page_lomse_session_execute_json(
    page_lomse_session_t session,
    const uint8_t* command_json,
    size_t command_json_size,
    uint64_t* out_revision);

page_lomse_status_t page_lomse_session_undo(
    page_lomse_session_t session,
    uint64_t* out_revision);

page_lomse_status_t page_lomse_session_redo(
    page_lomse_session_t session,
    uint64_t* out_revision);

// On success, *out_musicxml is allocated by the bridge and must be released
// with page_lomse_buffer_free(). The returned revision matches the exported
// document snapshot.
page_lomse_status_t page_lomse_session_export_musicxml(
    page_lomse_session_t session,
    uint8_t** out_musicxml,
    size_t* out_musicxml_size,
    uint64_t* out_revision);

// Returns a borrowed UTF-8 error string. It remains valid until the next call
// on this session or until the session is disposed. Copy it immediately.
const char* page_lomse_session_last_error(page_lomse_session_t session);

void page_lomse_buffer_free(void* buffer);
void page_lomse_session_dispose(page_lomse_session_t session);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // PAGE_A_DIDDLE_LOMSE_BRIDGE_H_
