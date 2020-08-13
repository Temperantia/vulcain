from PIL import Image
from resizeimage import resizeimage

sizes = ((20, 20), (29, 29), (40, 40), (58, 58),
         (60, 60), (76, 76), (80, 80), (87, 87), (120, 120), (152, 152), (167, 167), (180, 180))


def makeName(width, height):
    return 'ios/Runner/Assets.xcassets/AppIcon.appiconset/logo_' + str(width) + 'x' + str(height) + '.png'


def resize():
    with open(makeName(1024, 1024), 'r+b') as f:
        with Image.open(f) as image:
            for size in sizes:
                width = size[0]
                height = size[1]
                cover = resizeimage.resize_cover(
                    image, [width, height])
                cover.save(makeName(width, height), image.format)

resize()