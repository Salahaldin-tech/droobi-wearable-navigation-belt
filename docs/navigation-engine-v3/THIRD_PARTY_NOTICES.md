# Third-party notices

## WMM2025 magnetic declination implementation

- Adapted source: `Rishav1995-roy/true_compass`
- Upstream revision: `e76448115764b9a59020dc603c4da1eb920d6db1`
- Adapted files: `lib/src/magnetic_declination.dart` and `lib/src/wmm2025_coefficients.dart`
- Vendored into: `lib/services/navigation/wmm2025/`
- License: MIT; full notice is retained at `lib/services/navigation/wmm2025/LICENSE`.
- The WMM2025 Gauss coefficients originate from NOAA/NCEI's public-domain WMM2025 coefficient file.
- The model is valid from 2025-01-01 through 2029-12-31. The navigation service refuses to start compass guidance when the model reports itself outside that validity window.

The compass stream remains `flutter_compass`; the vendored WMM implementation is used only to calculate local magnetic declination and convert magnetic heading to true heading. It adds no sensor, network request, or external IMU.
