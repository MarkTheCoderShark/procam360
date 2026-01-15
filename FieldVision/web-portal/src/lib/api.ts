const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/v1';

export interface SharedProject {
  id: string;
  name: string;
  address: string;
  photos: SharedPhoto[];
  folders: SharedFolder[];
  allowDownload: boolean;
  allowComments: boolean;
}

export interface SharedPhoto {
  id: string;
  remoteUrl: string;
  thumbnailUrl: string | null;
  capturedAt: string;
  latitude: number;
  longitude: number;
  note: string | null;
  folderId: string | null;
  comments: PhotoComment[];
}

export interface SharedFolder {
  id: string;
  name: string;
  photoCount: number;
}

export interface PhotoComment {
  id: string;
  text: string;
  userName: string;
  createdAt: string;
}

export async function getSharedProject(
  token: string,
  password?: string
): Promise<SharedProject | { requiresPassword: true } | null> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (password) {
    headers['X-Share-Password'] = password;
  }

  const response = await fetch(`${API_BASE}/share/${token}`, {
    headers,
    cache: 'no-store',
  });

  if (response.status === 401) {
    return { requiresPassword: true };
  }

  if (response.status === 404 || response.status === 410) {
    return null;
  }

  if (!response.ok) {
    throw new Error('Failed to fetch shared project');
  }

  return response.json();
}

export async function addComment(
  token: string,
  photoId: string,
  text: string,
  guestName: string
): Promise<PhotoComment> {
  const response = await fetch(`${API_BASE}/share/${token}/comments`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ photoId, text, guestName }),
  });

  if (!response.ok) {
    throw new Error('Failed to add comment');
  }

  return response.json();
}
