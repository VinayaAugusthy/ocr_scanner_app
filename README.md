# OCR Scanner App

Flutter app for scanning **payment cards** and **Indian bank passbook / account documents** from the camera or photo library.

Text is recognized **on-device** with Google ML Kit; structured fields are extracted with **custom Dart parsers** (no cloud OCR API).

## Features

| Flow                 | Extracted fields                                                                   |
| -------------------- | ---------------------------------------------------------------------------------- |
| **Card scanner**     | Card number (Luhn-checked when possible), expiry, cardholder name, payment network |
| **Passbook scanner** | Account holder name, account number, IFSC code                                     |

Both flows support:

- Camera capture
- Gallery import
- Loading overlay
- Clear/reset
- Duplicate-scan detection

## Steps to run the project

### Prerequisites

- Flutter SDK compatible with **Dart ^3.10** (see `pubspec.yaml`)
- **Android** or **iOS** device/emulator
- Camera permission enabled for scanning

### Setup and run

```bash
flutter pub get
flutter run
```

Run on a specific device:

```bash
flutter devices
flutter run -d <device_id>
```

### Run tests

```bash
flutter test
```

Parser-specific tests:

```bash
flutter test test/passbook_parser_test.dart
flutter test test/card_parser_test.dart
```

## Libraries used

| Package                                                                                   | Purpose                            |
| ----------------------------------------------------------------------------------------- | ---------------------------------- |
| [`flutter`](https://flutter.dev)                                                          | UI framework                       |
| [`flutter_bloc`](https://pub.dev/packages/flutter_bloc)                                   | State management                   |
| [`equatable`](https://pub.dev/packages/equatable)                                         | Value equality                     |
| [`google_mlkit_text_recognition`](https://pub.dev/packages/google_mlkit_text_recognition) | On-device OCR                      |
| [`image_picker`](https://pub.dev/packages/image_picker)                                   | Camera and gallery image selection |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons)                             | Flutter icons                      |

**Dev dependencies:** `flutter_test`, `flutter_lints`

## Assumptions made

- OCR works only on **Android and iOS**
- OCR is optimized for **Latin/English** text
- Passbook parsing targets **Indian banking** formats
- **One image** is processed at a time
- Card validation uses the **Luhn algorithm** when possible
- OCR correction uses **heuristic-based** cleanup
- All processing stays **fully offline**
- No backend or cloud OCR services are used

## What was skipped and why

| Item                          | Reason                                |
| ----------------------------- | ------------------------------------- |
| Web/desktop support           | ML Kit OCR integrated only for mobile |
| Cloud OCR / backend           | Scope limited to offline OCR          |
| Live camera OCR               | Simpler still-image workflow used     |
| Scan history / export         | No database or persistence added      |
| Localization                  | English-only UI                       |
| Dark mode                     | Light theme only                      |
| Additional bank fields        | Focused only on required extraction   |
| CVV / magnetic stripe reading | Security reasons                      |
| Production signing            | Assignment / demo scope               |
| Device integration tests      | OCR testing can be hardware-dependent |

## Project structure

```
lib/
├── app.dart
├── core/
├── features/
│   ├── home/
│   ├── card_scanner/
│   ├── passbook_scanner/
│   ├── ocr/
│   └── shared_image_picker/
test/
```

Architecture follows:

**presentation → domain → data**
