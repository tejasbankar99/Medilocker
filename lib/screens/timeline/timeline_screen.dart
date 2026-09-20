import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/medical_document.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String? _filterCategory;
  String? _filterDoctor;
  String? _filterHospital;
  DateTimeRange? _filterDateRange;
  bool _showFilters = false;

  List<MedicalDocument> _applyFilters(List<MedicalDocument> docs) {
    var filtered = List<MedicalDocument>.from(docs);

    // Sort by documentDate (fallback createdAt), oldest first
    filtered.sort((a, b) {
      final aDate = a.documentDate ?? a.createdAt;
      final bDate = b.documentDate ?? b.createdAt;
      return aDate.compareTo(bDate);
    });

    if (_filterCategory != null) {
      filtered = filtered.where((d) => d.category == _filterCategory).toList();
    }
    if (_filterDoctor != null && _filterDoctor!.isNotEmpty) {
      filtered = filtered
          .where((d) =>
              d.doctorName?.toLowerCase().contains(_filterDoctor!.toLowerCase()) ?? false)
          .toList();
    }
    if (_filterHospital != null && _filterHospital!.isNotEmpty) {
      filtered = filtered
          .where((d) =>
              d.hospitalName?.toLowerCase().contains(_filterHospital!.toLowerCase()) ?? false)
          .toList();
    }
    if (_filterDateRange != null) {
      filtered = filtered.where((d) {
        final date = d.documentDate ?? d.createdAt;
        return date.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) &&
            date.isBefore(_filterDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    return filtered;
  }

  /// Group documents by "Month Year" label
  Map<String, List<MedicalDocument>> _groupByMonth(List<MedicalDocument> docs) {
    final Map<String, List<MedicalDocument>> grouped = {};
    for (final doc in docs) {
      final date = doc.documentDate ?? doc.createdAt;
      final key = DateFormat('MMMM yyyy').format(date);
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    return grouped;
  }

  bool get _hasActiveFilters =>
      _filterCategory != null || _filterDateRange != null ||
      (_filterDoctor?.isNotEmpty ?? false) || (_filterHospital?.isNotEmpty ?? false);

  void _clearFilters() => setState(() {
        _filterCategory = null;
        _filterDoctor = null;
        _filterHospital = null;
        _filterDateRange = null;
      });

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _filterDateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) setState(() => _filterDateRange = range);
  }

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocumentProvider>().documents;
    final filtered = _applyFilters(docs);
    final grouped = _groupByMonth(filtered);
    final monthKeys = grouped.keys.toList();

    // Unique doctors and hospitals for filter dropdowns
    final doctors = docs
        .map((d) => d.doctorName)
        .where((d) => d != null && d.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList()
      ..sort();
    final hospitals = docs
        .map((d) => d.hospitalName)
        .where((h) => h != null && h.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Timeline'),
        actions: [
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
            ),
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _hasActiveFilters ? AppTheme.primary : AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Panel ──────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showFilters
                ? _FilterPanel(
                    selectedCategory: _filterCategory,
                    selectedDoctor: _filterDoctor,
                    selectedHospital: _filterHospital,
                    dateRange: _filterDateRange,
                    doctors: doctors,
                    hospitals: hospitals,
                    onCategoryChanged: (v) => setState(() => _filterCategory = v),
                    onDoctorChanged: (v) => setState(() => _filterDoctor = v),
                    onHospitalChanged: (v) => setState(() => _filterHospital = v),
                    onDateRangeTap: _pickDateRange,
                    onClearDateRange: () => setState(() => _filterDateRange = null),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Timeline Body ─────────────────────────────────────────────
          Expanded(
            child: docs.isEmpty
                ? _EmptyTimeline()
                : filtered.isEmpty
                    ? _NoResults(onClear: _clearFilters)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: monthKeys.length,
                        itemBuilder: (context, groupIdx) {
                          final month = monthKeys[groupIdx];
                          final monthDocs = grouped[month]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Month header
                              Padding(
                                padding: const EdgeInsets.only(top: 20, bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppTheme.primary.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        month,
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                          height: 1, color: AppTheme.border),
                                    ),
                                  ],
                                ),
                              ),
                              // Documents in this month
                              ...monthDocs.asMap().entries.map((e) {
                                final isLast = e.key == monthDocs.length - 1 &&
                                    groupIdx == monthKeys.length - 1;
                                return _TimelineEntry(
                                  document: e.value,
                                  isLast: isLast,
                                  onTap: () =>
                                      context.go('/documents/detail', extra: e.value),
                                );
                              }),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline Entry ────────────────────────────────────────────────────────────

class _TimelineEntry extends StatelessWidget {
  final MedicalDocument document;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineEntry(
      {required this.document, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.categoryColor(document.category);
    final date = document.documentDate ?? document.createdAt;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: date + line
          SizedBox(
            width: 72,
            child: Column(
              children: [
                // Date chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    DateFormat('dd MMM').format(date),
                    style: TextStyle(
                        color: catColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                // Vertical line
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: catColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              document.category,
                              style: TextStyle(
                                  color: catColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            document.isPdf
                                ? Icons.picture_as_pdf_rounded
                                : document.isImage
                                    ? Icons.image_rounded
                                    : Icons.insert_drive_file_rounded,
                            color: catColor,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        document.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (document.doctorName != null ||
                          document.hospitalName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [document.doctorName, document.hospitalName]
                              .where((s) => s != null)
                              .join(' · '),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Panel ──────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final String? selectedCategory;
  final String? selectedDoctor;
  final String? selectedHospital;
  final DateTimeRange? dateRange;
  final List<String> doctors;
  final List<String> hospitals;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onDoctorChanged;
  final ValueChanged<String?> onHospitalChanged;
  final VoidCallback onDateRangeTap;
  final VoidCallback onClearDateRange;

  const _FilterPanel({
    required this.selectedCategory,
    required this.selectedDoctor,
    required this.selectedHospital,
    required this.dateRange,
    required this.doctors,
    required this.hospitals,
    required this.onCategoryChanged,
    required this.onDoctorChanged,
    required this.onHospitalChanged,
    required this.onDateRangeTap,
    required this.onClearDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text('Filter Timeline',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          // Category filter
          DropdownButtonFormField<String>(
            value: selectedCategory,
            dropdownColor: AppTheme.card,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Category',
              isDense: true,
              prefixIcon:
                  Icon(Icons.category_rounded, color: AppTheme.textSecondary, size: 18),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Categories')),
              ...MedicalDocument.categories.map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Doctor filter
              if (doctors.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedDoctor,
                    dropdownColor: AppTheme.card,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Doctor',
                      isDense: true,
                      prefixIcon: Icon(Icons.medical_services_outlined,
                          color: AppTheme.textSecondary, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Doctors')),
                      ...doctors.map(
                        (d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: onDoctorChanged,
                  ),
                ),
              if (doctors.isNotEmpty && hospitals.isNotEmpty) const SizedBox(width: 10),
              // Hospital filter
              if (hospitals.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedHospital,
                    dropdownColor: AppTheme.card,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Hospital',
                      isDense: true,
                      prefixIcon: Icon(Icons.local_hospital_outlined,
                          color: AppTheme.textSecondary, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Hospitals')),
                      ...hospitals.map(
                        (h) => DropdownMenuItem(value: h, child: Text(h, overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: onHospitalChanged,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Date range
          GestureDetector(
            onTap: onDateRangeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: dateRange != null
                        ? AppTheme.primary.withOpacity(0.5)
                        : AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_rounded,
                      color:
                          dateRange != null ? AppTheme.primary : AppTheme.textSecondary,
                      size: 18),
                  const SizedBox(width: 10),
                  Text(
                    dateRange == null
                        ? 'Select Date Range'
                        : '${DateFormat('dd MMM yyyy').format(dateRange!.start)}  →  ${DateFormat('dd MMM yyyy').format(dateRange!.end)}',
                    style: TextStyle(
                      color: dateRange != null ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (dateRange != null)
                    GestureDetector(
                      onTap: onClearDateRange,
                      child: const Icon(Icons.close_rounded,
                          color: AppTheme.textSecondary, size: 16),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty States ──────────────────────────────────────────────────────────────

class _EmptyTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.timeline_rounded, color: AppTheme.primary, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('No Timeline Yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Upload medical documents to see\nyour health history here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/documents/upload'),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload Record'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final VoidCallback onClear;
  const _NoResults({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 12),
          const Text('No results for this filter',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(onPressed: onClear, child: const Text('Clear Filters')),
        ],
      ),
    );
  }
}
