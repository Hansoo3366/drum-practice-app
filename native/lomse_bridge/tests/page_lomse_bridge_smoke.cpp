#include "page_lomse_bridge.h"

#include <cassert>
#include <cstdint>
#include <cstring>
#include <string>

namespace {

constexpr char kMusicXml[] = R"xml(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><rest/><duration>3</duration><type>half</type></note>
    </measure>
  </part>
</score-partwise>)xml";

std::string last_error(page_lomse_session_t session) {
  const char* error = page_lomse_session_last_error(session);
  return error == nullptr ? std::string() : std::string(error);
}

}  // namespace

int main() {
  assert(page_lomse_bridge_abi_version() == PAGE_LOMSE_BRIDGE_ABI_VERSION);

  page_lomse_session_t session = page_lomse_session_create();
  assert(session != nullptr);

  std::uint64_t revision = 0;
  assert(page_lomse_session_load_musicxml(
             session,
             reinterpret_cast<const std::uint8_t*>(kMusicXml),
             std::strlen(kMusicXml),
             &revision) == PAGE_LOMSE_STATUS_OK);
  assert(revision == 1);

  std::uint8_t* exported = nullptr;
  std::size_t exported_size = 0;
  assert(page_lomse_session_export_musicxml(
             session,
             &exported,
             &exported_size,
             &revision) == PAGE_LOMSE_STATUS_OK);
  assert(exported != nullptr);
  assert(exported_size > 0);
  const std::string exported_xml(
      reinterpret_cast<const char*>(exported), exported_size);
  assert(exported_xml.find("score-partwise") != std::string::npos);
  page_lomse_buffer_free(exported);

  constexpr char kInsert[] =
      R"json({"action":"insert_ldp","values":{"source":"(n D4 q v1 p1)"}})json";
  const page_lomse_status_t edit_status = page_lomse_session_execute_json(
      session,
      reinterpret_cast<const std::uint8_t*>(kInsert),
      std::strlen(kInsert),
      &revision);
  assert(edit_status == PAGE_LOMSE_STATUS_OK);
  assert(revision == 2);

  assert(page_lomse_session_undo(session, &revision) == PAGE_LOMSE_STATUS_OK);
  assert(revision == 3);
  assert(page_lomse_session_redo(session, &revision) == PAGE_LOMSE_STATUS_OK);
  assert(revision == 4);
  assert(last_error(session).empty());

  page_lomse_session_dispose(session);
  return 0;
}
