import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../controllers/events_controller.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({
    super.key,
    required this.controller,
    this.eventToEdit,
  });

  final EventsController controller;
  final Event? eventToEdit;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _hostController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  bool get _isEditing => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    _titleController = TextEditingController(text: event?.title);
    _hostController = TextEditingController(text: event?.hostName);
    _locationController = TextEditingController(text: event?.locationName);
    _descriptionController = TextEditingController(text: event?.description);
    if (event != null) {
      final localStart = event.startTime.toLocal();
      _selectedDate = DateTime(
        localStart.year,
        localStart.month,
        localStart.day,
      );
      _selectedTime = TimeOfDay.fromDateTime(localStart);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hostController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduledAtLabel = _selectedDate == null || _selectedTime == null
        ? 'Choose date and time'
        : '${DateTimeFormatter.shortDate(context, _selectedDate!)} at ${DateTimeFormatter.shortTime(context, _selectedTime!)}';

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Event' : 'Create Event')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _isEditing ? 'Update event details.' : 'Create a simple event.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hostController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Host name'),
                validator: _requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: _requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: _requiredField,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(scheduledAtLabel),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: const Text('Choose Date'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule_outlined),
                            label: const Text('Choose Time'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isEditing
                      ? 'Save Changes'
                      : 'Create Event',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = _selectedDate ?? today;
    final defaultLastDate = DateTime(now.year + 2, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate.isBefore(today) ? initialDate : today,
      lastDate: initialDate.isAfter(defaultLastDate)
          ? initialDate
          : defaultLastDate,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedTime = picked;
    });
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a date and time first.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final startTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final existingEvent = widget.eventToEdit;
    final duration = existingEvent == null
        ? const Duration(hours: 2)
        : existingEvent.endTime.difference(existingEvent.startTime);
    final endTime = startTime.add(
      duration > Duration.zero ? duration : const Duration(hours: 2),
    );
    final event = existingEvent == null
        ? Event(
            id: _buildId(_titleController.text.trim(), startTime),
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            locationName: _locationController.text.trim(),
            hostName: _hostController.text.trim(),
            startTime: startTime,
            endTime: endTime,
            attendeeCount: 0,
            viewerRsvpStatus: RsvpStatus.going,
            isOwnedByViewer: true,
          )
        : existingEvent.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            locationName: _locationController.text.trim(),
            hostName: _hostController.text.trim(),
            startTime: startTime,
            endTime: endTime,
          );

    final succeeded = existingEvent == null
        ? await widget.controller.createNewEvent(event)
        : await widget.controller.updateEvent(event);

    if (!mounted) {
      return;
    }

    if (!succeeded) {
      setState(() {
        _isSaving = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ??
                (_isEditing
                    ? 'Unable to update event.'
                    : 'Unable to create event.'),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Event updated.' : 'Event created.')),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    return null;
  }

  String _buildId(String title, DateTime startTime) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return '$slug-${startTime.millisecondsSinceEpoch}';
  }
}
