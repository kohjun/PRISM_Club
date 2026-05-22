export type RevisionSource = 'SEED' | 'CONTRIBUTION' | 'ADMIN';

export interface RevisionDTO {
  id: string;
  block_id: string;
  version: number;
  block_type: string;
  title: string;
  body: string;
  source: RevisionSource;
  changed_by: { id: string; nickname: string | null } | null;
  changed_at: string;
  contribution_id: string | null;
}

export interface RevisionListDTO {
  items: RevisionDTO[];
  next_cursor: string | null;
}
