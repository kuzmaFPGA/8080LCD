import numpy as np

# Параметри зображення
width = 800
height = 480
bits_per_pixel = 16

# Приклад: Створення тестового зображення (градієнт)
image = np.zeros((height, width), dtype=np.uint16)
for y in range(height):
    for x in range(width):
        # RGB565: 5 біт червоний, 6 біт зелений, 5 біт синій
        red = (x * 31 // width) & 0x1F   # 5 біт
        green = (y * 63 // height) & 0x3F # 6 біт
        blue = ((x + y) * 31 // (width + height)) & 0x1F # 5 біт
        pixel = (red << 11) | (green << 5) | blue
        image[y, x] = pixel

# Збереження у бінарний файл
with open("image_data.bin", "wb") as f:
    for pixel in image.flatten():
        f.write(pixel.tobytes())
