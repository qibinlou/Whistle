import 'package:flutter_test/flutter_test.dart';
import 'package:whistle/chinese_utils.dart';

void main() {
  test('containsChineseCharacters returns true for Chinese input', () {
    expect(containsChineseCharacters('你好'), isTrue);
    expect(containsChineseCharacters('厨房、居家购物清单拖把咖啡机右侧多层架子书架右侧收纳架'), isTrue);
  });

  test('containsChineseCharacters returns false for non-Chinese input', () {
    expect(containsChineseCharacters('Hello'), isFalse);
    expect(containsChineseCharacters('3.14159 is Pi. !@#%^&*()_+{}:"<>?,./;[]'),
        isFalse);
  });

  test('containsChineseCharacters returns true for mixed input', () {
    expect(containsChineseCharacters('Hello 你好'), isTrue);

    expect(
        containsChineseCharacters(
            '嗯,那我想想看这句话怎么说。 你要不把那个作业发给我,我先看看。 然后明天我再提交到我们的课程表上。 你觉得怎么样? 还有,明天上完课要一起打羽毛球吗? 我们四个人一起打羽毛球,你觉得怎么样? 如果好的话你就回复我一下。怎么样?拜拜。'),
        isTrue);

    expect(
        containsChineseCharacters(
            '如图。 最近几次Google搜索发现知乎的页面几乎销声匿迹，残存的几个结果页也没有任何内容信息。 随手打开了zhihu的robots.txt页面，发现了这个大改动！'),
        isTrue);
  });

  test('containsChineseCharacters returns false for empty input', () {
    expect(containsChineseCharacters(''), isFalse);
  });

  test('containsChineseCharacters returns false for whitespace input', () {
    expect(containsChineseCharacters('   '), isFalse);
  });
}
