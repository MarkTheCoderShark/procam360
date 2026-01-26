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
  getProjectMembers,
  Project,
  Photo,
  Folder,
  ProjectMember,
} from '@/lib/projects-api';
import { ProjectMembersPanel } from '@/components/ProjectMembersPanel';
import { ShareWithTeamModal } from '@/components/ShareWithTeamModal';
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
  FileText,
  Users,
  UserPlus,
} from 'lucide-react';
import { generateProjectReport, downloadReport } from '@/lib/report-generator';
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
  const [batchMode, setBatchMode] = useState(false);
  const [batchPhotos, setBatchPhotos] = useState<File[]>([]);
  const [isGeneratingReport, setIsGeneratingReport] = useState(false);
  const [showReportOptions, setShowReportOptions] = useState(false);
  const [reportCompanyName, setReportCompanyName] = useState('');

  const [showMembersPanel, setShowMembersPanel] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);
  const [members, setMembers] = useState<ProjectMember[]>([]);
  const [isAdmin, setIsAdmin] = useState(false);

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
      const [projectData, photosData, membersData] = await Promise.all([
        getProject(projectId),
        getPhotos(projectId),
        getProjectMembers(projectId),
      ]);
      setProject(projectData);
      setPhotos(photosData.data);
      setMembers(membersData);
      // Check if current user is admin
      const currentUserMember = membersData.find((m) => m.isCurrentUser);
      setIsAdmin(currentUserMember?.role === 'ADMIN');
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

  async function handleFileUpload(files: FileList | File[] | null) {
    if (!files || files.length === 0) return;
    const fileArray = Array.from(files);

    setIsUploading(true);
    setUploadProgress(0);

    const totalFiles = fileArray.length;
    let uploadedFiles = 0;

    for (const file of fileArray) {
      try {
        // Sanitize filename - replace spaces and special chars
        const sanitizedName = file.name
          .replace(/\s+/g, '_')
          .replace(/[^a-zA-Z0-9._-]/g, '_');

        // Get presigned URL
        const { uploadUrl, mediaUrl } = await getUploadUrl(
          projectId,
          sanitizedName,
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

            <div className="flex items-center gap-2 flex-wrap">
              <button
                onClick={() => setShowMembersPanel(true)}
                className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
              >
                <Users className="w-5 h-5" />
                <span className="hidden sm:inline">Members</span>
                <span className="text-sm text-gray-500">({members.length})</span>
              </button>
              {isAdmin && (
                <button
                  onClick={() => setShowShareModal(true)}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg font-semibold hover:bg-green-700 transition-colors"
                >
                  <UserPlus className="w-5 h-5" />
                  <span className="hidden sm:inline">Share with Team</span>
                </button>
              )}
              <button
                onClick={() => setBatchMode(true)}
                className="flex items-center gap-2 px-4 py-2 bg-fieldvision-orange text-white rounded-lg font-semibold hover:bg-fieldvision-orange/90 transition-colors"
              >
                <Camera className="w-5 h-5" />
                <span className="hidden sm:inline">Batch Capture</span>
              </button>
              <button
                onClick={() => cameraInputRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors"
              >
                <Camera className="w-5 h-5" />
                <span className="hidden sm:inline">Single</span>
              </button>
              <button
                onClick={() => fileInputRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
              >
                <Upload className="w-5 h-5" />
                <span className="hidden sm:inline">Upload</span>
              </button>
              {photos.length > 0 && (
                <button
                  onClick={() => setShowReportOptions(true)}
                  disabled={isGeneratingReport}
                  className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-semibold hover:bg-gray-50 transition-colors disabled:opacity-50"
                >
                  {isGeneratingReport ? (
                    <Loader2 className="w-5 h-5 animate-spin" />
                  ) : (
                    <FileText className="w-5 h-5" />
                  )}
                  <span className="hidden sm:inline">Report</span>
                </button>
              )}
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

      {/* Report Options Modal */}
      {showReportOptions && project && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold mb-4">Generate PDF Report</h3>

            <div className="space-y-4 mb-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Company / Inspector Name
                </label>
                <input
                  type="text"
                  value={reportCompanyName}
                  onChange={(e) => setReportCompanyName(e.target.value)}
                  placeholder="Your Company Name"
                  className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                />
              </div>

              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-sm text-gray-600">
                  <strong>Report will include:</strong>
                </p>
                <ul className="text-sm text-gray-600 mt-2 space-y-1">
                  <li>• Cover page with project details</li>
                  <li>• All {photos.length} photos</li>
                  <li>• Photo dates and locations</li>
                  <li>• Notes for each photo</li>
                </ul>
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setShowReportOptions(false)}
                className="flex-1 py-2 border rounded-lg text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={async () => {
                  setShowReportOptions(false);
                  setIsGeneratingReport(true);
                  try {
                    const blob = await generateProjectReport(project, photos, {
                      companyName: reportCompanyName || 'ProCam360',
                    });
                    const filename = `${project.name.replace(/\s+/g, '_')}_Report_${format(new Date(), 'yyyy-MM-dd')}.pdf`;
                    downloadReport(blob, filename);
                  } catch (err) {
                    console.error('Failed to generate report:', err);
                    alert('Failed to generate report. Please try again.');
                  } finally {
                    setIsGeneratingReport(false);
                  }
                }}
                className="flex-1 py-2 bg-fieldvision-blue text-white rounded-lg hover:bg-fieldvision-blue/90 font-semibold"
              >
                Generate PDF
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Batch Capture Modal */}
      {batchMode && (
        <div className="fixed inset-0 z-50 bg-black flex flex-col">
          <div className="flex items-center justify-between p-4 bg-black/80">
            <div className="text-white">
              <span className="text-lg font-semibold">{batchPhotos.length} photos</span>
              <span className="text-white/60 ml-2">ready to upload</span>
            </div>
            <div className="flex items-center gap-3">
              {batchPhotos.length > 0 && (
                <button
                  onClick={async () => {
                    setBatchMode(false);
                    await handleFileUpload(
                      Object.assign(batchPhotos, { length: batchPhotos.length, item: (i: number) => batchPhotos[i] }) as unknown as FileList
                    );
                    setBatchPhotos([]);
                  }}
                  className="px-4 py-2 bg-fieldvision-orange text-white rounded-lg font-semibold hover:bg-fieldvision-orange/90"
                >
                  Upload All ({batchPhotos.length})
                </button>
              )}
              <button
                onClick={() => {
                  setBatchMode(false);
                  setBatchPhotos([]);
                }}
                className="p-2 text-white hover:bg-white/10 rounded-full"
              >
                <X className="w-6 h-6" />
              </button>
            </div>
          </div>

          <div className="flex-1 flex flex-col items-center justify-center p-4">
            <input
              type="file"
              accept="image/*"
              capture="environment"
              className="hidden"
              id="batch-camera"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) {
                  setBatchPhotos((prev) => [...prev, file]);
                  // Reset input so same file can be selected again
                  e.target.value = '';
                }
              }}
            />

            <button
              onClick={() => document.getElementById('batch-camera')?.click()}
              className="w-24 h-24 rounded-full bg-white flex items-center justify-center shadow-lg hover:scale-105 transition-transform mb-8"
            >
              <Camera className="w-12 h-12 text-fieldvision-blue" />
            </button>

            <p className="text-white/80 text-center mb-4">
              Tap the button to capture photos.<br />
              Upload all when done.
            </p>

            {/* Thumbnail strip of captured photos */}
            {batchPhotos.length > 0 && (
              <div className="flex gap-2 overflow-x-auto max-w-full p-2">
                {batchPhotos.map((file, index) => (
                  <div key={index} className="relative flex-shrink-0">
                    <img
                      src={URL.createObjectURL(file)}
                      alt={`Capture ${index + 1}`}
                      className="w-16 h-16 object-cover rounded-lg"
                    />
                    <button
                      onClick={() => setBatchPhotos((prev) => prev.filter((_, i) => i !== index))}
                      className="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center text-xs"
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

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

      {/* Members Panel */}
      <ProjectMembersPanel
        projectId={projectId}
        isOpen={showMembersPanel}
        onClose={() => setShowMembersPanel(false)}
        isAdmin={isAdmin}
      />

      {/* Share with Team Modal */}
      {showShareModal && (
        <ShareWithTeamModal
          projectId={projectId}
          existingMemberIds={members.map((m) => m.userId)}
          onClose={() => setShowShareModal(false)}
          onMembersAdded={(newMembers) => {
            setMembers((prev) => [...prev, ...newMembers]);
          }}
        />
      )}
    </DashboardLayout>
  );
}
