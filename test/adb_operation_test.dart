import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_pacman/utils/adb_operation.dart';

void main() {
  group('requireAdbCommandSuccess', () {
    test('accepts a zero exit code', () {
      expect(
        () => requireAdbCommandSuccess(
          operation: 'push expansion',
          exitCode: 0,
          stdout: 'Success',
          stderr: '',
        ),
        returnsNormally,
      );
    });

    test('throws with operation, exit code and stderr on failure', () {
      try {
        requireAdbCommandSuccess(
          operation: 'push expansion main.1.example.obb',
          exitCode: 1,
          stdout: '',
          stderr: 'remote secure_mkdirs failed: Permission denied',
        );
        fail('Expected AdbCommandFailure');
      } on AdbCommandFailure catch (error) {
        expect(error.toString(), contains('push expansion main.1.example.obb'));
        expect(error.toString(), contains('exit code 1'));
        expect(error.toString(), contains('Permission denied'));
      }
    });

    test('includes stdout when stderr is empty', () {
      try {
        requireAdbCommandSuccess(
          operation: 'move expansion',
          exitCode: 2,
          stdout: 'No such file or directory',
          stderr: '',
        );
        fail('Expected AdbCommandFailure');
      } on AdbCommandFailure catch (error) {
        expect(error.toString(), contains('No such file or directory'));
      }
    });

    test('provides a useful message when ADB returns no output', () {
      try {
        requireAdbCommandSuccess(
          operation: 'push expansion',
          exitCode: 1,
        );
        fail('Expected AdbCommandFailure');
      } on AdbCommandFailure catch (error) {
        expect(error.toString(), contains('no output'));
      }
    });
    test('quotes remote paths containing spaces', () {
      expect(
        quoteAdbShellArgument('Android/data/my app'),
        "'Android/data/my app'",
      );
    });

    test('escapes apostrophes in remote paths', () {
      expect(
        quoteAdbShellArgument("user's folder"),
        "'user'\\''s folder'",
      );
    });
  });
}
