/// A random-access byte source addressed by an opaque string id.
///
/// Implemented by `SmbService` today; the same proxy can serve FTP / WebDAV /
/// other storage providers later by implementing this interface.
abstract class RangeSource {
  /// Total byte length of the resource identified by [id].
  Future<int> length(String id);

  /// Byte stream for [id] over the inclusive range [start, endInclusive].
  Future<Stream<List<int>>> read(String id, int start, int endInclusive);
}
