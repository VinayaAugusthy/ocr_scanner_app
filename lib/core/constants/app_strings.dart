abstract final class AppStrings {
  AppStrings._();

  static const String appTitle = 'OCR Scanner';
  static const String materialAppTitle = appTitle;

  // Home
  static const String homeHeadline = 'Choose a scanner';
  static const String homeSubtitle =
      'Card and passbook flows use on-device OCR; parsing is custom.';
  static const String homeCardScannerButton = 'Card scanner';
  static const String homePassbookScannerButton = 'Passbook / bank document';

  // Card scanner
  static const String cardScannerTitle = 'Card scanner';
  static const String clearTooltip = 'Clear';
  static const String cameraButton = 'Camera';
  static const String galleryButton = 'Gallery';
  static const String extractedSectionTitle = 'Extracted';
  static const String cardFieldNumber = 'Card number';
  static const String cardFieldExpiry = 'Expiry';
  static const String cardFieldCardholder = 'Cardholder';
  static const String cardFieldLuhn = 'Luhn check';
  static const String cardFieldNetwork = 'Network';
  static const String luhnValid = 'Valid';
  static const String luhnInvalidOrUnknown = 'Invalid / unknown';

  // Passbook scanner
  static const String passbookScannerTitle = 'Passbook scanner';
  static const String passbookFieldHolder = 'Account holder';
  static const String passbookFieldAccount = 'Account number';
  static const String passbookFieldIfsc = 'IFSC';

  // Scan preview
  static const String scanPreviewLabel = 'Scan preview';

  // Placeholders / masks
  static const String emDash = '—';
  static const String cardNumberMaskPrefix = 'XXXX XXXX XXXX ';

  // Bloc / flow (user-facing errors)
  static const String errorTryAgainLater =
      'Something went wrong. Please try again later.';
  static const String errorPickImageFailed =
      'Could not capture or open the image. Check permissions and try again.';
}
