# Photographed medical fixtures

Generated camera-style images, 2026-10-06. Fictional patient, laboratory, clinic, and values; each image is visibly marked SYNTHETIC. No real patient records.

- `photographed-lab.png`: paper on a wooden desk, perspective/skew/fold/shadow; collected 2026-09-18; Glucose 105 mg/dL (70-100), Hemoglobin 13.8 g/dL (12.0-16.0), Creatinine 0.9 mg/dL (0.6-1.2).
- `photographed-medications.png`: historical medication table on paper with shadow/skew; recorded 2026-08-12; Loratadine 10 mg, Vitamin D3 1000 IU. Mentions do not establish current use.

Unit tests run actual Vision OCR against both images and preserve page order. The opt-in photo-picker UI test imports the lab photo and manually reviews a fact before checking timeline, chart, local chat citation, and export. Generated images can contain artifacts and are not a substitute for device-camera tests or diverse consented/redacted evaluation records. The simpler native `scripts/create-ui-fixture.swift` is retained as an isolated OCR smoke fixture; it is not the main photo workflow fixture.

`provider-sample-lab.jpg` is an unmodified public “Example Result” image from [Blood Tests London’s FULL LONDON VIP sample](https://bloodtestslondon.com/products/full-london-health-screen-plus-v), retrieved 2026-10-06 from [the original image](https://bloodtestslondon.com/cdn/shop/files/Blue-Horizon-Tests-London-FULL-LONDON-Blood-Test-VIP-_Plus-V_-1-sample-result_1800x1800.jpg?v=1755081211). Attribution and original provider marks remain intact; this project does not own the report. It supplies authentic report density, typography, scientific notation, colored flags and units for local OCR/import checks, alongside the camera-style fictional fixtures. It is a provider-published sample, not a private patient upload.
