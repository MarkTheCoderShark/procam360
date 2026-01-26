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
  name: string;
  email: string;
  avatarUrl: string | null;
  role: 'ADMIN' | 'CREW' | 'VIEWER';
  invitedAt: string;
  isCurrentUser?: boolean;
}

export interface TeamContact {
  id: string;
  contactId: string;
  name: string;
  email: string;
  avatarUrl: string | null;
  nickname: string | null;
  defaultRole: 'ADMIN' | 'CREW' | 'VIEWER';
  createdAt: string;
}

export interface Collaborator {
  userId: string;
  name: string;
  email: string;
  avatarUrl: string | null;
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
  // Supabase signed upload URLs - upload without Content-Type header
  const response = await fetch(uploadUrl, {
    method: 'PUT',
    body: file,
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => '');
    console.error('Upload failed:', response.status, errorText);
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

// Project Members
export async function getProjectMembers(projectId: string): Promise<ProjectMember[]> {
  const response = await fetch(`${API_BASE}/projects/${projectId}/members`, {
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to fetch project members');
  }

  return response.json();
}

export async function inviteMember(projectId: string, email: string, role: 'ADMIN' | 'CREW' | 'VIEWER' = 'CREW'): Promise<ProjectMember> {
  const response = await fetch(`${API_BASE}/projects/${projectId}/members`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ email, role }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to invite member');
  }

  return response.json();
}

export async function updateMemberRole(projectId: string, memberId: string, role: 'ADMIN' | 'CREW' | 'VIEWER'): Promise<ProjectMember> {
  const response = await fetch(`${API_BASE}/projects/${projectId}/members/${memberId}`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    body: JSON.stringify({ role }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to update member role');
  }

  return response.json();
}

export async function removeMember(projectId: string, memberId: string): Promise<void> {
  const response = await fetch(`${API_BASE}/projects/${projectId}/members/${memberId}`, {
    method: 'DELETE',
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to remove member');
  }
}

export async function bulkInviteMembers(projectId: string, invites: Array<{ email: string; role: 'ADMIN' | 'CREW' | 'VIEWER' }>): Promise<{
  summary: { total: number; successful: number; failed: number };
  results: Array<{ email: string; success: boolean; error?: string; member?: ProjectMember }>;
}> {
  const response = await fetch(`${API_BASE}/projects/${projectId}/members/bulk`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ invites }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to bulk invite members');
  }

  return response.json();
}

// Team Contacts
export async function getTeamContacts(): Promise<TeamContact[]> {
  const response = await fetch(`${API_BASE}/team/contacts`, {
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to fetch team contacts');
  }

  return response.json();
}

export async function addTeamContact(email: string, nickname?: string, defaultRole: 'ADMIN' | 'CREW' | 'VIEWER' = 'CREW'): Promise<TeamContact> {
  const response = await fetch(`${API_BASE}/team/contacts`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ email, nickname, defaultRole }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to add team contact');
  }

  return response.json();
}

export async function updateTeamContact(id: string, data: { nickname?: string; defaultRole?: 'ADMIN' | 'CREW' | 'VIEWER' }): Promise<TeamContact> {
  const response = await fetch(`${API_BASE}/team/contacts/${id}`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to update team contact');
  }

  return response.json();
}

export async function removeTeamContact(id: string): Promise<void> {
  const response = await fetch(`${API_BASE}/team/contacts/${id}`, {
    method: 'DELETE',
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to remove team contact');
  }
}

export async function getPastCollaborators(): Promise<Collaborator[]> {
  const response = await fetch(`${API_BASE}/team/collaborators`, {
    headers: getAuthHeaders(),
  });

  if (!response.ok) {
    throw new Error('Failed to fetch past collaborators');
  }

  return response.json();
}
