import 'package:flutter_test/flutter_test.dart';
import 'package:whistle/chinese_utils.dart';

void main() {
  group('Chinese Utils Tests', () {
    test('containsChineseCharacters detects Chinese characters', () {
      expect(containsChineseCharacters('Hello 世界'), isTrue);
      expect(containsChineseCharacters('Hello World'), isFalse);
    });

    test('containsMainlyChinese detects primary language', () {
      expect(containsMainlyChinese('你好，这是一个测试。'), isTrue);
      expect(containsMainlyChinese('Hello, this is a test. 你好'), isFalse);
    });
  });
}
