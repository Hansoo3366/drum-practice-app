"""Colour annotations (OMR spec MODULE-03): pen marks, typed notes and highlighter
on a photographed score are taken out of what the recogniser reads, and kept."""

from __future__ import annotations

import io
import json
import os
import re
import shutil
import subprocess
import tempfile

from pathlib import Path

from omr_rules import _TESSERACT_ENV


# A pixel is coloured when its channels differ by more than this, above the
# cast of the paper itself (a warm photo of white paper is slightly yellow).
_CHROMA_MIN = 40
_CHROMA_OVER_PAPER = 30
# Darker than this is print, whatever its tint: JPEG tints black edges.
_DARK = 80
# Lighter than this (in grey), a coloured pixel is see-through highlighter:
# print shows through it. Ink is darker.
_BRIGHT = 170
# The mean grey of a whole annotation from which it counts as highlighter.
_HIGHLIGHT = 185
# A page is left alone under this share of coloured pixels.
_MIN_SHARE = 0.0002
# A region smaller than this many pixels of the reduced mask is noise.
_MIN_REGION_CELLS = 3
_REGION_GRID = 640


def _enabled() -> bool:
    return os.environ.get("OMR_ANNOTATIONS", "1") != "0"


def _channels(photo):
    """Brightest and darkest channel of every pixel, and their difference."""
    from PIL import ImageChops

    red, green, blue = photo.convert("RGB").split()
    brightest = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    darkest = ImageChops.darker(ImageChops.darker(red, green), blue)
    return brightest, darkest, ImageChops.subtract(brightest, darkest)


def _median(histogram: list[int]) -> int:
    half = sum(histogram) / 2
    running = 0
    for value, count in enumerate(histogram):
        running += count
        if running >= half:
            return value
    return 0


def _separate(photo):
    """The page without its colour annotations, the annotations alone on white,
    their mask, and the mask without the soft edges (the colour itself); None
    when the page has none worth taking out.

    Print under highlighter is kept: only the colour goes. Ink is removed, and
    what it covered is not guessed."""
    from PIL import Image, ImageChops, ImageFilter

    photo = photo.convert("RGB")
    brightest, _darkest, chroma = _channels(photo)
    threshold = max(_CHROMA_MIN, _median(chroma.histogram()) + _CHROMA_OVER_PAPER)
    coloured = chroma.point(lambda value: 255 if value > threshold else 0)
    not_dark = brightest.point(lambda value: 255 if value > _DARK else 0)
    core = ImageChops.darker(coloured, not_dark).filter(ImageFilter.MedianFilter(3))
    # Single coloured pixels are noise; the soft edge of a stroke belongs to it.
    mask = core.filter(ImageFilter.MaxFilter(7))
    share = mask.histogram()[255] / (mask.width * mask.height)
    if share < _MIN_SHARE:
        return None

    # Under highlighter the page keeps its brightness (print stays dark, the
    # highlighted paper turns white); ink goes to white.
    grey = photo.convert("L")
    see_through = ImageChops.darker(
        coloured, grey.point(lambda value: 255 if value >= _BRIGHT else 0)
    ).filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(9))
    white = Image.new("L", photo.size, 255)
    replacement = Image.composite(brightest, white, see_through)
    clean = Image.composite(replacement, grey, mask)
    annotation = Image.composite(photo, Image.new("RGB", photo.size, "white"), mask)
    return clean, annotation, mask, core


def _colour_name(red: float, green: float, blue: float) -> str:
    import colorsys

    hue, _lightness, _saturation = colorsys.rgb_to_hls(red / 255, green / 255, blue / 255)
    degrees = hue * 360
    if degrees < 20 or degrees >= 330:
        return "red"
    if degrees < 45:
        return "orange"
    if degrees < 75:
        return "yellow"
    if degrees < 165:
        return "green"
    if degrees < 265:
        return "blue"
    return "purple"


