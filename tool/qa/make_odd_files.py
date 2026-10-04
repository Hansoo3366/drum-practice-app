"""Files a careless or unlucky user could pick, for import and conversion.

  make_odd_files.py DIRECTORY

Broken, empty, mislabelled and extreme scores. Push them to the device's
Download folder and pick them in the app: every one must end in a readable
message or a usable score, never a crash or a stuck screen.
"""
import os
import sys

HEAD = ('<?xml version="1.0" encoding="UTF-8"?>\n<score-partwise version="4.0">'
        '<part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>')


def note(step="C", duration=4, kind="whole"):
    return (f"<note><pitch><step>{step}</step><octave>4</octave></pitch>"
            f"<duration>{duration}</duration><voice>1</voice><type>{kind}</type></note>")


def score(measures, title=None, attributes=None):
    attributes = attributes or ("<attributes><divisions>1</divisions><time><beats>4</beats>"
                                "<beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line>"
                                "</clef></attributes>")
    work = f"<work><work-title>{title}</work-title></work>" if title else ""
    head = HEAD.replace("<part-list>", work + "<part-list>")
    body = "".join(f'<measure number="{i + 1}">{attributes if i == 0 else ""}{m}</measure>'
                   for i, m in enumerate(measures))
    return f'{head}<part id="P1">{body}</part></score-partwise>\n'


FILES = {
    # Not a score at all.
    "odd_empty.musicxml": b"",
    "odd_text.musicxml": b"this is not xml at all\n",
    "odd_binary.musicxml": bytes(range(256)) * 40,
    "odd_truncated.musicxml": score([note()] * 8)[:400].encode(),
    "odd_html.xml": b"<html><body><h1>404</h1></body></html>",
    "odd_empty.pdf": b"",
    "odd_text.pdf": b"%PDF-not really a pdf\n",
    "odd_png_named.pdf": b"\x89PNG\r\n\x1a\n" + b"\0" * 64,
    # Scores at the edges.
    "odd_no_measures.musicxml": (HEAD + '<part id="P1"></part></score-partwise>').encode(),
    "odd_no_notes.musicxml": score([""] * 4).encode(),
    "odd_one_bar.musicxml": score([note()]).encode(),
    "odd_long_title.musicxml": score([note()] * 4, title="아주 긴 제목 " * 40).encode(),
    "odd_symbols_title.musicxml": score([note()] * 4, title="&lt;b&gt;&amp;&quot;'/\\:*?|").encode(),
    "odd_zero_divisions.musicxml": score(
        [note()] * 2,
        attributes="<attributes><divisions>0</divisions><time><beats>0</beats><beat-type>0</beat-type>"
                   "</time><clef><sign>G</sign><line>2</line></clef></attributes>").encode(),
    "odd_huge_time.musicxml": score(
        [note(duration=64)] * 3,
        attributes="<attributes><divisions>4</divisions><time><beats>64</beats><beat-type>4</beat-type>"
                   "</time><clef><sign>G</sign><line>2</line></clef></attributes>").encode(),
    "odd_500_bars.musicxml": score([note("CDEFGAB"[i % 7]) for i in range(500)]).encode(),
    "odd_all_pickups.musicxml": score([note(duration=1, kind="quarter")] * 6).replace(
        '<measure number="', '<measure implicit="yes" number="').encode(),
    "odd_negative_duration.musicxml": score([note(duration=-4), note()]).encode(),
    "odd_two_parts_uneven.musicxml": (
        HEAD.replace("</part-list>", '<score-part id="P2"><part-name>W</part-name></score-part></part-list>')
        + '<part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes>'
        + note() + '</measure><measure number="2">' + note() + '</measure></part>'
        + '<part id="P2"><measure number="1"><attributes><divisions>1</divisions></attributes>'
        + note() + "</measure></part></score-partwise>").encode(),
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, data in FILES.items():
        with open(os.path.join(out, name), "wb") as file:
            file.write(data)
    print(len(FILES), "files in", out)


main()
