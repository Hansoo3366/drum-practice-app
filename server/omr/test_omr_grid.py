import hashlib
import io
import tempfile
import unittest
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from PIL import Image, ImageDraw
from omr_grid import _barline_evidence, _preserve_grid_barlines, _header_left_evidence


class GridBarlineEvidenceTest(unittest.TestCase):
    def fixture(self):
        image = Image.new('L', (160, 180), 255)
        draw = ImageDraw.Draw(image)
        staff = ET.Element('staff', id='1')
        lines = ET.SubElement(staff, 'lines')
        for y in (40, 60, 80, 100, 120):
            draw.rectangle((10, y-1, 150, y+1), fill=0)
            line = ET.SubElement(lines, 'line', thickness='3')
            ET.SubElement(line, 'point', x='10', y=str(y))
            ET.SubElement(line, 'point', x='150', y=str(y))
        draw.rectangle((79, 40, 81, 120), fill=0)
        bar = ET.fromstring('''<barline id="2" staff="1" width="3" grade=".8" shape="THIN_BARLINE">
          <bounds x="79" y="40" w="3" h="81"/><median><p1 x="80" y="40"/><p2 x="80" y="120"/></median></barline>''')
        return image, staff, bar

    def test_complete_isolated_bar_has_pixel_evidence(self):
        image, staff, bar = self.fixture()
        self.assertEqual(_barline_evidence(image, staff, bar)['coverage'], 1)

    def test_staff_spline_drift_uses_actual_ink_not_a_wide_mask(self):
        image, staff, bar = self.fixture()
        for p in staff.findall('lines/line')[-1].findall('point'):
            p.set('y', '123')
        self.assertIsNotNone(_barline_evidence(image, staff, bar))

    def test_full_staff_height_stem_with_attached_head_is_rejected(self):
        image, staff, bar = self.fixture()
        ImageDraw.Draw(image).ellipse((63, 107, 80, 118), fill=0)
        self.assertIsNone(_barline_evidence(image, staff, bar))

    def test_stem_with_head_outside_staff_is_rejected(self):
        image, staff, bar = self.fixture()
        ImageDraw.Draw(image).ellipse((66, 122, 81, 133), fill=0)
        self.assertIsNone(_barline_evidence(image, staff, bar))

    def test_stem_with_beam_is_rejected(self):
        image, staff, bar = self.fixture()
        ImageDraw.Draw(image).rectangle((65, 44, 80, 49), fill=0)
        self.assertIsNone(_barline_evidence(image, staff, bar))

    def test_missing_stroke_is_not_drawn_in(self):
        image, staff, bar = self.fixture()
        ImageDraw.Draw(image).rectangle((79, 67, 81, 74), fill=255)
        self.assertIsNone(_barline_evidence(image, staff, bar))

    def test_low_confidence_non_five_line_and_thick_bars_are_not_frozen(self):
        for attribute, value in (('grade', '.5'), ('shape', 'THICK_BARLINE'), ('width', '20')):
            image, staff, bar = self.fixture()
            bar.set(attribute, value)
            self.assertIsNone(_barline_evidence(image, staff, bar))
        image, staff, bar = self.fixture()
        staff.find('lines').remove(staff.find('lines/line'))
        self.assertIsNone(_barline_evidence(image, staff, bar))

    def book(self, path, steps='LOAD BINARY SCALE GRID'):
        image, staff, bar = self.fixture()
        root = ET.Element('sheet')
        system = ET.SubElement(root, 'system', id='1')
        ET.SubElement(system, 'part').append(staff)
        system.append(bar)
        png = io.BytesIO()
        image.save(png, format='PNG')
        with zipfile.ZipFile(path, 'x') as archive:
            archive.writestr('book.xml', f'<book><sheet number="1"><steps>{steps}</steps></sheet></book>')
            archive.writestr('sheet#1/sheet#1.xml', ET.tostring(root))
            archive.writestr('sheet#1/BINARY.png', png.getvalue())
            archive.writestr('extra.bin', b'preserve-me')

    def test_new_book_retains_original_bytes_images_and_other_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory)/'raw.omr', Path(directory)/'candidate.omr'
            self.book(source)
            digest = hashlib.sha256(source.read_bytes()).digest()
            changes = _preserve_grid_barlines(source, target)
            self.assertEqual(len(changes), 1)
            self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), digest)
            with zipfile.ZipFile(source) as a, zipfile.ZipFile(target) as b:
                for name in ('book.xml', 'sheet#1/BINARY.png', 'extra.bin'):
                    self.assertEqual(a.read(name), b.read(name))
                self.assertEqual(ET.fromstring(b.read('sheet#1/sheet#1.xml')).find('.//barline').get('frozen'), 'true')
                self.assertIsNone(ET.fromstring(a.read('sheet#1/sheet#1.xml')).find('.//barline').get('frozen'))
            with self.assertRaises(ValueError):
                _preserve_grid_barlines(source, target)
            with self.assertRaises(ValueError):
                _preserve_grid_barlines(source, source)

    def test_transcribed_book_is_rejected_without_creating_candidate(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory)/'raw.omr', Path(directory)/'candidate.omr'
            self.book(source, 'LOAD BINARY SCALE GRID HEADERS HEADS STEMS PAGE')
            with self.assertRaises(ValueError):
                _preserve_grid_barlines(source, target)
            self.assertFalse(target.exists())

    def header_fixture(self):
        image = Image.new('L', (300, 530), 255)
        draw = ImageDraw.Draw(image)
        reference = ET.Element('sheet')
        staff = ET.Element('staff', id='1', left='140')
        lines = ET.SubElement(staff, 'lines')
        for base, start in ((100, 96), (350, 26)):
            for yy in range(base, base+81, 20):
                draw.rectangle((start, yy-1, 280, yy+1), fill=0)
                if base == 100:
                    line = ET.SubElement(lines, 'line', thickness='3')
                    ET.SubElement(line, 'point', x='140', y=str(yy))
                    ET.SubElement(line, 'point', x='280', y=str(yy))
        # Same distinctive raster glyph in two header positions. The
        # recognizer's high-confidence G classification is supplied by the
        # reference; the algorithm does not classify this synthetic drawing.
        for xx, yy in ((110,74), (40,324)):
            draw.line((xx+25,yy,xx+25,yy+122), fill=0, width=5)
            draw.ellipse((xx+8,yy+5,xx+35,yy+47), outline=0, width=5)
            draw.ellipse((xx,yy+47,xx+46,yy+94), outline=0, width=5)
            draw.arc((xx+7,yy+94,xx+32,yy+124), 0, 270, fill=0, width=5)
        clef = ET.SubElement(reference, 'clef', shape='G_CLEF', grade='.9', **{'ctx-grade': '.95'})
        ET.SubElement(clef, 'bounds', x='40', y='324', w='48', h='126')
        return image, staff, reference

    def test_clipped_header_is_recovered_only_with_same_page_shape_and_staff_ink(self):
        image, staff, reference = self.header_fixture()
        result = _header_left_evidence(image, staff, reference)
        self.assertIsNotNone(result)
        self.assertLess(result['after'], 110)
        # This is only evidence; it does not rewrite a clef or notes.
        self.assertEqual(staff.get('left'), '140')
        self.assertIsNone(staff.find('header/clef'))

    def test_unprinted_header_margin_is_not_extended(self):
        image, staff, reference = self.header_fixture()
        ImageDraw.Draw(image).rectangle((96,99,139,101), fill=255)
        self.assertIsNone(_header_left_evidence(image, staff, reference))

    def test_no_high_confidence_reference_means_no_header_guess(self):
        image, staff, reference = self.header_fixture()
        reference.find('clef').set('grade','.1')
        self.assertIsNone(_header_left_evidence(image, staff, reference))

    def test_already_complete_header_is_not_changed(self):
        image, staff, reference = self.header_fixture()
        staff.set('left','96')
        self.assertIsNone(_header_left_evidence(image, staff, reference))


if __name__ == '__main__':
    unittest.main()
