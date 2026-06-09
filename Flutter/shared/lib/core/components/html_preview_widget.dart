import 'package:flutter/material.dart';

class HtmlPreviewWidget extends StatelessWidget {
  final String htmlText;

  const HtmlPreviewWidget({super.key, required this.htmlText});

  @override
  Widget build(BuildContext context) {
    if (htmlText.isEmpty) {
      return const Text(
        'Nincs tartalom.',
        style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
      );
    }

    final lines = htmlText.split(RegExp(r'<br\s*/?>'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lines.map((line) => _parseLineToRichText(line)).toList(),
    );
  }

  Widget _parseLineToRichText(String line) {
    TextAlign alignment = TextAlign.left;
    String content = line;

    final divMatch = RegExp(r'<div\s+align="([^"]+)"\s*>(.*?)</div>').firstMatch(line);
    if (divMatch != null) {
      final alignStr = divMatch.group(1);
      if (alignStr == 'center') alignment = TextAlign.center;
      if (alignStr == 'right') alignment = TextAlign.right;
      content = divMatch.group(2) ?? '';
    }

    final spans = _parseInlineTags(content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: alignment,
      ),
    );
  }

  List<InlineSpan> _parseInlineTags(String text) {
    final List<InlineSpan> spans = [];
    final RegExp tagRegex = RegExp(r'<(/?[a-zA-Z]+)(?:\s+[^>]*)?>');
    int lastIndex = 0;
    
    bool isBold = false;
    bool isItalic = false;
    double? fontSize;
    String? fontFamily;
    Color? fontColor;

    for (final Match match in tagRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final substring = text.substring(lastIndex, match.start);
        spans.add(TextSpan(
          text: substring,
          style: TextStyle(
            color: fontColor ?? Colors.white70,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        ));
      }

      final fullTag = match.group(0) ?? '';
      final tagName = match.group(1) ?? '';
      
      if (tagName.startsWith('/')) {
        final closedName = tagName.substring(1).toLowerCase();
        if (closedName == 'b') isBold = false;
        if (closedName == 'i') isItalic = false;
        if (closedName == 'font') {
          fontSize = null;
          fontFamily = null;
          fontColor = null;
        }
      } else {
        final openName = tagName.toLowerCase();
        if (openName == 'b') isBold = true;
        if (openName == 'i') isItalic = true;
        if (openName == 'font') {
          final sizeMatch = RegExp(r'size="([^"]+)"').firstMatch(fullTag);
          if (sizeMatch != null) {
            fontSize = double.tryParse(sizeMatch.group(1) ?? '') ?? 14.0;
          }
          final faceMatch = RegExp(r'face="([^"]+)"').firstMatch(fullTag);
          if (faceMatch != null) {
            fontFamily = faceMatch.group(1);
          }
          final colorMatch = RegExp(r'color="([^"]+)"').firstMatch(fullTag);
          if (colorMatch != null) {
            final colorStr = colorMatch.group(1);
            if (colorStr != null) {
              if (colorStr.startsWith('#')) {
                try {
                  fontColor = Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
                } catch (_) {}
              }
            }
          }
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          color: fontColor ?? Colors.white70,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          fontSize: fontSize,
          fontFamily: fontFamily,
        ),
      ));
    }

    return spans;
  }
}
