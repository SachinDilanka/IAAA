# Adaptive Sign Language Tutor

## Regenerate gesture data

Place alphabet videos in `videos/`, month videos in `videos/months/<Month>/`,
and verb videos either directly in `videos/Verbs/` or grouped under
`videos/Verbs/<verb>/`. Then extract the landmark sequences:

```powershell
python scripts/batch_extract.py
```

The extracted JSON files are written under `dataset/landmarks/` using
`<type>/<sign>/<sample>.json`. For example, `videos/Verbs/adinawa.mp4` becomes
`dataset/landmarks/verb/adinawa/adinawa.json`. The training scripts read this
nested layout.

Generate rigged avatar animations from the extracted hand landmarks with:

```powershell
python scripts/generate_avatar_animations.py
```

This writes `assets/models/avatar_signs.glb`. Run the generator again after
changing or adding gesture data, then rebuild the Flutter app. Month and verb
animations include 0.5x, 0.75x, and 1x clips; alphabet poses are held as static
clips.

To use a newly extracted verb inside the Flutter app, add its folder to
`pubspec.yaml` and add it to the app's library UI. Rebuild or fully restart the
app after changing the Flutter asset list.

To train the gesture classification model from the extracted sequences:

```powershell
python scripts/train_model.py
```
