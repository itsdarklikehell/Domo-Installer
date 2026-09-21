# Domo-Installer

Dit (menu)script geeft een gestroomlijnde installatie voor Domoticz.

```bash
bash <(curl -Ls https://github.com/hmol33/Domo-Installer/raw/master/Domo-Installer.sh)
```

---

## 🎥 Gource Visualisatie

De ontwikkelhistorie van dit project in een film:

<video src="https://raw.githubusercontent.com/itsdarklikehell/Domo-Installer/master/gource-720p.mp4" controls width="100%"></video>

*De video wordt automatisch gegenereerd door de [Gource workflow](.github/workflows/gource.yml) bij elke push — rendered via [nbprojekt/gource-action@v1.3.0](https://github.com/marketplace/actions/gource-action) in 1080p/60fps. Het artifact is 30 dagen beschikbaar via Actions.*

Lokale video genereren:

```bash
gource --max-files 1000 --key -800x600 \
  --highlight-users --filename-time 3 --output-framerate 25 \
  -s 0.6 --multi-sampling --auto-skip-seconds 0.1 \
  --stop-at-end --hide mouse,progress -o gource.ppm

ffmpeg -y -r 15 -f image2pipe -vcodec ppm -i gource.ppm \
  -vcodec libx264 -preset medium -pix_fmt yuv420p \
  -crf 1 -threads 0 -bf 0 gource.mp4
```
