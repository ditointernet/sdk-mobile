enum DitoOperationStatus {
  sent('sent'),
  savedLocally('saved_locally');

  const DitoOperationStatus(this.nativeValue);

  final String nativeValue;
}

class DitoOperationResult {
  const DitoOperationResult(this.status);

  factory DitoOperationResult.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      throw const FormatException('Dito operation result map is required.');
    }

    final status = map['status'];
    if (status is! String) {
      throw const FormatException('Dito operation status is required.');
    }

    return DitoOperationResult(_statusFromNativeValue(status));
  }

  final DitoOperationStatus status;

  bool get wasSavedLocally => status == DitoOperationStatus.savedLocally;
}

DitoOperationStatus _statusFromNativeValue(String value) {
  for (final status in DitoOperationStatus.values) {
    if (status.nativeValue == value) {
      return status;
    }
  }

  throw FormatException('Unknown Dito operation status: $value.');
}
