from PIL import Image

# Завантаження зображення (128x128 пікселів)
img = Image.open("image.png").convert("RGB")
img = img.resize((128, 128))
pixels = img.load()

# Створення .coe файлу
with open("image_data.coe", "w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    for y in range(128):
        for x in range(128):
            r, g, b = pixels[x, y]
            # Конвертація RGB888 у RGB565
            r = (r >> 3) & 0x1F
            g = (g >> 2) & 0x3F
            b = (b >> 3) & 0x1F
            pixel = (r << 11) | (g << 5) | b
            f.write(f"{pixel:04X}")
            if x == 127 and y == 127:
                f.write(";")
            else:
                f.write(",")
            f.write("\n")