export type ReportTargetType =
  | 'POST'
  | 'REPLY'
  | 'ROOM'
  | 'USER'
  | 'REFERENCE'
  | 'DM_MESSAGE';

export type ReportStatus = 'OPEN' | 'RESOLVED' | 'DISMISSED';

export type ModerationActionType = 'HIDE' | 'RESTORE' | 'DISMISS';

export interface ReportDTO {
  id: string;
  reporter: { id: string; nickname: string | null };
  target_type: ReportTargetType;
  target_id: string;
  reason: string;
  details: string | null;
  status: ReportStatus;
  resolution: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  resolver_note: string | null;
  created_at: string;
}

export interface ReportListDTO {
  items: ReportDTO[];
}

export interface CreateReportInput {
  target_type: string;
  target_id: string;
  reason: string;
  details?: string;
}

export interface ResolveReportInput {
  action: string; // HIDE | RESTORE | DISMISS
  note?: string;
}

export interface ReportTargetSummaryDTO {
  type: ReportTargetType;
  id: string;
  preview: string;
  status: string | null;
  exists: boolean;
}

export interface ReportDetailDTO extends ReportDTO {
  target: ReportTargetSummaryDTO;
  actions: ModerationActionDTO[];
}

export interface ModerationActionDTO {
  id: string;
  actor: { id: string; nickname: string | null };
  action: ModerationActionType;
  target_type: ReportTargetType;
  target_id: string;
  report_id: string | null;
  note: string | null;
  created_at: string;
}
