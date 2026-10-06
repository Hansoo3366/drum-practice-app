"""Conservative pixel evidence for preserving GRID-stage barline candidates.

This never draws a line or creates a symbol. A candidate with attached head,
beam, overhang, incomplete vertical stroke or non-five-line staff is rejected.
"""
from __future__ import annotations

import copy
import io
import math
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


def _line_y(line: ET.Element, x: float) -> float:
    points = [(float(p.get('x')), float(p.get('y'))) for p in line.findall('point')]
    if len(points) < 2:
        raise ValueError('missing staff geometry')
    for a, b in zip(points, points[1:]):
        if x <= b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
    a, b = points[-2:]
    return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])


def _barline_evidence(image, staff: ET.Element, bar: ET.Element) -> dict | None:
    lines = staff.findall('lines/line')
    median = bar.find('median')
    if len(lines) != 5 or bar.get('shape') != 'THIN_BARLINE' or median is None:
        return None
    a, b = median.find('p1'), median.find('p2')
    if a is None or b is None:
        return None
    x = (float(a.get('x')) + float(b.get('x'))) / 2
    top, bottom = _line_y(lines[0], x), _line_y(lines[-1], x)
    il = (bottom - top) / 4
    width = float(bar.get('width', '0'))
    if il < 8 or not (1 <= width <= .35 * il) or abs(float(a.get('x')) - float(b.get('x'))) > .1 * il:
        return None
    if abs(float(a.get('y')) - top) > .2 * il or abs(float(b.get('y')) - bottom) > .2 * il:
        return None
    # Do not freeze an isolated candidate that the recognizer already distrusts.
    if float(bar.get('grade', '0')) < .65:
        return None
    y0, y1 = math.ceil(top), math.floor(bottom)
    radius = math.ceil(.9 * il)
    band = math.ceil(width / 2) + 1
    if x - radius < 0 or x + radius >= image.width or y0 - radius < 0 or y1 + radius >= image.height:
        return None
    pixels = image.load()
    def ink(xx, yy):
        return pixels[xx, yy] < 128
    cx = round(x)
    # GRID's line spline can drift a few pixels from the actual ink (notably
    # the bottom line beside ledgers). Verify thin horizontal ink on BOTH
    # sides instead of widening a geometric mask until a head fits in it.
    side_x = [xx for xx in range(cx-radius, cx+radius+1) if abs(xx-x) > band]
    staff_rows = set()
    centers = []
    for line in lines:
        ly = _line_y(line, x)
        rows = [yy for yy in range(math.floor(ly-.3*il), math.ceil(ly+.3*il)+1)
                if sum(ink(xx, yy) for xx in side_x) >= .95 * len(side_x)]
        if not rows or len(rows) > .45*il or rows != list(range(min(rows), max(rows)+1)):
            return None
        centers.append((min(rows)+max(rows))/2)
        # At most two raster-fringe pixels, with a hard 45%-space mask cap;
        # never widen through a head or an entire staff gap.
        fringe = min(2, max(0, math.floor((.45*il-len(rows))/2)))
        staff_rows.update(range(min(rows)-fringe, max(rows)+fringe+1))
    y0, y1 = math.ceil(centers[0]), math.floor(centers[-1])
    coverage = sum(any(ink(xx, yy) for xx in range(cx-1, cx+2)) for yy in range(y0, y1+1)) / (y1-y0+1)
    if coverage < .98:
        return None
    # Skip only image-verified staff ink, not entire staff spaces.
    for xx in range(cx-radius, cx+radius+1):
        if abs(xx-x) <= band:
            continue
        for yy in range(y0, y1+1):
            if yy in staff_rows:
                continue
            if ink(xx, yy):
                return None
    # Stems whose head is outside the staff and stems extending past the
    # staff cannot pass merely because their inside segment is straight.
    for yy in list(range(y0-radius, min(staff_rows))) + list(range(max(staff_rows)+1, y1+radius+1)):
        if any(ink(xx, yy) for xx in range(cx-band, cx+band+1)):
            return None
    return {'id': bar.get('id'), 'x': round(x, 3), 'coverage': round(coverage, 4),
            'evidence': 'existing-grid-bar/full-stroke/no-attached-ink/no-overhang'}


