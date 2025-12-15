import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

const int _LF = 10;

// const _leadingZerosCompare = <int>[128, 192, 224, 240, 248, 252, 254, 255];

int _leadingOnes(int byte) {
  // UTF-8 encoding patterns:
  // 0xxxxxxx - 1 byte (ASCII)
  // 110xxxxx - 2 bytes
  // 1110xxxx - 3 bytes
  // 11110xxx - 4 bytes

  if (byte >> 7 == 0) return 0; // ASCII
  if (byte >> 5 == 6 /*0b110*/ ) return 1; // 2-byte sequence
  if (byte >> 4 == 14 /*0b1110*/ ) return 2; // 3-byte sequence
  if (byte >> 3 == 30 /*0b11110*/ ) return 3; // 4-byte sequence
  return 0; // Invalid or continuation byte
}

class BytesLineSplitter extends Converter<Uint8List, List<Uint8List>> {
  @override
  List<Uint8List> convert(Uint8List input) {
    final response = <Uint8List>[];

    final iter = input.iterator;
    int start = 0;
    int i = 0;
    while (iter.moveNext()) {
      final leadingOnes = _leadingOnes(iter.current);
      int j = 0;
      if (leadingOnes == 0 && iter.current == _LF) {
        response.add(Uint8List.sublistView(input, start, i));
        start = i + 1;
      }
      while (j < leadingOnes && iter.moveNext()) {
        j++;
        i++;
      }
      i++;
    }
    return response;
  }

  @override
  Sink<Uint8List> startChunkedConversion(Sink<List<Uint8List>> sink) {
    return _LineSplitterChunkedConversionSink(sink);
  }
}

class _LineSplitterChunkedConversionSink implements Sink<Uint8List> {
  final Sink<List<Uint8List>> _sink;
  int _skipBytes = 0;

  _LineSplitterChunkedConversionSink(this._sink);

  @override
  void add(Uint8List chunk) {
    final iter = chunk.iterator;
    for (final _ in List.generate(_skipBytes, (i) => i, growable: false)) {
      iter.moveNext();
    }

    final response = <Uint8List>[];
    int start = 0;
    int i = 0;
    while (iter.moveNext()) {
      final leadingOnes = min(_leadingOnes(iter.current), 3);
      if (leadingOnes == 0 && iter.current == _LF) {
        response.add(Uint8List.sublistView(chunk, start, i));
        start = i + 1;
      }
      _skipBytes = leadingOnes;
      int j = 0;
      while (j < leadingOnes && iter.moveNext()) {
        j++;
        i++;
        _skipBytes--;
      }
      i++;
    }

    _sink.add(response);
  }

  @override
  void close() {
    _sink.close();
  }
}

class Utf8RuneIterator extends Converter<Uint8List, List<Uint8List>> {
  @override
  List<Uint8List> convert(Uint8List input) {
    final response = <Uint8List>[];

    final iter = input.iterator;
    int start = 0;
    int i = 0;
    while (iter.moveNext()) {
      final leadingOnes = min(_leadingOnes(iter.current), 3);
      int j = 0;
      while (j < leadingOnes && iter.moveNext()) {
        j++;
        i++;
      }
      i++;
      response.add(Uint8List.sublistView(input, start, i));
      start = i;
    }
    return response;
  }
}
