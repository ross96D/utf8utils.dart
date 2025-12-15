import 'dart:convert';
import 'dart:typed_data';

import 'package:utf8utils/utf8utils.dart';
import 'package:test/test.dart';

void main() {
  group('Line splitter', () {
    final lineSplitter = BytesLineSplitter();

    test('Simple', () {
      final content = """
hello1
hello2
hello3


hello4
hello5
hello6
""";
      final lines = lineSplitter.convert(utf8.encode(content));
      final expectedLines = LineSplitter().convert(content);

      expect(lines.length, equals(expectedLines.length));

      for (int i = 0; i < lines.length; i++) {
        final actual = lines[i];
        final expected = expectedLines[i];
        expect(utf8.decode(actual), equals(expected));
      }
    });

    test('Simple Emoji', () {
      final content = """
hello1😂
hello2😂
hello😂3
hello😂4
😂hello5
he😂llo6
""";
      final lines = lineSplitter.convert(utf8.encode(content));
      final expectedLines = LineSplitter().convert(content);

      expect(lines.length, equals(expectedLines.length));

      for (int i = 0; i < lines.length; i++) {
        final actual = lines[i];
        final expected = expectedLines[i];
        expect(utf8.decode(actual), equals(expected));
      }
    });
  });

  group('Utf8RuneIterator', () {
    Utf8RuneIterator iterator = Utf8RuneIterator();

    test('should handle empty input', () {
      final input = Uint8List(0);
      final result = iterator.convert(input);
      expect(result, isEmpty);
    });

    test('should handle single ASCII character', () {
      // 'A' in UTF-8
      final input = Uint8List.fromList([0x41]);
      final result = iterator.convert(input);

      expect(result, hasLength(1));
      expect(result[0], equals(Uint8List.fromList([0x41])));
    });

    test('should handle multiple ASCII characters', () {
      // 'ABC' in UTF-8
      final input = Uint8List.fromList([0x41, 0x42, 0x43]);
      final result = iterator.convert(input);

      expect(result, hasLength(3));
      expect(result[0], equals(Uint8List.fromList([0x41])));
      expect(result[1], equals(Uint8List.fromList([0x42])));
      expect(result[2], equals(Uint8List.fromList([0x43])));
    });

    test('should handle 2-byte UTF-8 character', () {
      // '£' (U+00A3) in UTF-8: [0xC2, 0xA3]
      final input = Uint8List.fromList([0xC2, 0xA3]);
      final result = iterator.convert(input);

      expect(result, hasLength(1));
      expect(result[0], equals(Uint8List.fromList([0xC2, 0xA3])));
    });

    test('should handle 3-byte UTF-8 character', () {
      // '€' (U+20AC) in UTF-8: [0xE2, 0x82, 0xAC]
      final input = utf8.encode("€");
      // final input = Uint8List.fromList([0xE2, 0x82, 0xAC]);
      final result = iterator.convert(input);

      expect(result, hasLength(1));
      expect(result[0], equals(Uint8List.fromList([0xE2, 0x82, 0xAC])));
    });

    test('should handle 4-byte UTF-8 character', () {
      // '𐍈' (U+10348) in UTF-8: [0xF0, 0x90, 0x8D, 0x88]
      final input = Uint8List.fromList([0xF0, 0x90, 0x8D, 0x88]);
      final result = iterator.convert(input);

      expect(result, hasLength(1));
      expect(result[0], equals(Uint8List.fromList([0xF0, 0x90, 0x8D, 0x88])));
    });

    test('should handle mixed ASCII and multi-byte characters', () {
      // 'A£B€C' in UTF-8
      final input = Uint8List.fromList([
        0x41,           // A
        0xC2, 0xA3,    // £
        0x42,           // B
        0xE2, 0x82, 0xAC, // €
        0x43            // C
      ]);

      final result = iterator.convert(input);

      expect(result, hasLength(5));
      expect(result[0], equals(Uint8List.fromList([0x41]))); // A
      expect(result[1], equals(Uint8List.fromList([0xC2, 0xA3]))); // £
      expect(result[2], equals(Uint8List.fromList([0x42]))); // B
      expect(result[3], equals(Uint8List.fromList([0xE2, 0x82, 0xAC]))); // €
      expect(result[4], equals(Uint8List.fromList([0x43]))); // C
    });

    test('should handle string with only multi-byte characters', () {
      // '£€𐍈' in UTF-8
      final input = Uint8List.fromList([
        0xC2, 0xA3,          // £
        0xE2, 0x82, 0xAC,    // €
        0xF0, 0x90, 0x8D, 0x88 // 𐍈
      ]);

      final result = iterator.convert(input);

      expect(result, hasLength(3));
      expect(result[0], equals(Uint8List.fromList([0xC2, 0xA3]))); // £
      expect(result[1], equals(Uint8List.fromList([0xE2, 0x82, 0xAC]))); // €
      expect(result[2], equals(Uint8List.fromList([0xF0, 0x90, 0x8D, 0x88]))); // 𐍈
    });

    test('should handle complex string with emoji', () {
      final input = utf8.encode("'Hello 🌍 World! 😊' in UTF-8");

      final result = iterator.convert(input);

      expect(result, hasLength(27));
      expect(result.reduce((a, b) => Uint8List.fromList([...a, ...b])), equals(input));
    });

    test('should handle continuation bytes as separate runes (invalid UTF-8)', () {
      // This tests behavior with invalid UTF-8 where continuation bytes appear alone
      final input = Uint8List.fromList([0xA3, 0x82, 0xAC]);
      final result = iterator.convert(input);

      // Each continuation byte should be treated as a separate 1-byte rune
      expect(result, hasLength(3));
      expect(result[0], equals(Uint8List.fromList([0xA3])));
      expect(result[1], equals(Uint8List.fromList([0x82])));
      expect(result[2], equals(Uint8List.fromList([0xAC])));
    });

    test('should handle incomplete multi-byte sequence at end', () {
      // Incomplete 2-byte sequence: only first byte
      final input = Uint8List.fromList([0xC2]);
      final result = iterator.convert(input);

      expect(result, hasLength(1));
      expect(result[0], equals(Uint8List.fromList([0xC2])));
    });

    test('should verify rune boundaries match UTF-8 decoding', () {
      // Test that the rune boundaries match what UTF-8 decoder expects
      final testString = 'Hello 世界 🌍';
      final utf8Bytes = utf8.encode(testString);
      final input = Uint8List.fromList(utf8Bytes);

      final result = iterator.convert(input);

      // Verify each rune can be decoded back to the original string
      final decodedRunes = result.map((bytes) => utf8.decode(bytes)).toList();
      expect(decodedRunes.join(), equals(testString));

      // Verify rune count matches string's rune count
      expect(result.length, equals(testString.runes.length));
    });
  });
}
