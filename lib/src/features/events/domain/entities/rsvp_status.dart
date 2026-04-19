enum RsvpStatus {
  going(label: 'Going'),
  interested(label: 'Interested'),
  notGoing(label: 'Not going');

  const RsvpStatus({required this.label});

  final String label;
}
