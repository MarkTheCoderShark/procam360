'use client';

import { useState, useEffect } from 'react';
import { X, Loader2, Users, Check, AlertCircle } from 'lucide-react';
import { RoleBadge } from './RoleBadge';
import {
  getTeamContacts,
  bulkInviteMembers,
  TeamContact,
  ProjectMember,
} from '@/lib/projects-api';

type Role = 'ADMIN' | 'CREW' | 'VIEWER';

interface ShareWithTeamModalProps {
  projectId: string;
  existingMemberIds: string[];
  onClose: () => void;
  onMembersAdded: (members: ProjectMember[]) => void;
}

interface SelectedContact {
  contactId: string;
  email: string;
  role: Role;
}

export function ShareWithTeamModal({
  projectId,
  existingMemberIds,
  onClose,
  onMembersAdded,
}: ShareWithTeamModalProps) {
  const [contacts, setContacts] = useState<TeamContact[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedContacts, setSelectedContacts] = useState<SelectedContact[]>([]);
  const [isInviting, setIsInviting] = useState(false);
  const [results, setResults] = useState<{
    success: number;
    failed: number;
    errors: string[];
  } | null>(null);

  useEffect(() => {
    loadContacts();
  }, []);

  async function loadContacts() {
    try {
      const data = await getTeamContacts();
      // Filter out contacts who are already members
      const availableContacts = data.filter(
        (c) => !existingMemberIds.includes(c.contactId)
      );
      setContacts(availableContacts);
    } catch (err) {
      console.error('Failed to load team contacts:', err);
    } finally {
      setIsLoading(false);
    }
  }

  function toggleContact(contact: TeamContact) {
    const existing = selectedContacts.find((s) => s.contactId === contact.contactId);
    if (existing) {
      setSelectedContacts((prev) =>
        prev.filter((s) => s.contactId !== contact.contactId)
      );
    } else {
      setSelectedContacts((prev) => [
        ...prev,
        {
          contactId: contact.contactId,
          email: contact.email,
          role: contact.defaultRole,
        },
      ]);
    }
  }

  function updateRole(contactId: string, role: Role) {
    setSelectedContacts((prev) =>
      prev.map((s) => (s.contactId === contactId ? { ...s, role } : s))
    );
  }

  async function handleInvite() {
    if (selectedContacts.length === 0) return;

    setIsInviting(true);
    setResults(null);

    try {
      const invites = selectedContacts.map((s) => ({
        email: s.email,
        role: s.role,
      }));

      const response = await bulkInviteMembers(projectId, invites);

      const newMembers = response.results
        .filter((r) => r.success && r.member)
        .map((r) => r.member as ProjectMember);

      const errors = response.results
        .filter((r) => !r.success)
        .map((r) => `${r.email}: ${r.error}`);

      setResults({
        success: response.summary.successful,
        failed: response.summary.failed,
        errors,
      });

      if (newMembers.length > 0) {
        onMembersAdded(newMembers);
      }
    } catch (err) {
      setResults({
        success: 0,
        failed: selectedContacts.length,
        errors: [err instanceof Error ? err.message : 'Failed to invite members'],
      });
    } finally {
      setIsInviting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <div className="bg-white rounded-xl max-w-lg w-full max-h-[80vh] flex flex-col shadow-xl">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b">
          <div className="flex items-center gap-2">
            <Users className="w-5 h-5 text-fieldvision-blue" />
            <h2 className="text-lg font-semibold">Share with Team</h2>
          </div>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">
          {results ? (
            <div className="space-y-4">
              <div className={`p-4 rounded-lg ${results.failed === 0 ? 'bg-green-50 border border-green-200' : 'bg-yellow-50 border border-yellow-200'}`}>
                <p className="font-medium">
                  {results.success > 0 && `${results.success} member${results.success !== 1 ? 's' : ''} invited successfully`}
                  {results.success > 0 && results.failed > 0 && ', '}
                  {results.failed > 0 && `${results.failed} failed`}
                </p>
              </div>
              {results.errors.length > 0 && (
                <div className="space-y-2">
                  {results.errors.map((error, i) => (
                    <div key={i} className="flex items-start gap-2 text-sm text-red-600">
                      <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                      {error}
                    </div>
                  ))}
                </div>
              )}
              <button
                onClick={onClose}
                className="w-full py-2.5 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors"
              >
                Done
              </button>
            </div>
          ) : isLoading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="w-6 h-6 animate-spin text-fieldvision-blue" />
            </div>
          ) : contacts.length === 0 ? (
            <div className="text-center py-8">
              <Users className="w-12 h-12 text-gray-300 mx-auto mb-3" />
              <p className="text-gray-500">No team contacts available</p>
              <p className="text-sm text-gray-400 mt-1">
                Add contacts in the Team page first
              </p>
            </div>
          ) : (
            <div className="space-y-2">
              <p className="text-sm text-gray-500 mb-3">
                Select team members to invite to this project
              </p>
              {contacts.map((contact) => {
                const selected = selectedContacts.find(
                  (s) => s.contactId === contact.contactId
                );
                return (
                  <div
                    key={contact.id}
                    className={`flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-colors ${
                      selected
                        ? 'border-fieldvision-blue bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                    onClick={() => toggleContact(contact)}
                  >
                    <div
                      className={`w-5 h-5 rounded border-2 flex items-center justify-center ${
                        selected
                          ? 'bg-fieldvision-blue border-fieldvision-blue'
                          : 'border-gray-300'
                      }`}
                    >
                      {selected && <Check className="w-3 h-3 text-white" />}
                    </div>
                    <div className="w-10 h-10 bg-fieldvision-blue rounded-full flex items-center justify-center flex-shrink-0">
                      {contact.avatarUrl ? (
                        <img
                          src={contact.avatarUrl}
                          alt={contact.name}
                          className="w-10 h-10 rounded-full object-cover"
                        />
                      ) : (
                        <span className="text-white font-medium">
                          {contact.name.charAt(0).toUpperCase()}
                        </span>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-gray-900 truncate">
                        {contact.nickname || contact.name}
                      </p>
                      <p className="text-sm text-gray-500 truncate">
                        {contact.email}
                      </p>
                    </div>
                    {selected && (
                      <select
                        value={selected.role}
                        onChange={(e) => {
                          e.stopPropagation();
                          updateRole(contact.contactId, e.target.value as Role);
                        }}
                        onClick={(e) => e.stopPropagation()}
                        className="text-sm border rounded-lg px-2 py-1 focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                      >
                        <option value="ADMIN">Admin</option>
                        <option value="CREW">Editor</option>
                        <option value="VIEWER">Viewer</option>
                      </select>
                    )}
                    {!selected && <RoleBadge role={contact.defaultRole} size="sm" />}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Footer */}
        {!results && contacts.length > 0 && (
          <div className="p-4 border-t">
            <button
              onClick={handleInvite}
              disabled={selectedContacts.length === 0 || isInviting}
              className="w-full py-2.5 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isInviting ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Inviting...
                </>
              ) : (
                `Invite ${selectedContacts.length} Member${selectedContacts.length !== 1 ? 's' : ''}`
              )}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