def _regions(mask, core, annotation, clean) -> list[dict]:
    """Connected annotations as page boxes with their kind and colour."""
    from PIL import ImageFilter, ImageStat

    factor = max(1, max(mask.size) // _REGION_GRID)
    small = mask.reduce(factor) if factor > 1 else mask
    # Letters of one word, and the dots of a dashed mark, are one annotation.
    joined = small.filter(ImageFilter.MaxFilter(5))
    width, height = joined.size
    cells = joined.tobytes()
    seen = bytearray(width * height)
    regions = []
    for start in range(width * height):
        if cells[start] < 32 or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        left = right = start % width
        top = bottom = start // width
        count = 0
        while stack:
            cell = stack.pop()
            x, y = cell % width, cell // width
            count += 1
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            for step in (-1, 1, -width, width):
                other = cell + step
                if other < 0 or other >= width * height or seen[other] or cells[other] < 32:
                    continue
                if step in (-1, 1) and other // width != y:
                    continue
                seen[other] = 1
                stack.append(other)
        if count < _MIN_REGION_CELLS:
            continue
        box = (
            max(0, (left - 1) * factor), max(0, (top - 1) * factor),
            min(mask.width, (right + 2) * factor), min(mask.height, (bottom + 2) * factor),
        )
        part = mask.crop(box)
        covered = part.histogram()[255]
        if covered == 0:
            continue
        colour = core.crop(box)
        if colour.histogram()[255] == 0:
            continue
        mean = ImageStat.Stat(annotation.crop(box), colour).mean
        # Highlighter is light; ink is darker strokes.
        lightness = 0.299 * mean[0] + 0.587 * mean[1] + 0.114 * mean[2]
        kind = "highlight" if lightness >= _HIGHLIGHT else "ink"
        # Ink that touches print may hide some of it; what was there is not known.
        touches = False
        if kind == "ink":
            ring = part.filter(ImageFilter.MaxFilter(7))
            dark = clean.crop(box).point(lambda value: 255 if value < _DARK else 0)
            from PIL import ImageChops

            touches = ImageChops.darker(ring, dark).histogram()[255] > 0
        regions.append({
            "region": {"x": box[0], "y": box[1], "width": box[2] - box[0], "height": box[3] - box[1]},
            "type": kind,
            "color": _colour_name(*mean[:3]),
            "touches_print": touches,
            "text": None,
        })
    regions.sort(key=lambda item: (item["region"]["y"], item["region"]["x"]))
    return regions


def _read_text(tesseract: str | None, annotation, regions: list[dict], workdir: Path) -> None:
    """Fills in what an ink annotation says, where Tesseract can read it."""
    from PIL import ImageOps

    if not tesseract:
        return
    for index, item in enumerate(regions):
        if item["type"] != "ink":
            continue
        box = item["region"]
        if box["height"] < 12 or box["width"] < 12:
            continue
        crop = annotation.crop((box["x"], box["y"], box["x"] + box["width"], box["y"] + box["height"]))
        # Coloured strokes as black on white, large enough to read.
        grey = ImageOps.autocontrast(crop.convert("L"))
        scale = max(1, 64 // max(1, box["height"]))
        if scale > 1:
            grey = grey.resize((grey.width * scale, grey.height * scale))
        target = workdir / f"annotation_{index}.png"
        ImageOps.expand(grey, 12, fill=255).save(target)
        try:
            output = subprocess.run(
                [tesseract, str(target), "stdout", "-l", "kor+eng", "--psm", "7",
                 "-c", "tessedit_create_tsv=1"],
                capture_output=True, text=True, timeout=60, check=False, env=_TESSERACT_ENV,
            ).stdout
        except (OSError, subprocess.TimeoutExpired):
            continue
        words = []
        for row in output.splitlines()[1:]:
            fields = row.split("\t")
            if len(fields) < 12 or not fields[11].strip():
                continue
            try:
                confidence = float(fields[10])
            except ValueError:
                continue
            if confidence >= 50:
                words.append(fields[11].strip())
        # A mark that is not writing (a cross, a circle) reads as nothing sure.
        text = " ".join(words)
        if re.search(r"[0-9A-Za-z가-힣]", text):
            item["text"] = text


def _pdf_pages(data: bytes) -> int:
    return len(re.findall(rb"/Type\s*/Page(?![s\w])", data))


def _pdf_photos(data: bytes) -> list[bytes]:
    photos = []
    for match in re.finditer(rb"/DCTDecode[^>]*>>\s*stream\r?\n", data):
        end = data.find(b"endstream", match.end())
        if end > 0 and data[match.end():match.end() + 3] == b"\xff\xd8\xff":
            photos.append(data[match.end():end].rstrip(b"\r\n"))
    return photos


def _upload_pages(source: Path) -> list | None:
    """The pages of an upload as images, for an image or a PDF the app made of
    photos (one photo per page); None for any other PDF, which is left alone."""
    from PIL import Image, ImageOps

    suffix = source.suffix.lower()
    try:
        if suffix in (".jpg", ".jpeg", ".png"):
            page = Image.open(source)
            page.load()
            return [ImageOps.exif_transpose(page)]
        if suffix != ".pdf":
            return None
        data = source.read_bytes()
        photos = _pdf_photos(data)
        if not photos or len(photos) != _pdf_pages(data) or b"/Font" in data:
            return None
        pages = []
        for photo in photos:
            page = Image.open(io.BytesIO(photo))
            page.load()
            pages.append(page)
        return pages
    except (OSError, ValueError):
        return None


def _separate_upload(source: Path, outgoing: Path) -> tuple[Path, dict | None]:
    """The file the recogniser should read, and what was taken out of it.

    The upload itself is never changed: a cleaned copy is written beside the
    results, with the annotations of each page as an image and a list."""
    from PIL import Image

    if not _enabled():
        return source, None
    pages = _upload_pages(source)
    if not pages:
        return source, None
    folder = outgoing / "annotations"
    tesseract = shutil.which("tesseract")
    cleaned = []
    report = {"pages": [], "items": []}
    found = False
    with tempfile.TemporaryDirectory() as temporary:
        for number, page in enumerate(pages, start=1):
            parts = _separate(page)
            if parts is None:
                cleaned.append(page.convert("L"))
                report["pages"].append({"page": number, "width": page.width, "height": page.height,
                                        "annotations": 0})
                continue
            found = True
            clean, annotation, mask, core = parts
            regions = _regions(mask, core, annotation, clean)
            _read_text(tesseract, annotation, regions, Path(temporary))
            folder.mkdir(parents=True, exist_ok=True)
            annotation.save(folder / f"page-{number}.annotation.png", optimize=True)
            clean.save(folder / f"page-{number}.clean.jpg", quality=88)
            cleaned.append(clean)
            report["pages"].append({
                "page": number, "width": page.width, "height": page.height,
                "annotations": len(regions),
                "annotation": f"page-{number}.annotation.png",
                "clean": f"page-{number}.clean.jpg",
            })
            report["items"].extend({"page": number, **item} for item in regions)
    if not found:
        return source, None
    (outgoing / "annotations.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8",
    )
    if source.suffix.lower() != ".pdf":
        target = folder / "score.png"
        cleaned[0].save(target)
        return target, report
    # One PDF again, every page as wide as the widest so one resolution fits
    # them all; the app makes its pages A4 wide (595 points).
    width = max(page.width for page in cleaned)
    scaled = [
        page if page.width == width
        else page.resize((width, round(page.height * width / page.width)), Image.LANCZOS)
        for page in cleaned
    ]
    target = folder / "score.pdf"
    scaled[0].save(
        target, "PDF", save_all=True, append_images=scaled[1:],
        resolution=width * 72 / 595, quality=92,
    )
    return target, report
