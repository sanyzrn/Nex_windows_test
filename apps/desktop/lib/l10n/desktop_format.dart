import 'package:flutter/widgets.dart';
import 'package:nex_core/nex_core.dart';

/// Localize application-owned numbers; never transform user content or IDs.
String desktopDigits(BuildContext context, Object value) => nexDigits(
  '$value',
  persian: Localizations.localeOf(context).languageCode == 'fa',
);
