class Student {
  const Student({
    required this.id,
    required this.name,
    required this.email,
    this.studentId = '',
    this.course = '',
    this.yearLevel = '',
    this.role = 'student',
    this.isActive = true,
  });
  final String id, name, email, studentId, course, yearLevel;
  final String role;
  final bool isActive;

  factory Student.fromTrustedUser(dynamic data) {
    if (data is! Map || data['role'] is! String) {
      throw const FormatException('Invalid user response.');
    }
    if (data['role'] != 'student') throw const StudentOnlyException();
    if (data['isActive'] != true ||
        data['_id'] is! String ||
        (data['_id'] as String).isEmpty ||
        data['name'] is! String ||
        data['email'] is! String) {
      throw const FormatException('Invalid student response.');
    }
    return Student(
      id: data['_id'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      studentId: data['studentId'] is String ? data['studentId'] as String : '',
      course: data['course'] is String ? data['course'] as String : '',
      yearLevel: data['yearLevel'] is String ? data['yearLevel'] as String : '',
      role: data['role'] as String,
      isActive: data['isActive'] as bool,
    );
  }
}

class StudentOnlyException implements Exception {
  const StudentOnlyException();
}
