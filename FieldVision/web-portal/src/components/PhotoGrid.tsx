'use client';

import { useState } from 'react';
import Image from 'next/image';
import { Download, MessageCircle, X, ChevronLeft, ChevronRight } from 'lucide-react';
import { SharedPhoto } from '@/lib/api';
import { formatDateTime } from '@/lib/utils';
import { cn } from '@/lib/utils';

interface PhotoGridProps {
  photos: SharedPhoto[];
  allowDownload: boolean;
  allowComments: boolean;
  onAddComment?: (photoId: string, text: string) => void;
}

export function PhotoGrid({
  photos,
  allowDownload,
  allowComments,
  onAddComment,
}: PhotoGridProps) {
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [commentText, setCommentText] = useState('');

  const selectedPhoto = selectedIndex !== null ? photos[selectedIndex] : null;

  const handlePrevious = () => {
    if (selectedIndex !== null && selectedIndex > 0) {
      setSelectedIndex(selectedIndex - 1);
    }
  };

  const handleNext = () => {
    if (selectedIndex !== null && selectedIndex < photos.length - 1) {
      setSelectedIndex(selectedIndex + 1);
    }
  };

  const handleDownload = async (photo: SharedPhoto) => {
    const response = await fetch(photo.remoteUrl);
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `photo-${photo.id}.jpg`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  };

  const handleSubmitComment = () => {
    if (selectedPhoto && commentText.trim() && onAddComment) {
      onAddComment(selectedPhoto.id, commentText.trim());
      setCommentText('');
    }
  };

  return (
    <>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {photos.map((photo, index) => (
          <div
            key={photo.id}
            className="relative aspect-square cursor-pointer group overflow-hidden rounded-lg bg-gray-100"
            onClick={() => setSelectedIndex(index)}
          >
            <Image
              src={photo.thumbnailUrl || photo.remoteUrl}
              alt={photo.note || 'Project photo'}
              fill
              className="object-cover transition-transform group-hover:scale-105"
              sizes="(max-width: 768px) 50vw, (max-width: 1024px) 33vw, 25vw"
            />
            {photo.comments.length > 0 && (
              <div className="absolute bottom-2 right-2 bg-black/60 text-white px-2 py-1 rounded-full text-xs flex items-center gap-1">
                <MessageCircle className="w-3 h-3" />
                {photo.comments.length}
              </div>
            )}
          </div>
        ))}
      </div>

      {selectedPhoto && (
        <div className="fixed inset-0 z-50 bg-black/90 flex items-center justify-center">
          <button
            onClick={() => setSelectedIndex(null)}
            className="absolute top-4 right-4 text-white p-2 hover:bg-white/10 rounded-full transition-colors"
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

          {selectedIndex !== null && selectedIndex < photos.length - 1 && (
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
                <p className="text-sm text-gray-500">
                  {formatDateTime(selectedPhoto.capturedAt)}
                </p>
                {selectedPhoto.note && (
                  <p className="mt-2 text-gray-800">{selectedPhoto.note}</p>
                )}
              </div>

              {allowDownload && (
                <button
                  onClick={() => handleDownload(selectedPhoto)}
                  className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-fieldvision-blue text-white rounded-lg hover:bg-fieldvision-blue/90 transition-colors mb-4"
                >
                  <Download className="w-4 h-4" />
                  Download
                </button>
              )}

              <div className="border-t pt-4">
                <h3 className="font-semibold mb-3">
                  Comments ({selectedPhoto.comments.length})
                </h3>

                {selectedPhoto.comments.length === 0 ? (
                  <p className="text-gray-500 text-sm">No comments yet</p>
                ) : (
                  <div className="space-y-3">
                    {selectedPhoto.comments.map((comment) => (
                      <div key={comment.id} className="bg-gray-50 rounded-lg p-3">
                        <div className="flex items-center justify-between mb-1">
                          <span className="font-medium text-sm">
                            {comment.userName}
                          </span>
                          <span className="text-xs text-gray-400">
                            {formatDateTime(comment.createdAt)}
                          </span>
                        </div>
                        <p className="text-sm text-gray-700">{comment.text}</p>
                      </div>
                    ))}
                  </div>
                )}

                {allowComments && (
                  <div className="mt-4">
                    <textarea
                      value={commentText}
                      onChange={(e) => setCommentText(e.target.value)}
                      placeholder="Add a comment..."
                      className="w-full border rounded-lg p-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                      rows={3}
                    />
                    <button
                      onClick={handleSubmitComment}
                      disabled={!commentText.trim()}
                      className={cn(
                        'mt-2 w-full py-2 rounded-lg text-sm font-medium transition-colors',
                        commentText.trim()
                          ? 'bg-fieldvision-orange text-white hover:bg-fieldvision-orange/90'
                          : 'bg-gray-200 text-gray-400 cursor-not-allowed'
                      )}
                    >
                      Post Comment
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
