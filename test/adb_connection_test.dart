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
        stdout: List<String>.filled(400, 'x').join(),
        stderr: '',
      );
      expect(diagnostic.length, lessThan(300));
      expect(diagnostic, endsWith('...'));
    });

    test('detects the default WSA endpoint from device metadata', () {
      final endpoint = findWsaAdbEndpoint(
        'List of devices attached\n'
        '127.0.0.1:58526 device product:windows_x86_64 '
        'model:Subsystem_for_Android_TM_ device:windows_x86_64 transport_id:1\n',
      );
      expect(endpoint?.serial, '127.0.0.1:58526');
      expect(endpoint?.state, 'device');
    });

    test('discovers an alternate WSA VM address on port 5555', () {
      final endpoint = findWsaAdbEndpoint(
        '172.21.210.88:5555 device product:windows_x86_64 '
        'model:Subsystem_for_Android_TM_ device:windows_x86_64 transport_id:4\n',
        preferredSerial: '127.0.0.1:58526',
      );
      expect(endpoint?.serial, '172.21.210.88:5555');
    });

    test('ignores ordinary Android phones and emulators', () {
      final endpoint = findWsaAdbEndpoint(
        '192.168.1.20:5555 device product:sdk_gphone64_x86_64 model:Pixel_8\n'
        'emulator-5554 device product:sdk_gphone64_x86_64 model:Android_SDK_built_for_x86_64\n',
      );
      expect(endpoint, isNull);
    });

    test('does not guess when multiple WSA endpoints are available', () {
      final output =
          '127.0.0.1:58526 device product:windows_x86_64 model:Subsystem_for_Android_TM_\n'
          '172.21.210.88:5555 device product:windows_x86_64 model:Subsystem_for_Android_TM_\n';
      expect(findWsaAdbEndpoint(output), isNull);
      expect(
        findWsaAdbEndpoint(output, preferredSerial: '172.21.210.88:5555')?.serial,
        '172.21.210.88:5555',
      );
    });

    test('prefers a responding alternate endpoint over the configured offline one', () {
      final output =
          '127.0.0.1:58526 offline product:windows_x86_64 model:Subsystem_for_Android_TM_\n'
          '172.21.210.88:5555 device product:windows_x86_64 model:Subsystem_for_Android_TM_\n';
      expect(
        findWsaAdbEndpoint(output, preferredSerial: '127.0.0.1:58526')?.serial,
        '172.21.210.88:5555',
      );
    });

    test('ignores malformed endpoints and invalid ports', () {
      final endpoint = findWsaAdbEndpoint(
        '999.1.1.1:5555 device product:windows_x86_64\n'
        '172.21.210.88:70000 device product:windows_x86_64\n'
        'not-an-ip:5555 device product:windows_x86_64\n',
      );
      expect(endpoint, isNull);
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
