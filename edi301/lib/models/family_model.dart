class FamilyMember {
  final int idMiembro;
  final int idUsuario;
  final String fullName;
  final String tipoMiembro;

  final int? matricula;
  final String? telefono;
  final String? carrera;
  final String? fechaNacimiento;
  final String? fotoPerfil;

  FamilyMember({
    required this.idMiembro,
    required this.idUsuario,
    required this.fullName,
    required this.tipoMiembro,
    this.matricula,
    this.telefono,
    this.carrera,
    this.fechaNacimiento,
    this.fotoPerfil,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> j) {
    final nombre = j['nombre'] ?? '';
    final apellido = j['apellido'] ?? '';

    String? parseDate(dynamic d) {
      if (d == null) return null;
      try {
        final date = DateTime.parse(d.toString());
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (e) {
        return d.toString();
      }
    }

    return FamilyMember(
      idMiembro: (j['id_miembro'] ?? 0) as int,
      idUsuario: (j['id_usuario'] ?? 0) as int,
      fullName: '$nombre $apellido'.trim(),
      tipoMiembro: (j['tipo_miembro'] ?? 'HIJO') as String,
      matricula: (j['matricula'] as num?)?.toInt(),
      telefono: j['telefono']?.toString(),
      carrera: j['carrera']?.toString(),
      fechaNacimiento: parseDate(j['fecha_nacimiento']),
      fotoPerfil: j['foto_perfil_url']?.toString(),
    );
  }
}

class Family {
  final int? id;

  final String familyName;
  final String? fatherName;
  final String? motherName;
  final String? residencia;
  final String? direccion;
  final String? descripcion;
  final String? fotoPortadaUrl;
  final String? fotoPerfilUrl;
  final List<FamilyMember> assignedStudents;
  final List<FamilyMember> householdChildren;
  final int? fatherEmployeeId;
  final int? motherEmployeeId;
  final String? papaNumEmpleado;
  final String? mamaNumEmpleado;
  final String? papaTelefono;
  final String? mamaTelefono;
  final String? papaFotoPerfilUrl;
  final String? mamaFotoPerfilUrl;
  String get residence => residencia ?? '';
  const Family({
    required this.id,
    required this.familyName,
    this.fatherName,
    this.motherName,
    this.residencia,
    this.direccion,
    this.descripcion,
    this.fotoPortadaUrl,
    this.fotoPerfilUrl,
    this.assignedStudents = const [],
    this.householdChildren = const [],
    this.fatherEmployeeId,
    this.motherEmployeeId,
    this.papaNumEmpleado,
    this.mamaNumEmpleado,
    this.papaTelefono,
    this.mamaTelefono,
    this.papaFotoPerfilUrl,
    this.mamaFotoPerfilUrl,
  });

  factory Family.fromJson(Map<String, dynamic> j) {
    String? _normalizeRes(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final up = s.toUpperCase();
      if (up.startsWith('INT')) return 'Interna';
      if (up.startsWith('EXT')) return 'Externa';
      return s;
    }

    final List<FamilyMember> householdChildren = [];
    final List<FamilyMember> assignedStudents = [];

    if (j['miembros'] is List) {
      for (final miembro in (j['miembros'] as List)) {
        if (miembro is Map<String, dynamic>) {
          final familyMember = FamilyMember.fromJson(miembro);
          if (familyMember.tipoMiembro == 'HIJO') {
            householdChildren.add(familyMember);
          } else if (familyMember.tipoMiembro == 'ALUMNO_ASIGNADO') {
            assignedStudents.add(familyMember);
          }
        }
      }
    }

    return Family(
      id: (j['id_familia'] ?? j['FamiliaID'] ?? j['id']) as int?,
      familyName:
          (j['nombre_familia'] ?? j['Nombre_Familia'] ?? j['nombre'] ?? '')
              .toString(),
      fatherName:
          (j['papa_nombre'] ??
                  j['Padre'] ??
                  j['padre'] ??
                  j['fatherName'] ??
                  j['nombre_padre'])
              ?.toString(),
      motherName:
          (j['mama_nombre'] ??
                  j['Madre'] ??
                  j['madre'] ??
                  j['motherName'] ??
                  j['nombre_madre'])
              ?.toString(),
      residencia: _normalizeRes(j['residencia'] ?? j['Residencia']),
      direccion: (j['direccion'] ?? j['Direccion'])?.toString(),
      descripcion: (j['descripcion'] ?? j['Descripcion'])?.toString(),
      fotoPortadaUrl: j['foto_portada_url']?.toString(),
      fotoPerfilUrl: j['foto_perfil_url']?.toString(),
      householdChildren: householdChildren,
      assignedStudents: assignedStudents,
      fatherEmployeeId:
          (j['papa_id'] ??
                  j['Papa_id'] ??
                  j['PapaId'] ??
                  j['father_employee_id'])
              as int?,
      motherEmployeeId:
          (j['mama_id'] ??
                  j['Mama_id'] ??
                  j['MamaId'] ??
                  j['mother_employee_id'])
              as int?,
      papaNumEmpleado: j['papa_num_empleado']?.toString(),
      mamaNumEmpleado: j['mama_num_empleado']?.toString(),
      papaTelefono: j['papa_telefono']?.toString(),
      mamaTelefono: j['mama_telefono']?.toString(),
      papaFotoPerfilUrl: j['papa_foto_perfil_url']?.toString(),
      mamaFotoPerfilUrl: j['mama_foto_perfil_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id_familia': id,
    'nombre_familia': familyName,
    'padre': fatherName,
    'madre': motherName,
    'residencia': residencia,
    'direccion': direccion,

    'papa_id': fatherEmployeeId,
    'mama_id': motherEmployeeId,
  };

  Family copyWith({
    int? id,
    String? familyName,
    String? fatherName,
    String? motherName,
    String? residencia,
    String? direccion,
    String? descripcion,
    String? fotoPortadaUrl,
    String? fotoPerfilUrl,
    List<FamilyMember>? assignedStudents,
    List<FamilyMember>? householdChildren,
    int? fatherEmployeeId,
    int? motherEmployeeId,
    String? papaNumEmpleado,
    String? mamaNumEmpleado,
  }) {
    return Family(
      id: id ?? this.id,
      familyName: familyName ?? this.familyName,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      residencia: residencia ?? this.residencia,
      direccion: direccion ?? this.direccion,
      descripcion: descripcion ?? this.descripcion,
      fotoPortadaUrl: fotoPortadaUrl ?? this.fotoPortadaUrl,
      fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      householdChildren: householdChildren ?? this.householdChildren,
      fatherEmployeeId: fatherEmployeeId ?? this.fatherEmployeeId,
      motherEmployeeId: motherEmployeeId ?? this.motherEmployeeId,
      papaNumEmpleado: papaNumEmpleado ?? this.papaNumEmpleado,
      mamaNumEmpleado: mamaNumEmpleado ?? this.mamaNumEmpleado,
    );
  }
}
