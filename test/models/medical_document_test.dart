import 'package:flutter_test/flutter_test.dart';
import 'package:medilocker/models/medical_document.dart';

void main() {
  group('MedicalDocument Model Tests', () {
    test('should format file size accurately', () {
      final docBytes = MedicalDocument(
        id: 'doc-1',
        userId: 'user-1',
        title: 'Blood Test',
        category: 'Lab Report',
        fileSize: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(docBytes.fileSizeFormatted, '500B');

      final docKb = MedicalDocument(
        id: 'doc-2',
        userId: 'user-1',
        title: 'X-Ray',
        category: 'Radiology',
        fileSize: 2048,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(docKb.fileSizeFormatted, '2.0KB');

      final docMb = MedicalDocument(
        id: 'doc-3',
        userId: 'user-1',
        title: 'MRI Scan',
        category: 'Radiology',
        fileSize: 5242880,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(docMb.fileSizeFormatted, '5.0MB');
    });

    test('should identify PDF and Image file types properly', () {
      final pdfDoc = MedicalDocument(
        id: 'doc-pdf',
        userId: 'user-1',
        title: 'Prescription',
        category: 'Prescription',
        fileName: 'prescription.pdf',
        fileType: 'application/pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(pdfDoc.isPdf, isTrue);
      expect(pdfDoc.isImage, isFalse);

      final imgDoc = MedicalDocument(
        id: 'doc-img',
        userId: 'user-1',
        title: 'Lab Report Scan',
        category: 'Lab Report',
        fileName: 'report.png',
        fileType: 'image/png',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(imgDoc.isImage, isTrue);
      expect(imgDoc.isPdf, isFalse);
    });
  });
}
