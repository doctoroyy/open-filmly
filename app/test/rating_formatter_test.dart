import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/core/formatters/rating_formatter.dart';

void main() {
  test('formats ratings to one decimal place', () {
    expect(formatRating('8.381'), '8.4');
    expect(formatRating(7.531), '7.5');
    expect(formatRating('8'), '8.0');
  });

  test('handles missing and non-numeric ratings', () {
    expect(formatRating(null), isNull);
    expect(formatRating(''), isNull);
    expect(formatRating('暂无'), '暂无');
  });
}