def _header_left_evidence(image, staff: ET.Element, reference: ET.Element) -> dict | None:
    """Verify a clef body cut out of the engine's header search rectangle.

    Only the search boundary is recovered. We do NOT assign a clef, key,
    octave or pitch: Audiveris must recognize these again from the pixels.
    A high-confidence ordinary G clef from the same page is the reference.
    """
    from omr_marks import _shape_bits, _dice

    lines = staff.findall('lines/line')
    if len(lines) != 5:
        return None
    left = float(staff.get('left'))
    top = _line_y(lines[0], left)
    il = (_line_y(lines[-1], left)-top)/4
    refs = []
    for node in reference.iter('clef'):
        bounds = node.find('bounds')
        if node.get('shape') != 'G_CLEF' or float(node.get('grade', '0')) < .7 or bounds is None:
            continue
        x, y, w, h = (round(float(bounds.get(k))) for k in ('x', 'y', 'w', 'h'))
        if not (2.1*il < w < 3*il and 6*il < h < 7.2*il):
            continue
        refs.append((w, h, _shape_bits(image, (x,y,x+w,y+h)),
                     [p < 128 for p in image.crop((x,y-round(il),x+w,y+h+round(il))).getdata()]))
    if not refs:
        return None
    # A correct header already contains the entire clef. Search only for a
    # body which begins to the LEFT of the clipped header, within 3 spaces.
    best = None
    pad = round(il)
    for w, h, bits, full in refs:
        for x in range(max(0, math.floor(left-3*il)), math.floor(left)):
            for y in range(max(pad, math.floor(top-2*il)), math.ceil(top-.5*il)):
                score = _dice(bits, _shape_bits(image, (x,y,x+w,y+h)))
                if score < .96:
                    continue
                trial = [p < 128 for p in image.crop((x,y-pad,x+w,y+h+pad)).getdata()]
                pixel_score = _dice(full, trial)
                if pixel_score >= .92 and (best is None or (score,pixel_score) > best[:2]):
                    best = (score,pixel_score,x,y)
    if best is None:
        return None
    score, pixel_score, x, y = best
    new_left = math.floor(x-.7*il)
    if new_left < 0 or left-new_left < .5*il:
        return None
    # The five printed staff lines must actually extend across the proposed
    # margin. Extending an XML spline without this evidence is forbidden.
    for line in lines:
        yy = _line_y(line, new_left)
        rows = range(max(0, math.floor(yy-.25*il)), min(image.height,math.ceil(yy+.25*il)+1))
        coverage = max(sum(image.getpixel((xx,row)) < 128 for xx in range(new_left, math.ceil(left)))
                       / (math.ceil(left)-new_left) for row in rows)
        if coverage < .95:
            return None
    return {'kind': 'header-left', 'staff': staff.get('id'), 'before': left, 'after': new_left,
            'shapeScore': round(score,4), 'pixelScore': round(pixel_score,4),
            'evidence': 'same-page-clef-body/outside-header/five-printed-lines'}


def _preserve_grid_barlines(source: Path, destination: Path, reference_book: Path | None = None) -> list[dict]:
    """Write a NEW candidate book, preserving the original bytes and symbols.

    Intended only for isolated experiments until full candidate-regression
    gates have passed. Never apply this to an already transcribed book.
    """
    from PIL import Image

    if destination.exists() or source.resolve() == destination.resolve():
        raise ValueError('candidate destination must be new')
    changes = []
    with zipfile.ZipFile(source) as archive:
        book = ET.fromstring(archive.read('book.xml'))
        for stub in book.findall('sheet'):
            steps = (stub.findtext('steps') or '').split()
            if steps != ['LOAD', 'BINARY', 'SCALE', 'GRID']:
                raise ValueError('only untouched GRID-stage books are eligible')
    references = {}
    if reference_book is not None:
        with zipfile.ZipFile(source) as grid, zipfile.ZipFile(reference_book) as reference:
            for name in grid.namelist():
                if name.endswith('.xml') and '/sheet#' in name:
                    prefix = name.rsplit('/',1)[0]
                    if grid.read(prefix+'/BINARY.png') != reference.read(prefix+'/BINARY.png'):
                        raise ValueError('reference must use the identical source page pixels')
                    references[name] = ET.fromstring(reference.read(name))
    with zipfile.ZipFile(source) as archive, zipfile.ZipFile(destination, 'x') as outgoing:
        for item in archive.infolist():
            data = archive.read(item.filename)
            if item.filename.endswith('.xml') and '/sheet#' in item.filename:
                sheet = ET.fromstring(data)
                prefix = item.filename.rsplit('/', 1)[0]
                with Image.open(io.BytesIO(archive.read(prefix + '/BINARY.png'))) as original:
                    image = original.convert('L')
                for system in sheet.iter('system'):
                    staves = {s.get('id'): s for s in system.iter('staff')}
                    for bar in system.iter('barline'):
                        staff = staves.get(bar.get('staff'))
                        if staff is None:
                            continue
                        evidence = _barline_evidence(image, staff, bar)
                        if evidence is not None and bar.get('frozen') != 'true':
                            bar.set('frozen', 'true')
                            changes.append(dict(evidence, sheet=prefix, system=system.get('id'), staff=staff.get('id')))
                    if item.filename in references:
                        for staff in staves.values():
                            evidence = _header_left_evidence(image, staff, references[item.filename])
                            if evidence is None:
                                continue
                            new_left = evidence['after']
                            for line in staff.findall('lines/line'):
                                line.insert(0, ET.Element('point', x=str(new_left), y=str(_line_y(line,new_left))))
                            staff.set('left', str(new_left))
                            changes.append(dict(evidence, sheet=prefix, system=system.get('id')))
                data = ET.tostring(sheet, encoding='utf-8', xml_declaration=True)
            # ZipFile mutates ZipInfo offsets on write. Do not mutate the
            # source archive's index before later BINARY reads.
            outgoing.writestr(copy.copy(item), data)
    return changes
