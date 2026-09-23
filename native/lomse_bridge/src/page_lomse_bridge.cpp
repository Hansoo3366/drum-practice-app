#include "page_lomse_bridge.h"

#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>
#include <optional>
#include <string>
#include <string_view>

#include <lomse_command.h>
#include <lomse_document_cursor.h>
#include <lomse_doorway.h>
#include <lomse_graphic_view.h>
#include <lomse_interactor.h>
#include <lomse_mxl_exporter.h>
#include <lomse_presenter.h>

namespace {

using namespace lomse;

struct Session {
  Session() : doorway(std::make_unique<LomseDoorway>()) {
    doorway->init_library(k_pix_format_rgba32, 96);
  }

  ~Session() { delete presenter; }

  std::unique_ptr<LomseDoorway> doorway;
  Presenter* presenter = nullptr;
  std::uint64_t revision = 0;
  std::string last_error;
};

void set_error(Session* session, const std::string& error) {
  if (session != nullptr) {
    session->last_error = error;
  }
}

void clear_error(Session* session) {
  if (session != nullptr) {
    session->last_error.clear();
  }
}

SpInteractor get_interactor(Session* session) {
  if (session == nullptr || session->presenter == nullptr) {
    return {};
  }
  return session->presenter->get_interactor_shared_ptr(0);
}

bool has_json_string(std::string_view json, std::string_view key) {
  return json.find(std::string("\"") + std::string(key) + "\"") !=
      std::string_view::npos;
}

std::optional<std::string> json_string_field(
    std::string_view json,
    std::string_view key) {
  const std::string quoted_key = std::string("\"") + std::string(key) + "\"";
  const std::size_t key_position = json.find(quoted_key);
  if (key_position == std::string_view::npos) {
    return std::nullopt;
  }

  std::size_t cursor = key_position + quoted_key.size();
  while (cursor < json.size() &&
         (json[cursor] == ' ' || json[cursor] == '\t' ||
          json[cursor] == '\r' || json[cursor] == '\n')) {
    ++cursor;
  }
  if (cursor >= json.size() || json[cursor] != ':') {
    return std::nullopt;
  }
  ++cursor;
  while (cursor < json.size() &&
         (json[cursor] == ' ' || json[cursor] == '\t' ||
          json[cursor] == '\r' || json[cursor] == '\n')) {
    ++cursor;
  }
  if (cursor >= json.size() || json[cursor] != '"') {
    return std::nullopt;
  }
  ++cursor;

  std::string value;
  while (cursor < json.size()) {
    const char current = json[cursor++];
    if (current == '"') {
      return value;
    }
    if (current != '\\') {
      value.push_back(current);
      continue;
    }
    if (cursor >= json.size()) {
      return std::nullopt;
    }
    const char escaped = json[cursor++];
    switch (escaped) {
      case '"':
      case '\\':
      case '/':
        value.push_back(escaped);
        break;
      case 'b':
        value.push_back('\b');
        break;
      case 'f':
        value.push_back('\f');
        break;
      case 'n':
        value.push_back('\n');
        break;
      case 'r':
        value.push_back('\r');
        break;
      case 't':
        value.push_back('\t');
        break;
      default:
        return std::nullopt;
    }
  }
  return std::nullopt;
}

page_lomse_status_t require_loaded(Session* session, const char* operation) {
  if (session == nullptr || session->presenter == nullptr) {
    if (session != nullptr) {
      set_error(session, std::string(operation) + " requires a loaded score.");
    }
    return PAGE_LOMSE_STATUS_NOT_LOADED;
  }
  return PAGE_LOMSE_STATUS_OK;
}

page_lomse_status_t export_musicxml(
    Session* session,
    std::uint8_t** out_musicxml,
    std::size_t* out_musicxml_size,
    std::uint64_t* out_revision) {
  if (out_musicxml == nullptr || out_musicxml_size == nullptr ||
      out_revision == nullptr) {
    set_error(session, "Export output pointers are required.");
    return PAGE_LOMSE_STATUS_INVALID_ARGUMENT;
  }
  *out_musicxml = nullptr;
  *out_musicxml_size = 0;
  *out_revision = session == nullptr ? 0 : session->revision;

  const page_lomse_status_t loaded = require_loaded(session, "Export");
  if (loaded != PAGE_LOMSE_STATUS_OK) {
    return loaded;
  }

  try {
    const ADocument document = session->presenter->get_document();
    const AScore score = document.first_score();
    if (!document.is_valid() || !score.is_valid()) {
      set_error(session, "Lomse did not expose a valid score for export.");
      return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
    }

    MxlExporter exporter(*session->doorway->get_library_scope());
    const std::string musicxml = exporter.get_source(score);
    if (musicxml.empty()) {
      set_error(session, "Lomse exported an empty MusicXML document.");
      return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
    }

    auto* buffer = static_cast<std::uint8_t*>(std::malloc(musicxml.size()));
    if (buffer == nullptr) {
      set_error(session, "Could not allocate MusicXML export buffer.");
      return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
    }
    std::memcpy(buffer, musicxml.data(), musicxml.size());
    *out_musicxml = buffer;
    *out_musicxml_size = musicxml.size();
    *out_revision = session->revision;
    clear_error(session);
    return PAGE_LOMSE_STATUS_OK;
  } catch (const std::exception& error) {
    set_error(session, std::string("MusicXML export failed: ") + error.what());
    return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
  } catch (...) {
    set_error(session, "MusicXML export failed with an unknown error.");
    return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
  }
}

}  // namespace

