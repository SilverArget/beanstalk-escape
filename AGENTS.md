# Beanstalk Escape repository rules

- Source of truth: `../01-tasarim/BEANSTALK_ESCAPE_30_BOLUM_EKSIKSIZ_URETIM_EMRI.md` v1.3 and `../01-tasarim/CODEX-30-ETAP-BASLAT.md`.
- Work through GATE 0–8 in order. Stop after GATE 3A at owner checkpoint S5; do not start GATE 3B until the owner says `DEVAM`.
- Preserve user work and approved raw assets. Never hard reset, delete originals, push, publish, submit, or spend money.
- Do not edit `docs/` by hand. Release evidence belongs under `../03-test/qa/`; session state belongs only in `../IMPLEMENTATION_PROGRESS.md`.
- New artwork is produced only with Codex `image_gen`; request rig parts, not animation frames. Record source, date, license/provenance, scene use, and hashes.
- Scale lock (§5.1) is mandatory before art: 960×540, character 96–120 (target 108), trunk 160–200, branch 36–56, adjacent centers 130–180, gameplay zoom 1.0, no visible seams.
- A visual result is never PASS without inspecting the rendered frame. Headless numeric checks and browser emulation must be labelled accurately; real Android remains `NOT RUN` until measured on hardware.
- Baseline/import: `E:\Godot4\Godot_v4.7.2-stable_win64_console.exe --headless --path E:\oyunlar\BeanstalkEscape\02-kod --import`.
- Godot tests: run each approved `../03-test/**/test*.gd` with `--headless --fixed-fps 60 --path ... --script <file>` and report PASS/FAIL counts per file.
- Browser tests: `cd ../03-test/playwright; npm.cmd test`. Do not treat screenshots or concept art as gameplay proof.
- Every checkpoint updates `design-docs/QUALITY_REPORT.md`, `design-docs/DECISIONS.md` when applicable, and `../IMPLEMENTATION_PROGRESS.md`, then creates a local commit on `full-30-stage`.
