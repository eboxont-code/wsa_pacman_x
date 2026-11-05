import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_pacman/utils/adb_connection.dart';

void main() {
  group('classifyAdbConnectOutcome', () {
    test('accepts a successful connection response', () {
      expect(
        classifyAdbConnectOutcome(
          exitCode: 0,
          stdout: 'connected to 127.0.0.1:58526',
          stderr: '',
        ),
        AdbConnectOutcome.connected,
      );
    });

    test('accepts an already-connected response', () {
      expect(
        classifyAdbConnectOutcome(
          exitCode: 0,
          stdout: 'already connected to 127.0.0.1:58526',
          stderr: '',
        ),
        AdbConnectOutcome.connected,
      );
    });

    test('detects authentication failures reported on stderr', () {
      expect(
        classifyAdbConnectOutcome(
          exitCode: 1,
          stdout: '',
          stderr: 'failed to authenticate to 127.0.0.1:58526',
        ),
        AdbConnectOutcome.unauthorized,
      );
    });

    test('detects connection failures reported on stderr', () {
      expect(
        classifyAdbConnectOutcome(
          exitCode: 1,
          stdout: '',
          stderr: 'cannot connect to 127.0.0.1:58526',
        ),
        AdbConnectOutcome.failed,
      );
    });

    test('rejects an unexpected non-zero exit code', () {
      expect(
        classifyAdbConnectOutcome(
          exitCode: 2,
          stdout: '',
          stderr: 'adb server unavailable',
        ),
        AdbConnectOutcome.failed,
      );
    });

    test('reports the failed endpoint and stderr reason', () {
      expect(
        describeAdbConnectFailure(
          endpoint: '127.0.0.1:58526',
          exitCode: 1,
          stdout: '',
          stderr: 'cannot connect: connection refused',
        ),
        'ADB could not connect to 127.0.0.1:58526: cannot connect: connection refused',
      );
    });

    test('reports a timeout without an empty generic error', () {
      expect(
        describeAdbConnectFailure(
          endpoint: 'localhost:58526',
          exitCode: -1,
          stdout: '',
          stderr: '',
          timedOut: true,
        ),
        'Connection to localhost:58526 timed out while starting ADB.',
      );
    });

    test('caps long diagnostic output', () {
      final diagnostic = describeAdbConnectFailure(
        endpoint: 'localhost:58526',
        exitCode: 1,
        stdout: 'x' * 400,
        stderr: '',
      );
      expect(diagnostic.length, lessThan(300));
      expect(diagnostic, endsWith('...'));
    });

    test('treats a timed-out process as a failure', () {
      expect(
        classifyAdbConnectOutcome(
          exitCode: -1,
          stdout: '',
          stderr: '',
          timedOut: true,
        ),
        AdbConnectOutcome.failed,
      );
    });
  });
}
