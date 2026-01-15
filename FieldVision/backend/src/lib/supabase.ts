import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY!;

export const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

export const STORAGE_BUCKET = 'media';

export interface UploadResult {
  url: string;
  path: string;
}

export async function uploadFile(
  file: Buffer,
  fileName: string,
  contentType: string,
  folder: string = 'photos'
): Promise<UploadResult> {
  const path = `${folder}/${Date.now()}-${fileName}`;

  const { data, error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(path, file, {
      contentType,
      cacheControl: '3600',
      upsert: false,
    });

  if (error) {
    throw new Error(`Failed to upload file: ${error.message}`);
  }

  const { data: urlData } = supabase.storage
    .from(STORAGE_BUCKET)
    .getPublicUrl(path);

  return {
    url: urlData.publicUrl,
    path: data.path,
  };
}

export async function uploadThumbnail(
  file: Buffer,
  fileName: string
): Promise<UploadResult> {
  return uploadFile(file, fileName, 'image/jpeg', 'thumbnails');
}

export async function uploadVoiceNote(
  file: Buffer,
  fileName: string
): Promise<UploadResult> {
  return uploadFile(file, fileName, 'audio/m4a', 'voice-notes');
}

export async function deleteFile(path: string): Promise<void> {
  const { error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .remove([path]);

  if (error) {
    console.error(`Failed to delete file: ${error.message}`);
  }
}

export async function getSignedUrl(
  path: string,
  expiresIn: number = 3600
): Promise<string> {
  const { data, error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .createSignedUrl(path, expiresIn);

  if (error) {
    throw new Error(`Failed to create signed URL: ${error.message}`);
  }

  return data.signedUrl;
}

export async function getSignedUploadUrl(
  fileName: string,
  folder: string = 'photos'
): Promise<{ signedUrl: string; path: string }> {
  const path = `${folder}/${Date.now()}-${fileName}`;

  const { data, error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .createSignedUploadUrl(path);

  if (error) {
    throw new Error(`Failed to create signed upload URL: ${error.message}`);
  }

  return {
    signedUrl: data.signedUrl,
    path,
  };
}
