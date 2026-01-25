'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/lib/auth-context';
import { DashboardLayout } from '@/components/DashboardLayout';
import { getProjects, Project } from '@/lib/projects-api';
import {
  Loader2,
  FolderOpen,
  MapPin,
  Image,
  Plus,
  ChevronRight,
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

export default function DashboardPage() {
  const router = useRouter();
  const { isAuthenticated, isLoading: authLoading } = useAuth();
  const [projects, setProjects] = useState<Project[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [authLoading, isAuthenticated, router]);

  useEffect(() => {
    if (isAuthenticated) {
      loadProjects();
    }
  }, [isAuthenticated]);

  async function loadProjects() {
    try {
      const data = await getProjects();
      setProjects(data);
    } catch (err) {
      setError('Failed to load projects');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  }

  if (authLoading || !isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-fieldvision-blue" />
      </div>
    );
  }

  return (
    <DashboardLayout>
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Projects</h1>
            <p className="text-gray-500 mt-1">
              {projects.length} {projects.length === 1 ? 'project' : 'projects'}
            </p>
          </div>
          <Link
            href="/dashboard/new"
            className="hidden sm:flex items-center gap-2 px-4 py-2 bg-fieldvision-orange text-white rounded-lg font-semibold hover:bg-fieldvision-orange/90 transition-colors"
          >
            <Plus className="w-5 h-5" />
            New Project
          </Link>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <Loader2 className="w-8 h-8 animate-spin text-fieldvision-blue" />
          </div>
        ) : error ? (
          <div className="text-center py-12">
            <p className="text-red-600">{error}</p>
            <button
              onClick={loadProjects}
              className="mt-4 text-fieldvision-blue hover:underline"
            >
              Try again
            </button>
          </div>
        ) : projects.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-xl border-2 border-dashed border-gray-200">
            <FolderOpen className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No projects yet</h3>
            <p className="text-gray-500 mb-6">Create your first project to start documenting</p>
            <Link
              href="/dashboard/new"
              className="inline-flex items-center gap-2 px-4 py-2 bg-fieldvision-orange text-white rounded-lg font-semibold hover:bg-fieldvision-orange/90 transition-colors"
            >
              <Plus className="w-5 h-5" />
              Create Project
            </Link>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {projects.map((project) => (
              <Link
                key={project.id}
                href={`/projects/${project.id}`}
                className="group bg-white rounded-xl border hover:border-fieldvision-blue hover:shadow-md transition-all p-4"
              >
                <div className="flex items-start justify-between">
                  <div className="w-12 h-12 bg-fieldvision-orange/10 rounded-xl flex items-center justify-center flex-shrink-0">
                    <span className="text-fieldvision-orange font-bold text-lg">
                      {project.name.charAt(0).toUpperCase()}
                    </span>
                  </div>
                  <ChevronRight className="w-5 h-5 text-gray-400 group-hover:text-fieldvision-blue transition-colors" />
                </div>

                <h3 className="font-semibold text-gray-900 mt-3 mb-1 truncate">
                  {project.name}
                </h3>

                <div className="flex items-center gap-1 text-sm text-gray-500 mb-3">
                  <MapPin className="w-4 h-4 flex-shrink-0" />
                  <span className="truncate">{project.address}</span>
                </div>

                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-1 text-gray-500">
                    <Image className="w-4 h-4" />
                    <span>{project.photoCount || 0} photos</span>
                  </div>
                  <span className="text-gray-400">
                    {formatDistanceToNow(new Date(project.updatedAt), { addSuffix: true })}
                  </span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
