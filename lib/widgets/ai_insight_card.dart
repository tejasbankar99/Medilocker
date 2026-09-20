import 'package:flutter/material.dart';
import '../models/ai_insight.dart';
import '../theme/app_theme.dart';

class AiInsightCard extends StatelessWidget {
  final AiInsight? insight;
  final bool isLoading;

  const AiInsightCard({
    super.key,
    required this.insight,
    required this.isLoading,
  });

  static const String _disclaimer =
      '⚠️ AI-generated insights are for informational purposes only. '
      'This is NOT medical advice, diagnosis, or treatment. '
      'Always consult a qualified healthcare professional.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF7C3AED), size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI Insights',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Beta',
                  style: TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Content card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
          ),
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    // Loading state
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED))),
              SizedBox(height: 12),
              Text('Loading insights...',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // No insight yet
    if (insight == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_outlined,
                color: AppTheme.textSecondary, size: 32),
            const SizedBox(height: 10),
            const Text('No insights available yet.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    // Processing
    if (insight!.isProcessing) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Gemini is analyzing your document...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('This usually takes 10–20 seconds.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    // Failed
    if (insight!.hasFailed) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Analysis failed: ${insight!.errorMessage ?? "Unknown error"}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Completed — show full insights
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Disclaimer banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.08),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border(
                bottom: BorderSide(
                    color: AppTheme.warning.withOpacity(0.2))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.warning.withOpacity(0.8), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _disclaimer,
                  style: TextStyle(
                      color: AppTheme.warning.withOpacity(0.9),
                      fontSize: 10,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              if (insight!.summary != null &&
                  insight!.summary!.isNotEmpty) ...[
                _InsightSection(
                  icon: Icons.summarize_rounded,
                  title: 'Summary',
                  content: insight!.summary!,
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(height: 14),
              ],

              // Key Findings
              if (insight!.keyFindings != null &&
                  insight!.keyFindings!.isNotEmpty) ...[
                _InsightSection(
                  icon: Icons.search_rounded,
                  title: 'Key Findings',
                  content: insight!.keyFindings!,
                  color: AppTheme.secondary,
                ),
                const SizedBox(height: 14),
              ],

              // Comparison with previous
              if (insight!.hasComparison) ...[
                _InsightSection(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Comparison with Previous Report',
                  content: insight!.comparisonWithPrevious!,
                  color: AppTheme.primary,
                  highlight: true,
                ),
                const SizedBox(height: 14),
              ],

              // Parameter changes
              if (insight!.parameterChanges.isNotEmpty) ...[
                _ParameterChangesSection(
                    changes: insight!.parameterChanges),
                const SizedBox(height: 14),
              ],

              // Health trends
              if (insight!.healthTrends != null &&
                  insight!.healthTrends!.isNotEmpty) ...[
                _InsightSection(
                  icon: Icons.trending_up_rounded,
                  title: 'Health Trends',
                  content: insight!.healthTrends!,
                  color: const Color(0xFF81C784),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final bool highlight;

  const _InsightSection({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: highlight
          ? BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ParameterChangesSection extends StatelessWidget {
  final Map<String, dynamic> changes;
  const _ParameterChangesSection({required this.changes});

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart_rounded,
                color: AppTheme.warning, size: 14),
            const SizedBox(width: 6),
            const Text('Parameter Changes',
                style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: changes.entries.toList().asMap().entries.map((e) {
              final isLast = e.key == changes.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            e.value.key,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${e.value.value}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 12, endIndent: 12),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
