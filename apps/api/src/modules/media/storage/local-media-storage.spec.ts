import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { LocalMediaStorage } from './local-media-storage';

describe('LocalMediaStorage', () => {
  let tempDir: string;
  let envSnapshot: NodeJS.ProcessEnv;

  beforeEach(() => {
    envSnapshot = { ...process.env };
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'prism-media-'));
    process.env.UPLOADS_DIR = tempDir;
  });

  afterEach(() => {
    process.env = envSnapshot;
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  test('upload writes the bytes to UPLOADS_DIR and returns /uploads/<id>.<ext>', async () => {
    const storage = new LocalMediaStorage();
    const result = await storage.upload({
      id: 'abc-123',
      ext: 'png',
      contentType: 'image/png',
      body: Buffer.from([0x89, 0x50, 0x4e, 0x47]),
    });
    expect(result.urlPath).toBe('/uploads/abc-123.png');

    const written = fs.readFileSync(path.join(tempDir, 'abc-123.png'));
    expect(written.length).toBe(4);
    expect(written[0]).toBe(0x89);
  });

  test('mode() includes the configured uploads dir', () => {
    const storage = new LocalMediaStorage();
    expect(storage.mode()).toContain('local(');
    expect(storage.mode()).toContain(tempDir);
  });
});
