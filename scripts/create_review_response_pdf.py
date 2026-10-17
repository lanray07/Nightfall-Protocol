"""Render the factual review response as a printable App Review attachment."""
from pathlib import Path
from html import escape
import argparse
import re

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, default=ROOT / "APP_REVIEW_RESPONSE.md")
parser.add_argument("--output", type=Path, default=ROOT / "output/pdf/Nightfall-Protocol-App-Review-Response.pdf")
parser.add_argument("--submission", default="da1d6268-85c6-4f57-ad4c-ad38726eab88")
parser.add_argument("--subtitle", default="Response to App Review - iOS version 1.0")
args = parser.parse_args()
destination = args.output
destination.parent.mkdir(parents=True, exist_ok=True)
font_root = Path("C:/Windows/Fonts")
pdfmetrics.registerFont(TTFont("ReviewText", str(font_root / "segoeui.ttf")))
pdfmetrics.registerFont(TTFont("ReviewBold", str(font_root / "segoeuib.ttf")))
text = args.source.read_text(encoding="utf-8")
text = text[text.index("Hello App Review Team,"):]
for dash in ("\u2011", "\u2013", "\u2014"):
    text = text.replace(dash, "-")
body = ParagraphStyle("body", fontName="ReviewText", fontSize=9.5, leading=14,
                      spaceAfter=9, alignment=TA_LEFT, textColor=colors.HexColor("#202c3c"))
heading = ParagraphStyle("heading", parent=body, fontName="ReviewBold", fontSize=11,
                         leading=15, spaceBefore=12, spaceAfter=6, keepWithNext=True)
title = ParagraphStyle("title", parent=heading, fontSize=20, leading=26, spaceBefore=0)
story = [Paragraph("Nightfall Protocol", title),
         Paragraph(escape(args.subtitle), heading),
         Paragraph("Submission " + escape(args.submission), body), Spacer(1, 10)]
question_titles = ["App purpose", "Intended users", "Distinct experience", "Testing and feedback",
                   "Standalone scope", "Consolidation", "Shared account components",
                   "Third-party components", "Content provider"]
for paragraph in re.split(r"\n\s*\n", text):
    paragraph = paragraph.strip()
    if not paragraph:
        continue
    if re.match(r"^[1-9]\. ", paragraph):
        number = int(paragraph[0])
        story.append(Paragraph(f"{number}. {question_titles[number - 1]}", heading))
        paragraph = paragraph[3:]
    style = heading if paragraph.startswith("## ") else body
    paragraph = paragraph.removeprefix("## ")
    story.append(Paragraph(escape(paragraph).replace("\n", "<br/>"), style))


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#d7dde5"))
    canvas.line(48, 40, A4[0] - 48, 40)
    canvas.setFont("ReviewText", 8)
    canvas.setFillColor(colors.HexColor("#647286"))
    canvas.drawString(48, 27, "Nightfall Protocol | App Review response")
    canvas.drawRightString(A4[0] - 48, 27, str(doc.page))
    canvas.restoreState()


SimpleDocTemplate(str(destination), pagesize=A4, rightMargin=48, leftMargin=48,
                  topMargin=45, bottomMargin=57, title="Nightfall Protocol - App Review Response",
                  author="Olanrewaju Bankole").build(story, onFirstPage=footer, onLaterPages=footer)
print(destination)