extern "C" {

std::uint32_t page_lomse_bridge_abi_version(void) {
  return PAGE_LOMSE_BRIDGE_ABI_VERSION;
}

page_lomse_session_t page_lomse_session_create(void) {
  try {
    return new Session();
  } catch (...) {
    return nullptr;
  }
}

page_lomse_status_t page_lomse_session_load_musicxml(
    page_lomse_session_t raw_session,
    const std::uint8_t* musicxml,
    std::size_t musicxml_size,
    std::uint64_t* out_revision) {
  auto* session = static_cast<Session*>(raw_session);
  if (session == nullptr || musicxml == nullptr || musicxml_size == 0 ||
      out_revision == nullptr) {
    set_error(session, "MusicXML and output revision are required.");
    return PAGE_LOMSE_STATUS_INVALID_ARGUMENT;
  }

  try {
    std::string source(reinterpret_cast<const char*>(musicxml), musicxml_size);
    Presenter* next = session->doorway->new_document(
        k_view_vertical_book,
        source,
        Document::k_format_mxl);
    if (next == nullptr) {
      set_error(session, "Lomse could not create a MusicXML document.");
      return PAGE_LOMSE_STATUS_PARSE_ERROR;
    }

    auto interactor = next->get_interactor_shared_ptr(0);
    if (!interactor) {
      delete next;
      set_error(session, "Lomse did not create an editor interactor.");
      return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
    }
    interactor->set_operating_mode(Interactor::k_mode_edition);

    delete session->presenter;
    session->presenter = next;
    ++session->revision;
    *out_revision = session->revision;
    clear_error(session);
    return PAGE_LOMSE_STATUS_OK;
  } catch (const std::exception& error) {
    set_error(session, std::string("MusicXML load failed: ") + error.what());
    return PAGE_LOMSE_STATUS_PARSE_ERROR;
  } catch (...) {
    set_error(session, "MusicXML load failed with an unknown error.");
    return PAGE_LOMSE_STATUS_PARSE_ERROR;
  }
}

page_lomse_status_t page_lomse_session_execute_json(
    page_lomse_session_t raw_session,
    const std::uint8_t* command_json,
    std::size_t command_json_size,
    std::uint64_t* out_revision) {
  auto* session = static_cast<Session*>(raw_session);
  if (session == nullptr || command_json == nullptr || command_json_size == 0 ||
      out_revision == nullptr) {
    set_error(session, "Command JSON and output revision are required.");
    return PAGE_LOMSE_STATUS_INVALID_ARGUMENT;
  }
  const page_lomse_status_t loaded = require_loaded(session, "Edit");
  if (loaded != PAGE_LOMSE_STATUS_OK) {
    return loaded;
  }

  const std::string_view json(
      reinterpret_cast<const char*>(command_json), command_json_size);
  const auto action = json_string_field(json, "action");
  if (!action) {
    set_error(session, "Edit command action is required.");
    return PAGE_LOMSE_STATUS_INVALID_ARGUMENT;
  }

  // This first bridge slice intentionally supports only an LDP insertion at
  // Lomse's current cursor. AppElementId/EventLocator selection is added in
  // the next slice; it must not be faked with Lomse ImoId values.
  if (*action != "insert_ldp") {
    set_error(session, "Unsupported Lomse edit action: " + *action);
    return PAGE_LOMSE_STATUS_UNSUPPORTED_COMMAND;
  }
  const auto source = json_string_field(json, "source");
  if (!source || source->empty()) {
    set_error(session, "insert_ldp requires a non-empty LDP source value.");
    return PAGE_LOMSE_STATUS_INVALID_ARGUMENT;
  }
  if (has_json_string(json, "target")) {
    set_error(
        session,
        "insert_ldp target mapping is not implemented in this bridge slice.");
    return PAGE_LOMSE_STATUS_UNSUPPORTED_COMMAND;
  }

  try {
    auto interactor = get_interactor(session);
    if (!interactor) {
      set_error(session, "Lomse editor interactor is unavailable.");
      return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
    }
    // Commands operate on the document cursor. A newly imported document has
    // the cursor at the top-level score object, so enter that score before
    // asking CmdAddNoteRest to inspect the current time position.
    DocCursor* cursor = interactor->get_cursor();
    if (cursor == nullptr) {
      set_error(session, "Lomse document cursor is unavailable.");
      return PAGE_LOMSE_STATUS_INTERNAL_ERROR;
    }
    cursor->to_start();
    cursor->enter_element();
    interactor->exec_command(new CmdAddNoteRest(
        *source,
        k_edit_mode_replace,
        "Piano insert"));
    if (!interactor->should_enable_edit_undo()) {
      set_error(session, "Lomse rejected the LDP insertion command.");
      return PAGE_LOMSE_STATUS_EDIT_ERROR;
    }
    ++session->revision;
    *out_revision = session->revision;
    clear_error(session);
    return PAGE_LOMSE_STATUS_OK;
  } catch (const std::exception& error) {
    set_error(session, std::string("Lomse edit failed: ") + error.what());
    return PAGE_LOMSE_STATUS_EDIT_ERROR;
  } catch (...) {
    set_error(session, "Lomse edit failed with an unknown error.");
    return PAGE_LOMSE_STATUS_EDIT_ERROR;
  }
}

page_lomse_status_t page_lomse_session_undo(
    page_lomse_session_t raw_session,
    std::uint64_t* out_revision) {
  auto* session = static_cast<Session*>(raw_session);
  if (out_revision == nullptr) {
    set_error(session, "Undo output revision is required.");
    return PAGE_LOMSE_STATUS_INVALID_ARGUMENT;
  }
  const page_lomse_status_t loaded = require_loaded(session, "Undo");
  if (loaded != PAGE_LOMSE_STATUS_OK) {
    return loaded;
  }
  auto interactor = get_interactor(session);
  if (!interactor || !interactor->should_enable_edit_undo()) {
    set_error(session, "There is no Lomse edit to undo.");
    return PAGE_LOMSE_STATUS_NO_HISTORY;
  }
  interactor->exec_undo();
  ++session->revision;
  *out_revision = session->revision;
  clear_error(session);
  return PAGE_LOMSE_STATUS_OK;
}

page_lomse_status_t page_lomse_session_redo(
    page_lomse_session_t raw_session,
    std::uint64_t* out_revision) {
  auto* session = static_cast<Session*>(raw_session);
  if (out_revision == nullptr) {
    set_error(session, "Redo output revision is required.");
    return PAGE_LOMSE_STATUS_INVALID_ARGUMENT;
  }
  const page_lomse_status_t loaded = require_loaded(session, "Redo");
  if (loaded != PAGE_LOMSE_STATUS_OK) {
    return loaded;
  }
  auto interactor = get_interactor(session);
  if (!interactor || !interactor->should_enable_edit_redo()) {
    set_error(session, "There is no Lomse edit to redo.");
    return PAGE_LOMSE_STATUS_NO_HISTORY;
  }
  interactor->exec_redo();
  ++session->revision;
  *out_revision = session->revision;
  clear_error(session);
  return PAGE_LOMSE_STATUS_OK;
}

page_lomse_status_t page_lomse_session_export_musicxml(
    page_lomse_session_t raw_session,
    std::uint8_t** out_musicxml,
    std::size_t* out_musicxml_size,
    std::uint64_t* out_revision) {
  return export_musicxml(
      static_cast<Session*>(raw_session),
      out_musicxml,
      out_musicxml_size,
      out_revision);
}

const char* page_lomse_session_last_error(page_lomse_session_t raw_session) {
  auto* session = static_cast<Session*>(raw_session);
  return session == nullptr ? nullptr : session->last_error.c_str();
}

void page_lomse_buffer_free(void* buffer) {
  std::free(buffer);
}

void page_lomse_session_dispose(page_lomse_session_t raw_session) {
  delete static_cast<Session*>(raw_session);
}

}  // extern "C"
