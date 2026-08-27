/// Hijo del hogar sin cuenta en el sistema (niños pequeños).
class HogarChild {
  final int? idHijo;
  final String nombre;
  final String apellido;
  final String? fechaNacimiento; // formateada "dd/MM/yyyy"

  String get fullName => '$nombre $apellido'.trim();

  const HogarChild({
    this.idHijo,
    required this.nombre,
    required this.apellido,
    this.fechaNacimiento,
  });

  factory HogarChild.fromJson(Map<String, dynamic> j) {
    String? parseDate(dynamic d) {
      if (d == null) return null;
      final s = d.toString().trim();
      if (s.isEmpty) return null;
      try {
        final dt = DateTime.parse(s);
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        return s;
      }
    }

    return HogarChild(
      idHijo: (j['id_hijo'] as num?)?.toInt(),
      nombre: (j['nombre'] ?? '').toString(),
      apellido: (j['apellido'] ?? '').toString(),
      fechaNacimiento: parseDate(j['fecha_nacimiento']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
  final bool cerradaManualmente;
  final List<FamilyMember> assignedStudents;
  final List<FamilyMember> householdChildren;
  final List<HogarChild> hogarChildren;
  final List<FamilyMember> uncles;
  final int? fatherEmployeeId;
  final int? motherEmployeeId;
  final String? papaNumEmpleado;
  final String? mamaNumEmpleado;
  final String? papaTelefono;
  final String? mamaTelefono;
  final String? papaFotoPerfilUrl;
  final String? mamaFotoPerfilUrl;
  final String? papaFechaNacimiento;
  final String? mamaFechaNacimiento;
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
    this.cerradaManualmente = false,
    this.assignedStudents = const [],
    this.householdChildren = const [],
    this.hogarChildren = const [],
    this.uncles = const [],
    this.fatherEmployeeId,
    this.motherEmployeeId,
    this.papaNumEmpleado,
    this.mamaNumEmpleado,
    this.papaTelefono,
    this.mamaTelefono,
    this.papaFotoPerfilUrl,
    this.mamaFotoPerfilUrl,
    this.papaFechaNacimiento,
    this.mamaFechaNacimiento,
  });

  factory Family.fromJson(Map<String, dynamic> j) {
    String? _parseDate(dynamic d) {
      if (d == null) return null;
      try {
        final date = DateTime.parse(d.toString());
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (_) {
        return d.toString();
      }
    }

    String? _normalizeRes(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final up = s.toUpperCase();
      if (up.startsWith('INT')) return 'Interna';
      if (up.startsWith('EXT')) return 'Externa';
      return s;
    }

    bool asBool(dynamic value) {
      return value == true ||
          value == 1 ||
          value?.toString() == '1' ||
          value?.toString().toLowerCase() == 'true';
    }

    final List<FamilyMember> householdChildren = [];
    final List<FamilyMember> assignedStudents = [];
    final List<FamilyMember> uncles = [];

    if (j['miembros'] is List) {
      for (final miembro in (j['miembros'] as List)) {
        if (miembro is Map<String, dynamic>) {
          final familyMember = FamilyMember.fromJson(miembro);
          final rol = (miembro['nombre_rol'] ?? '').toString();
          if (rol == 'HijoSanguineo' ||
              (rol != 'HijoEDI' && familyMember.tipoMiembro == 'HIJO')) {
            householdChildren.add(familyMember);
          } else if (rol == 'HijoEDI' ||
              familyMember.tipoMiembro == 'ALUMNO_ASIGNADO') {
            assignedStudents.add(familyMember);
          } else if (familyMember.tipoMiembro == 'TIO_EDI') {
            uncles.add(familyMember);
          }
        }
      }
    }

    final List<HogarChild> hogarChildren = [];
    if (j['hijos_hogar'] is List) {
      for (final h in (j['hijos_hogar'] as List)) {
        if (h is Map<String, dynamic>) {
          hogarChildren.add(HogarChild.fromJson(h));
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
      cerradaManualmente: asBool(j['cerrada_manualmente']),
      householdChildren: householdChildren,
      assignedStudents: assignedStudents,
      hogarChildren: hogarChildren,
      uncles: uncles,
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
      papaFechaNacimiento: _parseDate(j['papa_fecha_nacimiento']),
      mamaFechaNacimiento: _parseDate(j['mama_fecha_nacimiento']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id_familia': id,
    'nombre_familia': familyName,
    'padre': fatherName,
    'madre': motherName,
    'residencia': residencia,
    'direccion': direccion,
    'cerrada_manualmente': cerradaManualmente,

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
    bool? cerradaManualmente,
    List<FamilyMember>? assignedStudents,
    List<FamilyMember>? householdChildren,
    List<FamilyMember>? uncles,
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
      cerradaManualmente: cerradaManualmente ?? this.cerradaManualmente,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      householdChildren: householdChildren ?? this.householdChildren,
      uncles: uncles ?? this.uncles,
      fatherEmployeeId: fatherEmployeeId ?? this.fatherEmployeeId,
      motherEmployeeId: motherEmployeeId ?? this.motherEmployeeId,
      papaNumEmpleado: papaNumEmpleado ?? this.papaNumEmpleado,
      mamaNumEmpleado: mamaNumEmpleado ?? this.mamaNumEmpleado,
    );
  }
}
