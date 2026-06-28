import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../controllers/events_controller.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, required this.controller});

  final EventsController controller;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hostController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

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
      appBar: AppBar(title: const Text('Create Event')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Create a simple event.',
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
                child: Text(_isSaving ? 'Saving...' : 'Create Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
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
    final endTime = startTime.add(const Duration(hours: 2));
    final event = Event(
      id: _buildId(_titleController.text.trim(), startTime),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      locationName: _locationController.text.trim(),
      hostName: _hostController.text.trim(),
      startTime: startTime,
      endTime: endTime,
      attendeeCount: 0,
      viewerRsvpStatus: RsvpStatus.going,
    );

    final succeeded = await widget.controller.createNewEvent(event);

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
            widget.controller.errorMessage ?? 'Unable to create event.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Event created.')));
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
