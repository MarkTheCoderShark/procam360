'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import { DashboardLayout } from '@/components/DashboardLayout';
import { RoleBadge } from '@/components/RoleBadge';
import {
  getTeamContacts,
  addTeamContact,
  updateTeamContact,
  removeTeamContact,
  getPastCollaborators,
  TeamContact,
  Collaborator,
} from '@/lib/projects-api';
import {
  Loader2,
  UserPlus,
  Users,
  Mail,
  MoreVertical,
  Trash2,
  Edit2,
  X,
  Check,
  UserCheck,
} from 'lucide-react';

type Role = 'ADMIN' | 'CREW' | 'VIEWER';

export default function TeamPage() {
  const router = useRouter();
  const { isAuthenticated, isLoading: authLoading } = useAuth();

  const [contacts, setContacts] = useState<TeamContact[]>([]);
  const [collaborators, setCollaborators] = useState<Collaborator[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const [showAddContact, setShowAddContact] = useState(false);
  const [newEmail, setNewEmail] = useState('');
  const [newNickname, setNewNickname] = useState('');
  const [newRole, setNewRole] = useState<Role>('CREW');
  const [isAdding, setIsAdding] = useState(false);
  const [addError, setAddError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editNickname, setEditNickname] = useState('');
  const [editRole, setEditRole] = useState<Role>('CREW');

  const [menuOpenFor, setMenuOpenFor] = useState<string | null>(null);
  const [isUpdating, setIsUpdating] = useState<string | null>(null);

  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [authLoading, isAuthenticated, router]);

  useEffect(() => {
    if (isAuthenticated) {
      loadData();
    }
  }, [isAuthenticated]);

  async function loadData() {
    setIsLoading(true);
    try {
      const [contactsData, collaboratorsData] = await Promise.all([
        getTeamContacts(),
        getPastCollaborators(),
      ]);
      setContacts(contactsData);
      setCollaborators(collaboratorsData);
    } catch (err) {
      console.error('Failed to load team data:', err);
    } finally {
      setIsLoading(false);
    }
  }

  async function handleAddContact(e: React.FormEvent) {
    e.preventDefault();
    if (!newEmail.trim()) return;

    setIsAdding(true);
    setAddError(null);

    try {
      const contact = await addTeamContact(newEmail.trim(), newNickname.trim() || undefined, newRole);
      setContacts((prev) => [contact, ...prev]);
      setNewEmail('');
      setNewNickname('');
      setNewRole('CREW');
      setShowAddContact(false);
      // Remove from collaborators if present
      setCollaborators((prev) => prev.filter((c) => c.userId !== contact.contactId));
    } catch (err) {
      setAddError(err instanceof Error ? err.message : 'Failed to add contact');
    } finally {
      setIsAdding(false);
    }
  }

  async function handleAddCollaborator(collaborator: Collaborator) {
    setIsUpdating(collaborator.userId);
    try {
      const contact = await addTeamContact(collaborator.email, undefined, 'CREW');
      setContacts((prev) => [contact, ...prev]);
      setCollaborators((prev) => prev.filter((c) => c.userId !== collaborator.userId));
    } catch (err) {
      console.error('Failed to add collaborator:', err);
      alert(err instanceof Error ? err.message : 'Failed to add contact');
    } finally {
      setIsUpdating(null);
    }
  }

  async function handleUpdateContact(id: string) {
    setIsUpdating(id);
    try {
      const updated = await updateTeamContact(id, {
        nickname: editNickname || undefined,
        defaultRole: editRole,
      });
      setContacts((prev) => prev.map((c) => (c.id === id ? updated : c)));
      setEditingId(null);
    } catch (err) {
      console.error('Failed to update contact:', err);
      alert(err instanceof Error ? err.message : 'Failed to update contact');
    } finally {
      setIsUpdating(null);
    }
  }

  async function handleRemoveContact(id: string, name: string) {
    if (!confirm(`Remove ${name} from your team contacts?`)) return;

    setIsUpdating(id);
    try {
      await removeTeamContact(id);
      setContacts((prev) => prev.filter((c) => c.id !== id));
    } catch (err) {
      console.error('Failed to remove contact:', err);
      alert(err instanceof Error ? err.message : 'Failed to remove contact');
    } finally {
      setIsUpdating(null);
      setMenuOpenFor(null);
    }
  }

  function startEditing(contact: TeamContact) {
    setEditingId(contact.id);
    setEditNickname(contact.nickname || '');
    setEditRole(contact.defaultRole);
    setMenuOpenFor(null);
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
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">My Team</h1>
            <p className="text-gray-500 mt-1">
              Manage your saved contacts for quick project sharing
            </p>
          </div>
          <button
            onClick={() => setShowAddContact(true)}
            className="flex items-center gap-2 px-4 py-2 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 transition-colors"
          >
            <UserPlus className="w-5 h-5" />
            <span className="hidden sm:inline">Add Contact</span>
          </button>
        </div>

        {/* Add Contact Form */}
        {showAddContact && (
          <div className="bg-white rounded-xl border p-4 mb-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900">Add Team Contact</h3>
              <button
                onClick={() => {
                  setShowAddContact(false);
                  setNewEmail('');
                  setNewNickname('');
                  setNewRole('CREW');
                  setAddError(null);
                }}
                className="p-1 hover:bg-gray-100 rounded-lg"
              >
                <X className="w-5 h-5 text-gray-400" />
              </button>
            </div>
            <form onSubmit={handleAddContact} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Email Address *
                  </label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                    <input
                      type="email"
                      value={newEmail}
                      onChange={(e) => setNewEmail(e.target.value)}
                      placeholder="colleague@company.com"
                      className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                      required
                      autoFocus
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nickname (optional)
                  </label>
                  <input
                    type="text"
                    value={newNickname}
                    onChange={(e) => setNewNickname(e.target.value)}
                    placeholder="e.g., Site Foreman"
                    className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Default Role
                </label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value as Role)}
                  className="w-full sm:w-auto px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                >
                  <option value="ADMIN">Admin</option>
                  <option value="CREW">Editor</option>
                  <option value="VIEWER">Viewer</option>
                </select>
                <p className="text-xs text-gray-500 mt-1">
                  This role will be pre-selected when inviting this contact to projects
                </p>
              </div>
              {addError && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                  {addError}
                </div>
              )}
              <div className="flex justify-end gap-3">
                <button
                  type="button"
                  onClick={() => {
                    setShowAddContact(false);
                    setAddError(null);
                  }}
                  className="px-4 py-2 border rounded-lg text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isAdding || !newEmail.trim()}
                  className="px-4 py-2 bg-fieldvision-blue text-white rounded-lg font-semibold hover:bg-fieldvision-blue/90 disabled:opacity-50 flex items-center gap-2"
                >
                  {isAdding ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Adding...
                    </>
                  ) : (
                    'Add Contact'
                  )}
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Main Content */}
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <Loader2 className="w-8 h-8 animate-spin text-fieldvision-blue" />
          </div>
        ) : (
          <div className="space-y-6">
            {/* Team Contacts */}
            <div className="bg-white rounded-xl border">
              <div className="p-4 border-b">
                <div className="flex items-center gap-2">
                  <Users className="w-5 h-5 text-fieldvision-blue" />
                  <h2 className="font-semibold text-gray-900">Team Contacts</h2>
                  <span className="text-sm text-gray-500">({contacts.length})</span>
                </div>
              </div>

              {contacts.length === 0 ? (
                <div className="p-8 text-center">
                  <Users className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                  <p className="text-gray-500">No team contacts yet</p>
                  <p className="text-sm text-gray-400 mt-1">
                    Add contacts for quick project sharing
                  </p>
                </div>
              ) : (
                <div className="divide-y">
                  {contacts.map((contact) => (
                    <div
                      key={contact.id}
                      className="flex items-center gap-3 p-4 hover:bg-gray-50"
                    >
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

                      {editingId === contact.id ? (
                        <div className="flex-1 flex items-center gap-3">
                          <input
                            type="text"
                            value={editNickname}
                            onChange={(e) => setEditNickname(e.target.value)}
                            placeholder="Nickname"
                            className="flex-1 px-3 py-1.5 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                          />
                          <select
                            value={editRole}
                            onChange={(e) => setEditRole(e.target.value as Role)}
                            className="px-3 py-1.5 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-fieldvision-blue"
                          >
                            <option value="ADMIN">Admin</option>
                            <option value="CREW">Editor</option>
                            <option value="VIEWER">Viewer</option>
                          </select>
                          <button
                            onClick={() => handleUpdateContact(contact.id)}
                            disabled={isUpdating === contact.id}
                            className="p-1.5 bg-green-500 text-white rounded-lg hover:bg-green-600 disabled:opacity-50"
                          >
                            {isUpdating === contact.id ? (
                              <Loader2 className="w-4 h-4 animate-spin" />
                            ) : (
                              <Check className="w-4 h-4" />
                            )}
                          </button>
                          <button
                            onClick={() => setEditingId(null)}
                            className="p-1.5 bg-gray-200 text-gray-600 rounded-lg hover:bg-gray-300"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      ) : (
                        <>
                          <div className="flex-1 min-w-0">
                            <p className="font-medium text-gray-900 truncate">
                              {contact.nickname || contact.name}
                              {contact.nickname && (
                                <span className="text-gray-500 font-normal ml-1">
                                  ({contact.name})
                                </span>
                              )}
                            </p>
                            <p className="text-sm text-gray-500 truncate">
                              {contact.email}
                            </p>
                          </div>
                          <RoleBadge role={contact.defaultRole} size="sm" />

                          <div className="relative">
                            <button
                              onClick={() =>
                                setMenuOpenFor(
                                  menuOpenFor === contact.id ? null : contact.id
                                )
                              }
                              className="p-1 hover:bg-gray-200 rounded transition-colors"
                              disabled={isUpdating === contact.id}
                            >
                              {isUpdating === contact.id ? (
                                <Loader2 className="w-4 h-4 animate-spin" />
                              ) : (
                                <MoreVertical className="w-4 h-4 text-gray-400" />
                              )}
                            </button>

                            {menuOpenFor === contact.id && (
                              <>
                                <div
                                  className="fixed inset-0 z-10"
                                  onClick={() => setMenuOpenFor(null)}
                                />
                                <div className="absolute right-0 mt-1 w-40 bg-white rounded-lg shadow-lg border py-1 z-20">
                                  <button
                                    onClick={() => startEditing(contact)}
                                    className="flex items-center gap-2 w-full px-3 py-2 text-sm hover:bg-gray-50"
                                  >
                                    <Edit2 className="w-4 h-4" />
                                    Edit
                                  </button>
                                  <button
                                    onClick={() =>
                                      handleRemoveContact(contact.id, contact.name)
                                    }
                                    className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-600 hover:bg-red-50"
                                  >
                                    <Trash2 className="w-4 h-4" />
                                    Remove
                                  </button>
                                </div>
                              </>
                            )}
                          </div>
                        </>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Past Collaborators */}
            {collaborators.length > 0 && (
              <div className="bg-white rounded-xl border">
                <div className="p-4 border-b">
                  <div className="flex items-center gap-2">
                    <UserCheck className="w-5 h-5 text-green-600" />
                    <h2 className="font-semibold text-gray-900">Past Collaborators</h2>
                    <span className="text-sm text-gray-500">({collaborators.length})</span>
                  </div>
                  <p className="text-sm text-gray-500 mt-1">
                    People you&apos;ve worked with on previous projects
                  </p>
                </div>

                <div className="divide-y">
                  {collaborators.map((collaborator) => (
                    <div
                      key={collaborator.userId}
                      className="flex items-center gap-3 p-4 hover:bg-gray-50"
                    >
                      <div className="w-10 h-10 bg-gray-400 rounded-full flex items-center justify-center flex-shrink-0">
                        {collaborator.avatarUrl ? (
                          <img
                            src={collaborator.avatarUrl}
                            alt={collaborator.name}
                            className="w-10 h-10 rounded-full object-cover"
                          />
                        ) : (
                          <span className="text-white font-medium">
                            {collaborator.name.charAt(0).toUpperCase()}
                          </span>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-medium text-gray-900 truncate">
                          {collaborator.name}
                        </p>
                        <p className="text-sm text-gray-500 truncate">
                          {collaborator.email}
                        </p>
                      </div>
                      <button
                        onClick={() => handleAddCollaborator(collaborator)}
                        disabled={isUpdating === collaborator.userId}
                        className="flex items-center gap-1 px-3 py-1.5 border rounded-lg text-sm font-medium hover:bg-gray-50 disabled:opacity-50"
                      >
                        {isUpdating === collaborator.userId ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          <>
                            <UserPlus className="w-4 h-4" />
                            Add to Team
                          </>
                        )}
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
