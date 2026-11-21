# Blender art sources

`blender/building_house.blend` is the editable source scene for the house prototype.
`renders/` contains its full-size Cycles render before downsampling.

Rebuild from the project root with the bundled Blender installation:

```powershell
& ".\Blender\blender.exe" --background --factory-startup --python ".\tools\render_house.py"
```

The default pipeline renders at 768 x 768 with 96 samples, then downsamples to the
192 x 192 transparent PNG used by Godot. For a quicker lighting preview:

```powershell
& ".\Blender\blender.exe" --background --factory-startup --python ".\tools\render_house.py" -- --samples 24 --master-size 384
```

The scene uses an orthographic camera, automatic subject framing, warm upper-left
lighting, beveled geometry and subtle procedural material texture. No third-party
models or textures are required.
