from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

CANVAS_WIDTH = 1800
CANVAS_HEIGHT = 1300
MARGIN = 60
BACKGROUND_COLOR = "#FFFFFF"
TITLE_FILL = "#0F766E"
CLIENT_FILL = "#DCFCE7"
SERVICE_FILL = "#E0F2FE"
DATA_FILL = "#FEE2E2"
INTEGRATION_FILL = "#F1F5F9"
OUTLINE_COLOR = "#0F172A"
TEXT_COLOR = "#0F172A"
ARROW_COLOR = "#0F172A"

OUTPUT_PATH = Path(__file__).resolve().parents[1] / "assets" / "tera_farm_architecture.png"


def load_fonts():
    base_font = ImageFont.load_default()
    return {
        "title": base_font,
        "heading": base_font,
        "body": base_font,
    }


def draw_box(draw: ImageDraw.ImageDraw, bbox, text, fill, fonts, heading=False):
    radius = 20
    x1, y1, x2, y2 = bbox
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=OUTLINE_COLOR, width=3)

    lines = text.strip().split("\n")
    font = fonts["heading"] if heading else fonts["body"]
    # Calculate text height
    line_height = font.getbbox("Ag")[3] - font.getbbox("Ag")[1] + 4
    total_height = len(lines) * line_height
    start_y = (y1 + y2) / 2 - total_height / 2

    for i, line in enumerate(lines):
        w = font.getlength(line)
        line_x = (x1 + x2) / 2 - w / 2
        line_y = start_y + i * line_height
        draw.text((line_x, line_y), line, fill=TEXT_COLOR, font=font)


def draw_arrow(draw: ImageDraw.ImageDraw, start, end):
    draw.line([start, end], fill=ARROW_COLOR, width=4)
    # Arrow head
    arrow_size = 12
    angle = 0.5
    x1, y1 = start
    x2, y2 = end
    vx = x2 - x1
    vy = y2 - y1
    length = max((vx ** 2 + vy ** 2) ** 0.5, 1)
    ux = vx / length
    uy = vy / length

    left = (x2 - arrow_size * (ux + uy * angle), y2 - arrow_size * (uy - ux * angle))
    right = (x2 - arrow_size * (ux - uy * angle), y2 - arrow_size * (uy + ux * angle))
    draw.polygon([left, right, (x2, y2)], fill=ARROW_COLOR)


def main():
    fonts = load_fonts()
    img = Image.new("RGB", (CANVAS_WIDTH, CANVAS_HEIGHT), BACKGROUND_COLOR)
    draw = ImageDraw.Draw(img)

    # Title
    title_bbox = (MARGIN, MARGIN, CANVAS_WIDTH - MARGIN, MARGIN + 120)
    draw_box(
        draw,
        title_bbox,
        "TeraFarm Urban Agriculture Platform\nSystem Architecture Overview",
        fill="#CCFBF1",
        fonts=fonts,
        heading=True,
    )

    # Client layer
    client_bbox = (MARGIN + 120, MARGIN + 160, CANVAS_WIDTH - MARGIN - 120, MARGIN + 360)
    draw_box(
        draw,
        client_bbox,
        "Client Layer (Flutter App)\n- Pages, Widgets, Localization\n- Authentication & Profile\n- AI Interfaces (TeraDoc, TeraCare, TeraRecommend)\n- Marketplace & Community UI",
        fill=CLIENT_FILL,
        fonts=fonts,
    )

    # Service layer boxes
    service_top = MARGIN + 420
    service_bottom = service_top + 260
    column_width = (CANVAS_WIDTH - 2 * (MARGIN + 80)) / 3

    ai_service_bbox = (
        MARGIN + 80,
        service_top,
        MARGIN + 80 + column_width,
        service_bottom,
    )
    draw_box(
        draw,
        ai_service_bbox,
        "AI Services\n- Enhanced AI (Gemini)\n- Scheme Chatbot + RAG\n- YouTube Tutorials\n- TensorFlow Models",
        fill=SERVICE_FILL,
        fonts=fonts,
    )

    backend_service_bbox = (
        MARGIN + 80 + column_width + 40,
        service_top,
        MARGIN + 80 + 2 * column_width + 40,
        service_bottom,
    )
    draw_box(
        draw,
        backend_service_bbox,
        "Backend Services\n- Python Flask API\n- Crop Recommendation Engine\n- Cloud Functions\n- Notifications & Scheduling",
        fill=SERVICE_FILL,
        fonts=fonts,
    )

    utility_service_bbox = (
        MARGIN + 80 + 2 * column_width + 80,
        service_top,
        MARGIN + 80 + 3 * column_width + 80,
        service_bottom,
    )
    draw_box(
        draw,
        utility_service_bbox,
        "Utility Services\n- Navigation & Mapping\n- Voice Assistant & TTS\n- Model Download Manager\n- Google Auth Integration",
        fill=SERVICE_FILL,
        fonts=fonts,
    )

    # Data layer
    data_bbox = (MARGIN + 120, service_bottom + 60, CANVAS_WIDTH - MARGIN - 120, service_bottom + 320)
    draw_box(
        draw,
        data_bbox,
        "Data Layer\n- Firestore: profiles, marketplace, community\n- Firebase Storage: media & plant images\n- Local Storage: offline AI models, cache\n- Analytics & Monitoring",
        fill=DATA_FILL,
        fonts=fonts,
    )

    # External integrations
    integration_top = service_bottom + 380
    integration_height = 180
    integrations = [
        ("Weather API\n(OpenWeather)",),
        ("YouTube Data API\n(Tutorial Videos)",),
        ("Government Schemes\nDatasets & Docs",),
        ("Gemini AI\nGenerative Models",),
    ]

    integration_width = (CANVAS_WIDTH - 2 * (MARGIN + 60) - 3 * 40) / 4
    integration_boxes = []
    for idx in range(4):
        x1 = MARGIN + 60 + idx * (integration_width + 40)
        x2 = x1 + integration_width
        bbox = (x1, integration_top, x2, integration_top + integration_height)
        integration_boxes.append(bbox)
        draw_box(
            draw,
            bbox,
            integrations[idx][0],
            fill=INTEGRATION_FILL,
            fonts=fonts,
        )

    # Draw arrows
    def center_of(b):
        x1, y1, x2, y2 = b
        return (int((x1 + x2) / 2), int((y1 + y2) / 2))

    # From title to client
    draw_arrow(draw, center_of(title_bbox), (center_of(client_bbox)[0], client_bbox[1]))
    # Client to service boxes
    client_bottom_center = (center_of(client_bbox)[0], client_bbox[3])
    for bbox in [ai_service_bbox, backend_service_bbox, utility_service_bbox]:
        draw_arrow(draw, client_bottom_center, (center_of(bbox)[0], bbox[1]))

    # Service boxes to data layer
    data_top = data_bbox[1]
    for bbox in [ai_service_bbox, backend_service_bbox, utility_service_bbox]:
        draw_arrow(draw, (center_of(bbox)[0], bbox[3]), (center_of(bbox)[0], data_top))

    # Data layer to integrations
    data_bottom = data_bbox[3]
    for bbox in integration_boxes:
        draw_arrow(draw, (center_of(bbox)[0], data_bottom), (center_of(bbox)[0], bbox[1]))

    # Save output
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUTPUT_PATH, format="PNG")
    print(f"Architecture diagram saved to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
