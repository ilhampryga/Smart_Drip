import 'package:flutter/material.dart';

class DatePickerField extends StatefulWidget {
  const DatePickerField({
    super.key,
    required this.label,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.onDateChanged,
  });

  final String label;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime>? onDateChanged;

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: widget.firstDate ?? DateTime(2020),
      lastDate: widget.lastDate ?? now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      widget.onDateChanged?.call(picked);
    }
  }

  String get _displayText {
    if (_selectedDate == null) return widget.label;
    final d = _selectedDate!;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasDate = _selectedDate != null;

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasDate ? cs.primary : cs.outline,
            width: hasDate ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: hasDate
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasDate ? _displayText : widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: hasDate ? cs.primary : cs.onSurfaceVariant,
                fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: hasDate ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
