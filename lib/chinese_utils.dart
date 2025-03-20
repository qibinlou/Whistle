bool containsChineseCharacters(String input) {
  // Regular expression for matching Chinese characters (CJK Unified Ideographs)
  final RegExp chineseRegex = RegExp(r'[\u4E00-\u9FFF]');

  // Check if the input contains any Chinese character
  return chineseRegex.hasMatch(input);
}

bool containsMainlyChinese(String input) {
  // Regular expression for matching Chinese characters (CJK Unified Ideographs)
  final RegExp chineseRegex = RegExp(r'[\u4E00-\u9FFF]');

  int chineseCount = 0;
  int nonChineseCount = 0;

  for (int i = 0; i < input.length; i++) {
    String char = input[i];
    if (chineseRegex.hasMatch(char)) {
      chineseCount++;
      // If the count of Chinese characters is already larger than the remaining length,
      // it means the input contains mainly Chinese characters
    } else {
      nonChineseCount++;
    }
  }

  // If the loop completes without early termination, check if the majority of characters are Chinese
  return chineseCount > nonChineseCount;
}
