export type ShareTargetType = 'POST' | 'TOPIC_HUB' | 'EVENT' | 'PROFILE';

export interface SharePreviewDTO {
  type: ShareTargetType;
  id: string;
  title: string;
  description: string;
  image_url: string | null;
  deep_link: string;
  web_url: string;
}
