import { MapPin, Calendar, Folder } from 'lucide-react';
import { SharedProject } from '@/lib/api';

interface ProjectHeaderProps {
  project: SharedProject;
  photoCount: number;
}

export function ProjectHeader({ project, photoCount }: ProjectHeaderProps) {
  return (
    <header className="bg-white border-b sticky top-0 z-40">
      <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 bg-fieldvision-orange rounded-xl flex items-center justify-center flex-shrink-0">
            <span className="text-white font-bold text-lg">
              {project.name.charAt(0).toUpperCase()}
            </span>
          </div>

          <div className="flex-1 min-w-0">
            <h1 className="text-xl font-bold text-gray-900 truncate">
              {project.name}
            </h1>
            <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-gray-500 mt-1">
              <span className="flex items-center gap-1">
                <MapPin className="w-4 h-4" />
                {project.address}
              </span>
              <span className="flex items-center gap-1">
                <Calendar className="w-4 h-4" />
                {photoCount} photos
              </span>
              {project.folders.length > 0 && (
                <span className="flex items-center gap-1">
                  <Folder className="w-4 h-4" />
                  {project.folders.length} folders
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
