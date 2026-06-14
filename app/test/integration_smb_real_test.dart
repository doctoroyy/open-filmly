import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smb_connect/smb_connect.dart';

void main() {
  final env = Platform.environment;
  final host = env['OPEN_FILMLY_REAL_SMB_HOST'];
  final username = env['OPEN_FILMLY_REAL_SMB_USERNAME'];
  final password = env['OPEN_FILMLY_REAL_SMB_PASSWORD'];
  final shareName = env['OPEN_FILMLY_REAL_SMB_SHARE'];
  final domain = env['OPEN_FILMLY_REAL_SMB_DOMAIN'] ?? '';
  final hasConfig =
      host != null &&
      host.isNotEmpty &&
      username != null &&
      username.isNotEmpty &&
      password != null &&
      password.isNotEmpty &&
      shareName != null &&
      shareName.isNotEmpty;

  test(
    'connects to a real SMB share when credentials are supplied',
    () async {
      final conn = await SmbConnect.connectAuth(
        host: host!,
        username: username!,
        password: password!,
        domain: domain,
      );

      final shares = await conn.listShares();
      expect(shares, isNotEmpty, reason: 'Expected to find at least one share');
      final share = shares.firstWhere((s) => s.name == shareName);
      final rootFolder = await conn.file(share.path);
      expect(
        rootFolder.isExists,
        isTrue,
        reason: 'Root folder of $shareName should exist',
      );

      final children = await conn.listFiles(rootFolder);
      expect(
        children,
        isNotEmpty,
        reason: 'Expected $shareName to have directories or files inside',
      );

      final firstDir = children.firstWhere(
        (entry) => entry.isDirectory(),
        orElse: () => children.first,
      );
      if (firstDir.isDirectory()) {
        final subChildren = await conn.listFiles(firstDir);
        expect(subChildren, isNotNull);
      }
    },
    skip: hasConfig
        ? false
        : 'Set OPEN_FILMLY_REAL_SMB_HOST, OPEN_FILMLY_REAL_SMB_USERNAME, '
              'OPEN_FILMLY_REAL_SMB_PASSWORD, and OPEN_FILMLY_REAL_SMB_SHARE '
              'to run the real SMB test.',
  );
}
