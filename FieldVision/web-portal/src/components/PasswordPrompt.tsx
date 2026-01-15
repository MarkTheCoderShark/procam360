'use client';

import { useState } from 'react';
import { Lock } from 'lucide-react';

interface PasswordPromptProps {
  onSubmit: (password: string) => void;
  error?: string;
}

export function PasswordPrompt({ onSubmit, error }: PasswordPromptProps) {
  const [password, setPassword] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (password.trim()) {
      onSubmit(password.trim());
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-2xl shadow-xl p-8">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-fieldvision-blue/10 rounded-full flex items-center justify-center mx-auto mb-4">
            <Lock className="w-8 h-8 text-fieldvision-blue" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900">Password Required</h1>
          <p className="text-gray-600 mt-2">
            This shared project is password protected
          </p>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label htmlFor="password" className="sr-only">
              Password
            </label>
            <input
              type="password"
              id="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter password"
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fieldvision-blue focus:border-transparent"
              autoFocus
            />
            {error && (
              <p className="mt-2 text-sm text-red-600">{error}</p>
            )}
          </div>

          <button
            type="submit"
            disabled={!password.trim()}
            className="w-full py-3 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            View Project
          </button>
        </form>
      </div>
    </div>
  );
}
