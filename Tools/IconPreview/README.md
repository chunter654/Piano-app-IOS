# Looking at the icon

Two small Mac tools, because judging an icon in a 1024 pixel window is how you
ship something clunky.

`sheet.swift` masks each icon it is given and lays it out large and at 60
points, the size it occupies on a home screen, with the small one blown up
without smoothing so you see only the detail that survives.

`corner.swift` magnifies one masked corner, which is where the mask and the
keybed have to agree.

Both mask with a superellipse rather than a circular rounded rectangle, and
that is the point of keeping them. iOS does not mask icons with a circular
arc. A circular preview mask makes the band round the corner look even when it
is not, which is exactly the defect it was hiding when this was written.

```bash
swiftc -O Tools/IconPreview/sheet.swift -o /tmp/sheet
/tmp/sheet /tmp/out.png Piano/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```
