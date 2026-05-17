export interface NotificationDTO {
  id: string;
  type: string;
  is_read: boolean;
  payload: Record<string, unknown>;
  created_at: string;
}

export interface NotificationListDTO {
  items: NotificationDTO[];
  next_cursor: string | null;
  unread_count: number;
}

export interface UnreadCountDTO {
  count: number;
}
