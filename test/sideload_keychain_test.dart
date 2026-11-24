import 'package:celechron/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the iOS storage query uses only its configured signing scope', () {
    final options = secureStorageIOSOptions.toMap();
    expect(options['accessibility'], 'first_unlock');
    expect(options['accountName'], 'Celechron');
    if (privateIOSKeychain) {
      expect(options.containsKey('groupId'), isFalse);
    } else {
      expect(options['groupId'], kDebugMode
          ? 'group.top.celechron.celechron.debug'
          : 'group.top.celechron.celechron');
    }
  });
}
