const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/v1';

function getAuthHeaders(): Record<string, string> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('accessToken') : null;
  return {
    'Content-Type': 'application/json',
    ...(token && { 'Authorization': `Bearer ${token}` }),
  };
}

export interface Project {
  id: string;
  name: string;
  address: string;
  latitude: number | null;
  longitude: number | null;
  createdAt: string;
  updatedAt: string;
  photoCount?: number;
  folderCount?: number;
  members?: ProjectMember[];
}

export interface ProjectMember {
  id: string;
  userId: string;
  role: 'ADMIN' | 'EDITOR' | 'VIEWER';
  user: {
    id: string;
    name: string;
    email: string;
    avatarUrl: string | null;
  };
}

export interface Photo {
  id: string;
  remoteUrl: string;
  thumbnailUrl: string | null;
  capturedAt: string;
  latitude: number | null;
  longitude: number | null;
  note: string | null;
  voiceNoteUrl: string | null;
  voiceNoteTranscript: string | null;
  folderId: string | null;
  folder?: Folder | null;
  uploaderId: string;
  comments: Comment[];
}

export interface Folder {
  id: string;
  name: string;
  projectId: string;
  photoCount?: number;
}

export interface Comment {
  id: string;
  text: string;
  createdAt: string;
  user: {
    id: string;
    name: string;
    avatarUrl: string | null;
  };
}

export interface CreateProjectData {
  name: string;
  address: string;
  latitude?: number;
  longitude?: number;
}

export interface ShareLink {
  id: string;
  token: string;
  shareUrl: string;
  folderIds: string[];
  expiresAt: string | null;
  passwordProtected: boolean;
  allowDownload: boolean;
  allowComments: boolean;
  isActive: boolean;
  accessCount: number;
  createdAt: string;
}

// Projects
export async function getProjects(): Promise<Project[]> {
  const response = await fetch(`${API_BASE}/projects`, {
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to fetch projects');
  }

  return response.json();
}

export async function getProject(id: string): Promise<Project> {
  const response = await fetch(`${API_BASE}/projects/${id}`, {
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to fetch project');
  }

  return response.json();
}

export async function createProject(data: CreateProjectData): Promise<Project> {
  const response = await fetch(`${API_BASE}/projects`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to create project');
  }

  return response.json();
}

export async function updateProject(id: string, data: Partial<CreateProjectData>): Promise<Project> {
  const response = await fetch(`${API_BASE}/projects/${id}`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error('Failed to update project');
  }

  return response.json();
}

export async function deleteProject(id: string): Promise<void> {
  const response = await fetch(`${API_BASE}/projects/${id}`, {
    method: 'DELETE',
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to delete project');
  }
}

// Photos
export async function getPhotos(projectId: string, page = 1, limit = 50): Promise<{ data: Photo[]; total: number; hasMore: boolean }> {
  const response = await fetch(`${API_BASE}/projects/${projectId}/photos?page=${page}&limit=${limit}`, {
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to fetch photos');
  }

  return response.json();
}

export async function getUploadUrl(projectId: string, filename: string, contentType: string): Promise<{ uploadUrl: string; mediaUrl: string; thumbnailUploadUrl: string; thumbnailUrl: string }> {
  const response = await fetch(`${API_BASE}/photos/upload-url`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ projectId, filename, contentType }),
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    throw new Error(error.error || 'Failed to get upload URL');
  }

  return response.json();
}

export async function uploadToS3(uploadUrl: string, file: File): Promise<void> {
  const response = await fetch(uploadUrl, {
    method: 'PUT',
    headers: {
      'Content-Type': file.type,
    },
    body: file,
  });

  if (!response.ok) {
    throw new Error('Failed to upload file');
  }
}

export async function createPhoto(data: {
  projectId: string;
  remoteUrl: string;
  thumbnailUrl?: string;
  capturedAt: string;
  latitude: number;
  longitude: number;
  note?: string;
  folderId?: string;
}): Promise<Photo> {
  const response = await fetch(`${API_BASE}/photos`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error('Failed to create photo');
  }

  return response.json();
}

export async function deletePhoto(photoId: string): Promise<void> {
  const response = await fetch(`${API_BASE}/photos/${photoId}`, {
    method: 'DELETE',
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to delete photo');
  }
}

export async function addComment(photoId: string, text: string): Promise<Comment> {
  const response = await fetch(`${API_BASE}/photos/${photoId}/comments`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ text }),
  });

  if (!response.ok) {
    throw new Error('Failed to add comment');
  }

  return response.json();
}

// Folders
export async function createFolder(projectId: string, name: string): Promise<Folder> {
  const response = await fetch(`${API_BASE}/projects/${projectId}/folders`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ name }),
  });

  if (!response.ok) {
    throw new Error('Failed to create folder');
  }

  return response.json();
}

// Share Links
export async function createShareLink(projectId: string, options: {
  folderIds?: string[];
  expiresAt?: string;
  password?: string;
  allowDownload?: boolean;
  allowComments?: boolean;
}): Promise<ShareLink> {
  const response = await fetch(`${API_BASE}/share/${projectId}`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify(options),
  });

  if (!response.ok) {
    throw new Error('Failed to create share link');
  }

  return response.json();
}
