import OpenAI from 'openai';
import { Readable } from 'stream';

export class TranscriptionService {
  private openai: OpenAI | null = null;

  constructor() {
    const apiKey = process.env.OPENAI_API_KEY;
    if (apiKey) {
      this.openai = new OpenAI({ apiKey });
    }
  }

  async transcribe(audioBuffer: Buffer): Promise<string | null> {
    if (!this.openai) {
      console.warn('OpenAI API key not configured, skipping transcription');
      return null;
    }

    try {
      const file = new File([audioBuffer], 'audio.m4a', { type: 'audio/m4a' });

      const transcription = await this.openai.audio.transcriptions.create({
        file,
        model: 'whisper-1',
        language: 'en',
      });

      return transcription.text;
    } catch (error) {
      console.error('Transcription error:', error);
      return null;
    }
  }
}
