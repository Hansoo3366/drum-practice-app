"""Pickup-bar test score: bar 0 pickup, four written lines, a repeat whose
first ending sits inside the third line."""
import sys

STEPS = ["C", "D", "E", "F", "G", "A", "B"]


def note(step, octave, dur, typ, lyric=None):
    text = f"<lyric number=\"1\"><syllabic>single</syllabic><text>{lyric}</text></lyric>" if lyric else ""
    return (f"<note><pitch><step>{step}</step><octave>{octave}</octave></pitch>"
            f"<duration>{dur}</duration><voice>1</voice><type>{typ}</type>{text}</note>")


def harmony(root):
    return f"<harmony><root><root-step>{root}</root-step></root><kind>major</kind></harmony>"


measures = []
line_starts = {5, 9, 13}
for i in range(17):
    number = i  # pickup is written as 0
    attrs = ' implicit="yes"' if i == 0 else ""
    body = ""
    if i in line_starts:
        body += '<print new-system="yes"/>'
    if i == 0:
        body += ("<attributes><divisions>1</divisions><key><fifths>0</fifths></key>"
                 "<time><beats>4</beats><beat-type>4</beat-type></time>"
                 "<clef><sign>G</sign><line>2</line></clef></attributes>")
    if i == 5:
        body += '<barline location="left"><bar-style>heavy-light</bar-style><repeat direction="forward"/></barline>'
    if i == 10:
        body += '<barline location="left"><ending number="1" type="start"/></barline>'
    if i == 11:
        body += '<barline location="left"><ending number="2" type="start"/></barline>'
    if i == 0:
        body += note("G", 4, 1, "quarter", "p")
    else:
        body += harmony(STEPS[i % 7])
        for beat in range(4):
            step = STEPS[(i + beat) % 7]
            # Lyric shows the app's bar count (index + 1) on the first beat.
            body += note(step, 4, 1, "quarter", f"m{i + 1}" if beat == 0 else None)
    if i == 10:
        body += ('<barline location="right"><bar-style>light-heavy</bar-style>'
                 '<ending number="1" type="stop"/><repeat direction="backward"/></barline>')
    if i == 11:
        body += '<barline location="right"><ending number="2" type="discontinue"/></barline>'
    if i == 16:
        body += '<barline location="right"><bar-style>light-heavy</bar-style></barline>'
    measures.append(f'<measure number="{number}"{attrs}>{body}</measure>')

xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<score-partwise version="4.0"><work><work-title>Pickup QA</work-title></work>'
       '<part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>'
       '<part id="P1">\n' + "\n".join(measures) + "\n</part></score-partwise>\n")
open(sys.argv[1], "w", encoding="utf-8").write(xml)
print(len(measures), "measures")
