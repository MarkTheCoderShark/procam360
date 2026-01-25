'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { getSharedProject, addComment, SharedProject } from '@/lib/api';
import { PhotoGrid } from '@/components/PhotoGrid';
import { PasswordPrompt } from '@/components/PasswordPrompt';
import { ProjectHeader } from '@/components/ProjectHeader';
import { Loader2, AlertCircle, FolderOpen } from 'lucide-react';
import { cn } from '@/lib/utils';

type ViewMode = 'all' | 'folder';

export default function SharePage() {
  const params = useParams();
  const token = params.token as string;

  const [project, setProject] = useState<SharedProject | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [requiresPassword, setRequiresPassword] = useState(false);
  const [passwordError, setPasswordError] = useState<string | undefined>();
  const [viewMode, setViewMode] = useState<ViewMode>('all');
  const [selectedFolderId, setSelectedFolderId] = useState<string | null>(null);
  const [guestName, setGuestName] = useState('');
  const [showNamePrompt, setShowNamePrompt] = useState(false);
  const [pendingComment, setPendingComment] = useState<{ photoId: string; text: string } | null>(null);

  useEffect(() => {
    loadProject();
  }, [token]);

  async function loadProject(password?: string) {
    setLoading(true);
    try {
      const result = await getSharedProject(token, password);

      if (result === null) {
        setError('This link has expired or does not exist');
      } else if ('requiresPassword' in result) {
        setRequiresPassword(true);
        if (password) {
          setPasswordError('Incorrect password');
        }
      } else {
        setProject(result);
        setRequiresPassword(false);
        setPasswordError(undefined);
      }
    } catch (err) {
      setError('Failed to load project');
    } finally {
      setLoading(false);
    }
  }

  async function handleAddComment(photoId: string, text: string) {
    if (!project?.allowComments) return;

    if (!guestName) {
      setPendingComment({ photoId, text });
      setShowNamePrompt(true);
      return;
    }

    try {
      const comment = await addComment(token, photoId, text, guestName);

      setProject((prev) => {
        if (!prev) return prev;
        return {
          ...prev,
          photos: prev.photos.map((photo) =>
            photo.id === photoId
              ? { ...photo, comments: [...photo.comments, comment] }
              : photo
          ),
        };
      });
    } catch (err) {
      console.error('Failed to add comment:', err);
    }
  }

  function handleNameSubmit(name: string) {
    setGuestName(name);
    setShowNamePrompt(false);
    if (pendingComment) {
      handleAddComment(pendingComment.photoId, pendingComment.text);
      setPendingComment(null);
    }
  }

  const filteredPhotos = project?.photos.filter((photo) => {
    if (viewMode === 'all') return true;
    return photo.folderId === selectedFolderId;
  }) ?? [];

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-fieldvision-blue" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <div className="text-center">
          <AlertCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            Link Unavailable
          </h1>
          <p className="text-gray-600">{error}</p>
        </div>
      </div>
    );
  }

  if (requiresPassword) {
    return <PasswordPrompt onSubmit={(pw) => loadProject(pw)} error={passwordError} />;
  }

  if (!project) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <ProjectHeader project={project} photoCount={project.photos.length} />

      <main className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
        {project.folders.length > 0 && (
          <div className="mb-6">
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => {
                  setViewMode('all');
                  setSelectedFolderId(null);
                }}
                className={cn(
                  'px-4 py-2 rounded-full text-sm font-medium transition-colors',
                  viewMode === 'all'
                    ? 'bg-fieldvision-blue text-white'
                    : 'bg-white text-gray-700 hover:bg-gray-100'
                )}
              >
                All Photos
              </button>
              {project.folders.map((folder) => (
                <button
                  key={folder.id}
                  onClick={() => {
                    setViewMode('folder');
                    setSelectedFolderId(folder.id);
                  }}
                  className={cn(
                    'px-4 py-2 rounded-full text-sm font-medium transition-colors flex items-center gap-2',
                    viewMode === 'folder' && selectedFolderId === folder.id
                      ? 'bg-fieldvision-blue text-white'
                      : 'bg-white text-gray-700 hover:bg-gray-100'
                  )}
                >
                  <FolderOpen className="w-4 h-4" />
                  {folder.name}
                  <span className="text-xs opacity-70">({folder.photoCount})</span>
                </button>
              ))}
            </div>
          </div>
        )}

        {filteredPhotos.length === 0 ? (
          <div className="text-center py-16">
            <p className="text-gray-500">No photos in this view</p>
          </div>
        ) : (
          <PhotoGrid
            photos={filteredPhotos}
            allowDownload={project.allowDownload}
            allowComments={project.allowComments}
            onAddComment={handleAddComment}
          />
        )}
      </main>

      {showNamePrompt && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl p-6 max-w-sm w-full">
            <h3 className="text-lg font-semibold mb-4">Your Name</h3>
            <p className="text-sm text-gray-600 mb-4">
              Please enter your name to post a comment
            </p>
            <input
              type="text"
              placeholder="Your name"
              className="w-full px-4 py-2 border rounded-lg mb-4 focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
              onKeyDown={(e) => {
                if (e.key === 'Enter' && (e.target as HTMLInputElement).value.trim()) {
                  handleNameSubmit((e.target as HTMLInputElement).value.trim());
                }
              }}
              autoFocus
            />
            <div className="flex gap-2">
              <button
                onClick={() => {
                  setShowNamePrompt(false);
                  setPendingComment(null);
                }}
                className="flex-1 py-2 border rounded-lg text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  const input = document.querySelector('input[placeholder="Your name"]') as HTMLInputElement;
                  if (input?.value.trim()) {
                    handleNameSubmit(input.value.trim());
                  }
                }}
                className="flex-1 py-2 bg-fieldvision-blue text-white rounded-lg hover:bg-fieldvision-blue/90"
              >
                Continue
              </button>
            </div>
          </div>
        </div>
      )}

      <footer className="bg-white border-t mt-12">
        <div className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
          <div className="text-center text-sm text-gray-500">
            <p>Shared via ProCam360</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
