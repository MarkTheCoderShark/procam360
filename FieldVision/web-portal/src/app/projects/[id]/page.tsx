'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter, useParams } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import { useAuth } from '@/lib/auth-context';
import { DashboardLayout } from '@/components/DashboardLayout';
import {
  getProject,
  getPhotos,
  getUploadUrl,
  uploadToS3,
  createPhoto,
  createFolder,
  deletePhoto,
  Project,
  Photo,
  Folder,
} from '@/lib/projects-api';
import {
  Loader2,
  ArrowLeft,
  Camera,
  Upload,
  FolderPlus,
  MapPin,
  Image as ImageIcon,
  X,
  ChevronLeft,
  ChevronRight,
  Download,
  Trash2,
  Share2,
  MoreVertical,
  Calendar,
} from 'lucide-react';
import { format, formatDistanceToNow } from 'date-fns';
import { cn } from '@/lib/utils';

export default function ProjectDetailPage() {
  const router = useRouter();
  const params = useParams();
  const projectId = params.id as string;
  const { isAuthenticated, isLoading: authLoading } = useAuth();

  const [project, setProject] = useState<Project | null>(null);
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [folders, setFolders] = useState<Folder[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [selectedPhoto, setSelectedPhoto] = useState<Photo | null>(null);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);

  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);

  const [showNewFolder, setShowNewFolder] = useState(false);
  const [newFolderName, setNewFolderName] = useState('');

  const [activeFolder, setActiveFolder] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [authLoading, isAuthenticated, router]);

  useEffect(() => {
    if (isAuthenticated && projectId) {
      loadProjectData();
    }
  }, [isAuthenticated, projectId]);

  async function loadProjectData() {
    try {
      const [projectData, photosData] = await Promise.all([
        getProject(projectId),
        getPhotos(projectId),
      ]);
      setProject(projectData);
      setPhotos(photosData.data);
      // Extract unique folders from photos
      const folderMap = new Map<string, Folder>();
      photosData.data.forEach((photo: Photo) => {
        if (photo.folder) {
          folderMap.set(photo.folder.id, photo.folder);
        }
      });
      setFolders(Array.from(folderMap.values()));
    } catch (err) {
      setError('Failed to load project');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  }

  async function handleFileUpload(files: FileList | null) {
    if (!files || files.length === 0) return;

    setIsUploading(true);
    setUploadProgress(0);

    const totalFiles = files.length;
    let uploadedFiles = 0;

    for (const file of Array.from(files)) {
      try {
        // Get presigned URL
        const { uploadUrl, mediaUrl } = await getUploadUrl(
          projectId,
          file.name,
          file.type
        );

        // Upload to S3
        await uploadToS3(uploadUrl, file);

        // Get current location for the photo
        let latitude = 0;
        let longitude = 0;
        if (navigator.geolocation) {
          try {
            const position = await new Promise<GeolocationPosition>((resolve, reject) => {
              navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 5000 });
            });
            latitude = position.coords.latitude;
            longitude = position.coords.longitude;
          } catch (e) {
            console.log('Could not get location');
          }
        }

        // Create photo record
        const photo = await createPhoto({
          projectId,
          remoteUrl: mediaUrl,
          capturedAt: new Date().toISOString(),
          latitude,
          longitude,
          ...(activeFolder && { folderId: activeFolder }),
        });

        setPhotos((prev) => [photo, ...prev]);
        uploadedFiles++;
        setUploadProgress(Math.round((uploadedFiles / totalFiles) * 100));
      } catch (err) {
        console.error('Failed to upload file:', file.name, err);
      }
    }

    setIsUploading(false);
    setUploadProgress(0);
  }

  async function handleCreateFolder() {
    if (!newFolderName.trim()) return;

    try {
      const folder = await createFolder(projectId, newFolderName.trim());
      setFolders((prev) => [...prev, folder]);
      setNewFolderName('');
      setShowNewFolder(false);
    } catch (err) {
      console.error('Failed to create folder:', err);
    }
  }

  async function handleDeletePhoto(photoId: string) {
    if (!confirm('Are you sure you want to delete this photo?')) return;

    try {
      await deletePhoto(photoId);
      setPhotos((prev) => prev.filter((p) => p.id !== photoId));
      setSelectedPhoto(null);
      setSelectedIndex(null);
    } catch (err) {
      console.error('Failed to delete photo:', err);
    }
  }

  const filteredPhotos = activeFolder
    ? photos.filter((p) => p.folderId === activeFolder)
    : photos;

  const handlePrevious = () => {
    if (selectedIndex !== null && selectedIndex > 0) {
      const newIndex = selectedIndex - 1;
      setSelectedIndex(newIndex);
      setSelectedPhoto(filteredPhotos[newIndex]);
    }
  };

  const handleNext = () => {
    if (selectedIndex !== null && selectedIndex < filteredPhotos.length - 1) {
      const newIndex = selectedIndex + 1;
      setSelectedIndex(newIndex);
      setSelectedPhoto(filteredPhotos[newIndex]);
    }
  };

  if (authLoading || !isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-fieldvision-blue" />
      </div>
    );
  }

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center py-12">
          <Loader2 className="w-8 h-8 animate-spin text-fieldvision-blue" />
        </div>
      </DashboardLayout>
    );
  }

  if (error || !project) {
    return (
      <DashboardLayout>
        <div className="text-center py-12">
          <p className="text-red-600">{error || 'Project not found'}</p>
          <Link href="/dashboard" className="mt-4 text-fieldvision-blue hover:underline">
            Back to projects
          </Link>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="mb-6">
          <Link
            href="/dashboard"
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to projects
          </Link>

          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">{project.name}</h1>
              <div className="flex items-center gap-1 text-gray-500 mt-1">
                <MapPin className="w-4 h-4" />
                <span>{project.address}</span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={() => cameraInputRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors"
              >
                <Camera className="w-5 h-5" />
                <span className="hidden sm:inline">Capture</span>
              </button>
              <button
                onClick={() => fileInputRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
              >
                <Upload className="w-5 h-5" />
                <span className="hidden sm:inline">Upload</span>
              </button>
            </div>
          </div>
        </div>

        {/* Hidden file inputs */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          className="hidden"
          onChange={(e) => handleFileUpload(e.target.files)}
        />
        <input
          ref={cameraInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          className="hidden"
          onChange={(e) => handleFileUpload(e.target.files)}
        />

        {/* Upload progress */}
        {isUploading && (
          <div className="mb-6 bg-white rounded-lg border p-4">
            <div className="flex items-center gap-3">
              <Loader2 className="w-5 h-5 animate-spin text-fieldvision-blue" />
              <div className="flex-1">
                <p className="text-sm font-medium text-gray-900">Uploading photos...</p>
                <div className="mt-2 h-2 bg-gray-200 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-fieldvision-blue transition-all"
                    style={{ width: `${uploadProgress}%` }}
                  />
                </div>
              </div>
              <span className="text-sm text-gray-500">{uploadProgress}%</span>
            </div>
          </div>
        )}

        {/* Folders */}
        <div className="mb-6 flex flex-wrap items-center gap-2">
          <button
            onClick={() => setActiveFolder(null)}
            className={cn(
              'px-4 py-2 rounded-full text-sm font-medium transition-colors',
              activeFolder === null
                ? 'bg-fieldvision-blue text-white'
                : 'bg-white border text-gray-700 hover:bg-gray-50'
            )}
          >
            All Photos ({photos.length})
          </button>
          {folders.map((folder) => (
            <button
              key={folder.id}
              onClick={() => setActiveFolder(folder.id)}
              className={cn(
                'px-4 py-2 rounded-full text-sm font-medium transition-colors',
                activeFolder === folder.id
                  ? 'bg-fieldvision-blue text-white'
                  : 'bg-white border text-gray-700 hover:bg-gray-50'
              )}
            >
              {folder.name} ({photos.filter((p) => p.folderId === folder.id).length})
            </button>
          ))}
          {showNewFolder ? (
            <div className="flex items-center gap-2">
              <input
                type="text"
                value={newFolderName}
                onChange={(e) => setNewFolderName(e.target.value)}
                placeholder="Folder name"
                className="px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                autoFocus
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleCreateFolder();
                  if (e.key === 'Escape') {
                    setShowNewFolder(false);
                    setNewFolderName('');
                  }
                }}
              />
              <button
                onClick={handleCreateFolder}
                className="p-2 bg-fieldvision-blue text-white rounded-lg hover:bg-fieldvision-blue/90"
              >
                <FolderPlus className="w-4 h-4" />
              </button>
              <button
                onClick={() => {
                  setShowNewFolder(false);
                  setNewFolderName('');
                }}
                className="p-2 text-gray-400 hover:text-gray-600"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          ) : (
            <button
              onClick={() => setShowNewFolder(true)}
              className="px-4 py-2 rounded-full text-sm font-medium border border-dashed text-gray-500 hover:border-fieldvision-blue hover:text-fieldvision-blue transition-colors flex items-center gap-1"
            >
              <FolderPlus className="w-4 h-4" />
              New Folder
            </button>
          )}
        </div>

        {/* Photo grid */}
        {filteredPhotos.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-xl border-2 border-dashed border-gray-200">
            <ImageIcon className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No photos yet</h3>
            <p className="text-gray-500 mb-6">Capture or upload photos to document this project</p>
            <div className="flex items-center justify-center gap-3">
              <button
                onClick={() => cameraInputRef.current?.click()}
                className="inline-flex items-center gap-2 px-4 py-2 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors"
              >
                <Camera className="w-5 h-5" />
                Capture Photo
              </button>
              <button
                onClick={() => fileInputRef.current?.click()}
                className="inline-flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
              >
                <Upload className="w-5 h-5" />
                Upload Photos
              </button>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {filteredPhotos.map((photo, index) => (
              <div
                key={photo.id}
                onClick={() => {
                  setSelectedPhoto(photo);
                  setSelectedIndex(index);
                }}
                className="relative aspect-square cursor-pointer group overflow-hidden rounded-lg bg-gray-100"
              >
                <Image
                  src={photo.thumbnailUrl || photo.remoteUrl}
                  alt={photo.note || 'Project photo'}
                  fill
                  className="object-cover transition-transform group-hover:scale-105"
                  sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw"
                />
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors" />
                {photo.note && (
                  <div className="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/60 to-transparent">
                    <p className="text-white text-xs truncate">{photo.note}</p>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Photo lightbox */}
      {selectedPhoto && (
        <div className="fixed inset-0 z-50 bg-black/90 flex items-center justify-center">
          <button
            onClick={() => {
              setSelectedPhoto(null);
              setSelectedIndex(null);
            }}
            className="absolute top-4 right-4 text-white p-2 hover:bg-white/10 rounded-full transition-colors z-10"
          >
            <X className="w-6 h-6" />
          </button>

          {selectedIndex !== null && selectedIndex > 0 && (
            <button
              onClick={handlePrevious}
              className="absolute left-4 top-1/2 -translate-y-1/2 text-white p-2 hover:bg-white/10 rounded-full transition-colors"
            >
              <ChevronLeft className="w-8 h-8" />
            </button>
          )}

          {selectedIndex !== null && selectedIndex < filteredPhotos.length - 1 && (
            <button
              onClick={handleNext}
              className="absolute right-4 top-1/2 -translate-y-1/2 text-white p-2 hover:bg-white/10 rounded-full transition-colors"
            >
              <ChevronRight className="w-8 h-8" />
            </button>
          )}

          <div className="max-w-5xl w-full mx-4 flex flex-col lg:flex-row gap-4">
            <div className="relative flex-1 aspect-[4/3] lg:aspect-auto lg:h-[70vh]">
              <Image
                src={selectedPhoto.remoteUrl}
                alt={selectedPhoto.note || 'Project photo'}
                fill
                className="object-contain"
                sizes="(max-width: 1024px) 100vw, 70vw"
              />
            </div>

            <div className="lg:w-80 bg-white rounded-lg p-4 max-h-[70vh] overflow-y-auto">
              <div className="mb-4">
                <div className="flex items-center gap-2 text-sm text-gray-500 mb-2">
                  <Calendar className="w-4 h-4" />
                  {format(new Date(selectedPhoto.capturedAt), 'PPP p')}
                </div>
                {selectedPhoto.note && (
                  <p className="text-gray-800">{selectedPhoto.note}</p>
                )}
              </div>

              <div className="space-y-2">
                <a
                  href={selectedPhoto.remoteUrl}
                  download
                  className="flex items-center justify-center gap-2 w-full py-2 bg-fieldvision-blue text-white rounded-lg hover:bg-fieldvision-blue/90 transition-colors"
                >
                  <Download className="w-4 h-4" />
                  Download
                </a>
                <button
                  onClick={() => handleDeletePhoto(selectedPhoto.id)}
                  className="flex items-center justify-center gap-2 w-full py-2 border border-red-200 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </DashboardLayout>
  );
}
