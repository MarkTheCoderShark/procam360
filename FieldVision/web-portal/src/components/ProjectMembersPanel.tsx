'use client';

import { useState, useEffect } from 'react';
import { X, UserPlus, Loader2, MoreVertical, Trash2, Shield } from 'lucide-react';
import { RoleBadge } from './RoleBadge';
import { InviteMemberModal } from './InviteMemberModal';
import {
  getProjectMembers,
  updateMemberRole,
  removeMember,
  ProjectMember,
} from '@/lib/projects-api';

type Role = 'ADMIN' | 'CREW' | 'VIEWER';

interface ProjectMembersPanelProps {
  projectId: string;
  isOpen: boolean;
  onClose: () => void;
  isAdmin: boolean;
}

export function ProjectMembersPanel({ projectId, isOpen, onClose, isAdmin }: ProjectMembersPanelProps) {
  const [members, setMembers] = useState<ProjectMember[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [menuOpenFor, setMenuOpenFor] = useState<string | null>(null);
  const [isUpdating, setIsUpdating] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      loadMembers();
    }
  }, [isOpen, projectId]);

  async function loadMembers() {
    setIsLoading(true);
    try {
      const data = await getProjectMembers(projectId);
      setMembers(data);
    } catch (err) {
      console.error('Failed to load members:', err);
    } finally {
      setIsLoading(false);
    }
  }

  async function handleRoleChange(memberId: string, newRole: Role) {
    setIsUpdating(memberId);
    try {
      const updated = await updateMemberRole(projectId, memberId, newRole);
      setMembers(prev => prev.map(m => m.id === memberId ? updated : m));
    } catch (err) {
      console.error('Failed to update role:', err);
      alert(err instanceof Error ? err.message : 'Failed to update role');
    } finally {
      setIsUpdating(null);
      setMenuOpenFor(null);
    }
  }

  async function handleRemoveMember(memberId: string, memberName: string) {
    if (!confirm(`Are you sure you want to remove ${memberName} from this project?`)) return;

    setIsUpdating(memberId);
    try {
      await removeMember(projectId, memberId);
      setMembers(prev => prev.filter(m => m.id !== memberId));
    } catch (err) {
      console.error('Failed to remove member:', err);
      alert(err instanceof Error ? err.message : 'Failed to remove member');
    } finally {
      setIsUpdating(null);
      setMenuOpenFor(null);
    }
  }

  if (!isOpen) return null;

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 z-40 bg-black/50"
        onClick={onClose}
      />

      {/* Panel */}
      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-md bg-white shadow-xl flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold">Project Members</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="w-6 h-6 animate-spin text-fieldvision-blue" />
            </div>
          ) : (
            <div className="space-y-2">
              {members.map((member) => (
                <div
                  key={member.id}
                  className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg"
                >
                  <div className="w-10 h-10 bg-fieldvision-blue rounded-full flex items-center justify-center flex-shrink-0">
                    {member.avatarUrl ? (
                      <img
                        src={member.avatarUrl}
                        alt={member.name}
                        className="w-10 h-10 rounded-full object-cover"
                      />
                    ) : (
                      <span className="text-white font-medium">
                        {member.name.charAt(0).toUpperCase()}
                      </span>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="font-medium text-gray-900 truncate">
                        {member.name}
                        {member.isCurrentUser && (
                          <span className="text-gray-500 font-normal"> (you)</span>
                        )}
                      </p>
                    </div>
                    <p className="text-sm text-gray-500 truncate">{member.email}</p>
                  </div>
                  <RoleBadge role={member.role} size="sm" />

                  {/* Member menu - only show if admin and not self */}
                  {isAdmin && !member.isCurrentUser && (
                    <div className="relative">
                      <button
                        onClick={() => setMenuOpenFor(menuOpenFor === member.id ? null : member.id)}
                        className="p-1 hover:bg-gray-200 rounded transition-colors"
                        disabled={isUpdating === member.id}
                      >
                        {isUpdating === member.id ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          <MoreVertical className="w-4 h-4 text-gray-400" />
                        )}
                      </button>

                      {menuOpenFor === member.id && (
                        <>
                          <div
                            className="fixed inset-0 z-10"
                            onClick={() => setMenuOpenFor(null)}
                          />
                          <div className="absolute right-0 mt-1 w-48 bg-white rounded-lg shadow-lg border py-1 z-20">
                            <div className="px-3 py-1.5 text-xs font-medium text-gray-500 uppercase">
                              Change Role
                            </div>
                            {(['ADMIN', 'CREW', 'VIEWER'] as Role[]).map((r) => (
                              <button
                                key={r}
                                onClick={() => handleRoleChange(member.id, r)}
                                className={`flex items-center gap-2 w-full px-3 py-2 text-sm hover:bg-gray-50 ${
                                  member.role === r ? 'text-fieldvision-blue font-medium' : ''
                                }`}
                              >
                                <Shield className="w-4 h-4" />
                                {r === 'ADMIN' ? 'Admin' : r === 'CREW' ? 'Editor' : 'Viewer'}
                                {member.role === r && ' (current)'}
                              </button>
                            ))}
                            <div className="border-t my-1" />
                            <button
                              onClick={() => handleRemoveMember(member.id, member.name)}
                              className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-600 hover:bg-red-50"
                            >
                              <Trash2 className="w-4 h-4" />
                              Remove from project
                            </button>
                          </div>
                        </>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer - Add member button (only for admins) */}
        {isAdmin && (
          <div className="p-4 border-t">
            <button
              onClick={() => setShowInviteModal(true)}
              className="w-full flex items-center justify-center gap-2 py-2.5 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors"
            >
              <UserPlus className="w-5 h-5" />
              Invite Member
            </button>
          </div>
        )}
      </div>

      {/* Invite Modal */}
      {showInviteModal && (
        <InviteMemberModal
          projectId={projectId}
          onClose={() => setShowInviteModal(false)}
          onMemberAdded={(member) => {
            setMembers(prev => [...prev, member]);
          }}
        />
      )}
    </>
  );
}
