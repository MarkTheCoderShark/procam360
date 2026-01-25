import { createClient, SupabaseClient } from '@supabase/supabase-js';

const STORAGE_BUCKET = 'media';

export interface UploadResult {
  url: string;
  path: string;
}

export interface StorageService {
  uploadFile(buffer: Buffer, fileName: string, contentType: string, folder?: string): Promise<UploadResult>;
  deleteFile(path: string): Promise<void>;
  getSignedUploadUrl(fileName: string, folder?: string): Promise<{ signedUrl: string; path: string; publicUrl: string }>;
  getPublicUrl(path: string): string;
}

class SupabaseStorageService implements StorageService {
  private supabase: SupabaseClient;
  private bucketUrl: string;

  constructor() {
    const supabaseUrl = process.env.SUPABASE_URL!;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY!;

    this.supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    this.bucketUrl = `${supabaseUrl}/storage/v1/object/public/${STORAGE_BUCKET}`;
  }

  async uploadFile(
    buffer: Buffer,
    fileName: string,
    contentType: string,
    folder: string = 'photos'
  ): Promise<UploadResult> {
    const path = `${folder}/${Date.now()}-${fileName}`;

    const { data, error } = await this.supabase.storage
      .from(STORAGE_BUCKET)
      .upload(path, buffer, {
        contentType,
        cacheControl: '3600',
        upsert: false,
      });

    if (error) {
      throw new Error(`Failed to upload file: ${error.message}`);
    }

    return {
      url: this.getPublicUrl(data.path),
      path: data.path,
    };
  }

  async deleteFile(path: string): Promise<void> {
    const { error } = await this.supabase.storage
      .from(STORAGE_BUCKET)
      .remove([path]);

    if (error) {
      console.error(`Failed to delete file: ${error.message}`);
    }
  }

  async getSignedUploadUrl(
    fileName: string,
    folder: string = 'photos'
  ): Promise<{ signedUrl: string; path: string; publicUrl: string }> {
    // Sanitize filename: replace spaces and special chars with underscores
    const sanitizedFileName = fileName
      .replace(/\s+/g, '_')
      .replace(/[^a-zA-Z0-9._-]/g, '_');
    const path = `${folder}/${Date.now()}-${sanitizedFileName}`;

    const { data, error } = await this.supabase.storage
      .from(STORAGE_BUCKET)
      .createSignedUploadUrl(path);

    if (error) {
      throw new Error(`Failed to create signed upload URL: ${error.message}`);
    }

    return {
      signedUrl: data.signedUrl,
      path,
      publicUrl: this.getPublicUrl(path),
    };
  }

  getPublicUrl(path: string): string {
    return `${this.bucketUrl}/${path}`;
  }
}

let storageService: StorageService | null = null;

export function getStorageService(): StorageService {
  if (!storageService) {
    storageService = new SupabaseStorageService();
  }
  return storageService;
}

export { SupabaseStorageService };
