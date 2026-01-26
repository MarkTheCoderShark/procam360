'use client';

import { cn } from '@/lib/utils';

type Role = 'ADMIN' | 'CREW' | 'VIEWER';

interface RoleBadgeProps {
  role: Role;
  size?: 'sm' | 'md';
}

const roleConfig: Record<Role, { label: string; className: string }> = {
  ADMIN: {
    label: 'Admin',
    className: 'bg-purple-100 text-purple-700 border-purple-200',
  },
  CREW: {
    label: 'Editor',
    className: 'bg-blue-100 text-blue-700 border-blue-200',
  },
  VIEWER: {
    label: 'Viewer',
    className: 'bg-gray-100 text-gray-700 border-gray-200',
  },
};

export function RoleBadge({ role, size = 'md' }: RoleBadgeProps) {
  const config = roleConfig[role];

  return (
    <span
      className={cn(
        'inline-flex items-center font-medium rounded-full border',
        config.className,
        size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-2.5 py-1 text-sm'
      )}
    >
      {config.label}
    </span>
  );
}

export function getRoleLabel(role: Role): string {
  return roleConfig[role].label;
}
