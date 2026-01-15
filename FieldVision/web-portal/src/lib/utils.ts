import { clsx, type ClassValue } from 'clsx';

export function cn(...inputs: ClassValue[]) {
  return clsx(inputs);
}

export function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export function formatDateTime(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

export function groupPhotosByDate<T extends { capturedAt: string }>(
  photos: T[]
): Map<string, T[]> {
  const grouped = new Map<string, T[]>();

  for (const photo of photos) {
    const dateKey = new Date(photo.capturedAt).toDateString();
    const existing = grouped.get(dateKey) || [];
    grouped.set(dateKey, [...existing, photo]);
  }

  return grouped;
}
