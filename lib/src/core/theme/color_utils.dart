import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:material_color_utilities/quantize/quantizer_celebi.dart';
import 'package:material_color_utilities/score/score.dart';

/// Computes a dominant ARGB color from an image at [filePath] off the main isolate.
/// Returns an ARGB int (0xFFrrggbb) or null if decoding fails.
Future<int?> computeDominantArgb(String filePath) async {
  return compute<String, int?>(_dominantColorJob, filePath);
}

Future<int?> _dominantColorJob(String path) async {
  try {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Downscale for speed
    final sample = img.copyResize(decoded, width: 120);

    // Build ARGB pixel list (sampled) for MCU quantizer
    final List<int> argbPixels = <int>[];
    for (int y = 0; y < sample.height; y += 2) {
      for (int x = 0; x < sample.width; x += 2) {
        final pixel = sample.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        argbPixels.add((0xFF << 24) | (r << 16) | (g << 8) | b);
      }
    }
    if (argbPixels.isEmpty) return null;

    // Use Material Color Utilities to score a seed color from pixels
    final quantizer = QuantizerCelebi();
    final quantized = await quantizer.quantize(argbPixels, 128);
    final Map<int, int> colorToCount = quantized.colorToCount;
    final List<int> ranked = Score.score(colorToCount);
    return ranked.isNotEmpty ? ranked.first : null;
  } catch (_) {
    return null;
  }
}
