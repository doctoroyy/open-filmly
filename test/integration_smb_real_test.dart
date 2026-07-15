import 'package:test/test.dart';
import 'package:smb_connect/smb_connect.dart';

void main() {
  test('Real SMB Connection and List Files Closed Loop', () async {
    print('Starting automated SMB connection test...');

    // Connect to the real NAS
    final conn = await SmbConnect.connectAuth(
      host: '192.168.31.252',
      username: 'xiaoyu',
      password: '0206a0216cy',
      domain: '',
    );
    print('Connected successfully!');

    // 1. Get the list of shares
    final shares = await conn.listShares();
    expect(shares, isNotEmpty, reason: 'Expected to find at least one share');
    print('Found shares: ${shares.map((e) => e.name).toList()}');

    // 2. Open the wd share
    final wdShare = shares.firstWhere((s) => s.name == 'wd');
    expect(wdShare.name, 'wd');

    final rootFolder = await conn.file(wdShare.path);
    expect(
      rootFolder.isExists,
      isTrue,
      reason: 'Root folder of wd share should exist',
    );
    print('Opened wd share root: path=${rootFolder.path}');

    // 3. List the children of wd share
    final children = await conn.listFiles(rootFolder);
    expect(
      children,
      isNotEmpty,
      reason: 'Expected wd share to have directories/files inside',
    );

    print('Found ${children.length} children in wd share.');
    for (var c in children.take(5)) {
      print(' - ${c.name} (isDir: ${c.isDirectory()})');
    }

    // 4. Try to list the first directory child (Deep Browse test)
    final firstDir = children.firstWhere(
      (c) => c.isDirectory(),
      orElse: () => children.first,
    );
    if (firstDir.isDirectory()) {
      print('Deep browsing into: ${firstDir.path}');
      final subChildren = await conn.listFiles(firstDir);
      print('Found ${subChildren.length} children inside ${firstDir.name}');
      expect(subChildren, isNotNull);
    }

    print('Automated testing closed loop completed successfully!');
  });
}
