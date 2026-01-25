'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import { Loader2, Camera, CheckCircle, ArrowRight } from 'lucide-react';
import Link from 'next/link';

export default function Home() {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuth();

  useEffect(() => {
    if (!isLoading && isAuthenticated) {
      router.push('/dashboard');
    }
  }, [isLoading, isAuthenticated, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-fieldvision-blue" />
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-gradient-to-b from-gray-50 to-white">
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 bg-white/80 backdrop-blur-sm border-b">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-fieldvision-orange rounded-lg flex items-center justify-center">
                <Camera className="w-5 h-5 text-white" />
              </div>
              <span className="font-bold text-lg">FieldVision</span>
            </div>
            <div className="flex items-center gap-3">
              <Link
                href="/login"
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors"
              >
                Sign in
              </Link>
              <Link
                href="/register"
                className="px-4 py-2 text-sm font-medium text-white bg-fieldvision-blue rounded-lg hover:bg-fieldvision-blue/90 transition-colors"
              >
                Get Started
              </Link>
            </div>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="pt-32 pb-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 leading-tight mb-6">
            Job site photo documentation{' '}
            <span className="text-fieldvision-orange">made simple</span>
          </h1>
          <p className="text-xl text-gray-600 mb-8 max-w-2xl mx-auto">
            Capture, organize, and share job site photos with your team.
            Document progress, track issues, and keep everyone in the loop.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link
              href="/register"
              className="flex items-center gap-2 px-6 py-3 text-lg font-semibold text-white bg-fieldvision-orange rounded-xl hover:bg-fieldvision-orange/90 transition-colors"
            >
              Start Free
              <ArrowRight className="w-5 h-5" />
            </Link>
            <Link
              href="/login"
              className="flex items-center gap-2 px-6 py-3 text-lg font-semibold text-gray-700 bg-white border-2 border-gray-200 rounded-xl hover:border-gray-300 transition-colors"
            >
              Sign in to your account
            </Link>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 px-4 sm:px-6 lg:px-8 bg-white">
        <div className="max-w-6xl mx-auto">
          <h2 className="text-3xl font-bold text-center text-gray-900 mb-12">
            Everything you need for job site documentation
          </h2>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                title: 'Capture Photos',
                description: 'Take photos directly from your device camera or upload existing images',
                icon: '📸',
              },
              {
                title: 'Organize by Project',
                description: 'Keep photos organized with projects and folders for easy navigation',
                icon: '📁',
              },
              {
                title: 'Share with Anyone',
                description: 'Generate secure share links to share project photos with clients and team',
                icon: '🔗',
              },
              {
                title: 'Add Notes',
                description: 'Add notes and comments to photos for better context and documentation',
                icon: '📝',
              },
              {
                title: 'Location Tracking',
                description: 'Automatically capture GPS coordinates for each photo',
                icon: '📍',
              },
              {
                title: 'Works Offline',
                description: 'Capture photos even without internet - sync when you\'re back online',
                icon: '📶',
              },
            ].map((feature, index) => (
              <div key={index} className="text-center p-6">
                <div className="text-4xl mb-4">{feature.icon}</div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">{feature.title}</h3>
                <p className="text-gray-600">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl font-bold text-gray-900 mb-4">
            Ready to streamline your documentation?
          </h2>
          <p className="text-xl text-gray-600 mb-8">
            Join contractors and builders who use FieldVision every day.
          </p>
          <Link
            href="/register"
            className="inline-flex items-center gap-2 px-8 py-4 text-lg font-semibold text-white bg-fieldvision-blue rounded-xl hover:bg-fieldvision-blue/90 transition-colors"
          >
            Get Started Free
            <ArrowRight className="w-5 h-5" />
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 px-4 sm:px-6 lg:px-8 border-t">
        <div className="max-w-6xl mx-auto text-center text-sm text-gray-500">
          <p>&copy; {new Date().getFullYear()} FieldVision. All rights reserved.</p>
        </div>
      </footer>
    </main>
  );
}
