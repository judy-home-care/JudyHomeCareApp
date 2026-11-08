import 'package:flutter/material.dart';

import 'app_language.dart';
import 'content_translator.dart';

/// Drop-in replacement for [Text] for user-written content (notes, care plan
/// titles and descriptions, incident details, messages...).
///
/// Shows the text in the app language: built-in dictionary first, otherwise a
/// machine translation fetched from the server. Until the translation arrives
/// (or if it fails) the original is shown. Longer translated passages get a
/// "Show original" link, so readers can always check what the author wrote.
class TranslatedText extends StatefulWidget {
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// Show the "Show original" link under translated text. Defaults to on for
  /// passages of [_toggleMinLength]+ characters that are not truncated.
  final bool? showOriginalToggle;

  static const int _toggleMinLength = 60;

  const TranslatedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.showOriginalToggle,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    AppLanguage.current.addListener(_refresh);
    ContentTranslator.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _showOriginal = false;
  }

  @override
  void dispose() {
    AppLanguage.current.removeListener(_refresh);
    ContentTranslator.instance.removeListener(_refresh);
    super.dispose();
  }

  Text _text(String value) => Text(
        value,
        style: widget.style,
        strutStyle: widget.strutStyle,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        locale: widget.locale,
        softWrap: widget.softWrap,
        overflow: widget.overflow,
        textScaler: widget.textScaler,
        maxLines: widget.maxLines,
        semanticsLabel: widget.semanticsLabel,
        textWidthBasis: widget.textWidthBasis,
        textHeightBehavior: widget.textHeightBehavior,
        selectionColor: widget.selectionColor,
      );

  @override
  Widget build(BuildContext context) {
    final original = widget.data;
    final translated = translateContent(original);
    final isMachineTranslated =
        translated != original && AppLanguage.lookup(original) == null;

    final wantsToggle = widget.showOriginalToggle ??
        (widget.maxLines == null &&
            original.length >= TranslatedText._toggleMinLength);

    if (!isMachineTranslated || !wantsToggle) {
      return _text(translated);
    }

    final align = switch (widget.textAlign) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        _text(_showOriginal ? original : translated),
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showOriginal = !_showOriginal),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 12, color: Color(0xFF8A8A8A)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _showOriginal
                        ? 'Show translation'.tr
                        : 'Translated · Show original'.tr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
