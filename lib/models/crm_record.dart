class CrmRecord {
  final String id;
  final String entityType; // 'product', 'lead', 'task', 'partner', 'partner_visit', 'followup', 'collection', 'meeting', 'notice', 'quick_alert', 'activity_log'
  final String title;
  final String? description;
  final String team; // 'Gulbarga', 'Solapur', 'Both'
  final String status;
  final String priority; // 'low', 'normal', 'high', 'urgent'
  final String? assignedTo;
  final String? partnerId;
  final String? productId;
  final String? clientName;
  final double amountDue;
  final double amountReceived;
  final DateTime? dueDate;
  final DateTime? meetingTime;
  final Map<String, dynamic> extraData;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CrmRecord({
    required this.id,
    required this.entityType,
    required this.title,
    this.description,
    this.team = 'Gulbarga',
    this.status = 'new',
    this.priority = 'normal',
    this.assignedTo,
    this.partnerId,
    this.productId,
    this.clientName,
    this.amountDue = 0.0,
    this.amountReceived = 0.0,
    this.dueDate,
    this.meetingTime,
    this.extraData = const {},
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  // Helper getters
  String? get statusChangedBy => extraData['status_changed_by'] as String?;
  String? get statusChangedAt => extraData['status_changed_at'] as String?;
  String? get assignedPerson {
    if (assignedTo != null && assignedTo!.trim().isNotEmpty) {
      return assignedTo!.trim();
    }
    final extra = extraData['assigned_to']?.toString().trim();
    if (extra != null && extra.isNotEmpty) {
      return extra;
    }
    return null;
  }
  String? get pipelineSection => extraData['pipeline_section'] as String?;
  String get leadStage => extraData['stage'] as String? ?? 'New';
  String get pitchNotes => extraData['pitch_notes'] as String? ?? '';
  String get clientPhone => extraData['phone'] as String? ?? '';
  List<String> get visitSteps =>
      (extraData['steps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
      [];
  String? get nextVisitDate => extraData['next_visit_date'] as String?;
  List<String> get seenBy =>
      (extraData['seen_by'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
      [];
  List<dynamic> get acknowledgedBy =>
      (extraData['acknowledged_by'] as List<dynamic>?) ?? [];
  String get productPrice =>
      extraData['price']?.toString() ?? extraData['pricing']?.toString() ?? '0';
  List<String> get productFeatures =>
      (extraData['features'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
      [];

  factory CrmRecord.fromJson(Map<String, dynamic> json) {
    return CrmRecord(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      team: json['team'] as String? ?? 'Gulbarga',
      status: json['status'] as String? ?? 'new',
      priority: json['priority'] as String? ?? 'normal',
      assignedTo: json['assigned_to'] as String?,
      partnerId: json['partner_id'] as String?,
      productId: json['product_id'] as String?,
      clientName: json['client_name'] as String?,
      amountDue: (json['amount_due'] is num)
          ? (json['amount_due'] as num).toDouble()
          : double.tryParse(json['amount_due']?.toString() ?? '0') ?? 0.0,
      amountReceived: (json['amount_received'] is num)
          ? (json['amount_received'] as num).toDouble()
          : double.tryParse(json['amount_received']?.toString() ?? '0') ?? 0.0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'])
          : null,
      meetingTime: json['meeting_time'] != null
          ? DateTime.tryParse(json['meeting_time'])
          : null,
      extraData: json['extra_data'] as Map<String, dynamic>? ?? {},
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'title': title,
      'description': description,
      'team': team,
      'status': status,
      'priority': priority,
      'assigned_to': assignedTo,
      'partner_id': partnerId,
      'product_id': productId,
      'client_name': clientName,
      'amount_due': amountDue,
      'amount_received': amountReceived,
      'due_date': dueDate?.toIso8601String(),
      'meeting_time': meetingTime?.toIso8601String(),
      'extra_data': extraData,
      'created_by': createdBy,
    };
  }

  CrmRecord copyWith({
    String? title,
    String? description,
    String? team,
    String? status,
    String? priority,
    String? assignedTo,
    String? partnerId,
    String? productId,
    String? clientName,
    double? amountDue,
    double? amountReceived,
    DateTime? dueDate,
    DateTime? meetingTime,
    Map<String, dynamic>? extraData,
  }) {
    return CrmRecord(
      id: id,
      entityType: entityType,
      title: title ?? this.title,
      description: description ?? this.description,
      team: team ?? this.team,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      partnerId: partnerId ?? this.partnerId,
      productId: productId ?? this.productId,
      clientName: clientName ?? this.clientName,
      amountDue: amountDue ?? this.amountDue,
      amountReceived: amountReceived ?? this.amountReceived,
      dueDate: dueDate ?? this.dueDate,
      meetingTime: meetingTime ?? this.meetingTime,
      extraData: extraData ?? this.extraData,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

