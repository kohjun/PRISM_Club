import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';

const EVENT_DURATION_HOURS = 2;
const PROD_ID = '-//PRISM Club//prism.club//KO';

/**
 * RFC 5545 ICS builder for a single EventCard (P3.4).
 *
 * EventCard has no end time today — we default DTEND to startsAt+2h so
 * the imported calendar block is not zero-length. All wall-clock times
 * are emitted in `TZID=Asia/Seoul` since every PRISM event surface is
 * KST today; calendar apps then convert per the user's device timezone.
 */
@Injectable()
export class EventIcsService {
  constructor(private readonly prisma: PrismaService) {}

  async buildIcs(eventCardId: string): Promise<string> {
    const card = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
    });
    if (!card) {
      throw new NotFoundException(`Event not found: ${eventCardId}`);
    }
    const start = card.startsAt;
    const end = new Date(start.getTime() + EVENT_DURATION_HOURS * 60 * 60 * 1000);

    const lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      `PRODID:${PROD_ID}`,
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VTIMEZONE',
      'TZID:Asia/Seoul',
      'BEGIN:STANDARD',
      'DTSTART:19700101T000000',
      'TZOFFSETFROM:+0900',
      'TZOFFSETTO:+0900',
      'TZNAME:KST',
      'END:STANDARD',
      'END:VTIMEZONE',
      'BEGIN:VEVENT',
      `UID:${card.externalEventId}@prism.club`,
      `DTSTAMP:${formatUtc(new Date())}`,
      `DTSTART;TZID=Asia/Seoul:${formatKst(start)}`,
      `DTEND;TZID=Asia/Seoul:${formatKst(end)}`,
      `SUMMARY:${escape(card.title)}`,
      `LOCATION:${escape(`${card.venueName}, ${card.region}`)}`,
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    // RFC 5545 requires CRLF line endings; some calendar apps tolerate
    // LF but Outlook is strict.
    return lines.join('\r\n') + '\r\n';
  }
}

/** "YYYYMMDDTHHMMSSZ" in UTC. */
function formatUtc(d: Date): string {
  return (
    d.getUTCFullYear().toString().padStart(4, '0') +
    (d.getUTCMonth() + 1).toString().padStart(2, '0') +
    d.getUTCDate().toString().padStart(2, '0') +
    'T' +
    d.getUTCHours().toString().padStart(2, '0') +
    d.getUTCMinutes().toString().padStart(2, '0') +
    d.getUTCSeconds().toString().padStart(2, '0') +
    'Z'
  );
}

/** "YYYYMMDDTHHMMSS" in Asia/Seoul wall-clock (no Z suffix). */
function formatKst(d: Date): string {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return (
    kst.getUTCFullYear().toString().padStart(4, '0') +
    (kst.getUTCMonth() + 1).toString().padStart(2, '0') +
    kst.getUTCDate().toString().padStart(2, '0') +
    'T' +
    kst.getUTCHours().toString().padStart(2, '0') +
    kst.getUTCMinutes().toString().padStart(2, '0') +
    kst.getUTCSeconds().toString().padStart(2, '0')
  );
}

/** RFC 5545 TEXT escape: backslash, semicolon, comma, newline. */
function escape(s: string): string {
  return s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');
}
