import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.js';

const addContactSchema = z.object({
  email: z.string().email(),
  nickname: z.string().optional(),
  defaultRole: z.enum(['ADMIN', 'CREW', 'VIEWER']).default('CREW'),
});

const updateContactSchema = z.object({
  nickname: z.string().optional(),
  defaultRole: z.enum(['ADMIN', 'CREW', 'VIEWER']).optional(),
});

export async function teamContactRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // GET /v1/team/contacts - List saved contacts
  fastify.get('/contacts', async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const contacts = await prisma.teamContact.findMany({
      where: { ownerId: userId },
      include: {
        contact: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return contacts.map((c: any) => ({
      id: c.id,
      contactId: c.contact.id,
      name: c.contact.name,
      email: c.contact.email,
      avatarUrl: c.contact.avatarUrl,
      nickname: c.nickname,
      defaultRole: c.defaultRole,
      createdAt: c.createdAt,
    }));
  });

  // POST /v1/team/contacts - Add contact by email
  fastify.post('/contacts', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = addContactSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    // Find the user to add as contact
    const userToAdd = await prisma.user.findUnique({
      where: { email: body.email },
    });

    if (!userToAdd) {
      return reply.status(404).send({
        error: 'User not found. They need to create an account first.',
        code: 'USER_NOT_FOUND',
      });
    }

    // Cannot add yourself as a contact
    if (userToAdd.id === userId) {
      return reply.status(400).send({
        error: 'You cannot add yourself as a team contact',
        code: 'SELF_CONTACT',
      });
    }

    // Check if contact already exists
    const existingContact = await prisma.teamContact.findUnique({
      where: {
        ownerId_contactId: {
          ownerId: userId,
          contactId: userToAdd.id,
        },
      },
    });

    if (existingContact) {
      return reply.status(400).send({
        error: 'This user is already in your team contacts',
        code: 'ALREADY_CONTACT',
      });
    }

    const contact = await prisma.teamContact.create({
      data: {
        ownerId: userId,
        contactId: userToAdd.id,
        nickname: body.nickname,
        defaultRole: body.defaultRole,
      },
      include: {
        contact: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
    });

    return {
      id: contact.id,
      contactId: contact.contact.id,
      name: contact.contact.name,
      email: contact.contact.email,
      avatarUrl: contact.contact.avatarUrl,
      nickname: contact.nickname,
      defaultRole: contact.defaultRole,
      createdAt: contact.createdAt,
    };
  });

  // PATCH /v1/team/contacts/:id - Update nickname/defaultRole
  fastify.patch('/contacts/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const body = updateContactSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const contact = await prisma.teamContact.findFirst({
      where: { id, ownerId: userId },
    });

    if (!contact) {
      return reply.status(404).send({ error: 'Contact not found' });
    }

    const updatedContact = await prisma.teamContact.update({
      where: { id },
      data: {
        ...(body.nickname !== undefined && { nickname: body.nickname }),
        ...(body.defaultRole !== undefined && { defaultRole: body.defaultRole }),
      },
      include: {
        contact: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
    });

    return {
      id: updatedContact.id,
      contactId: updatedContact.contact.id,
      name: updatedContact.contact.name,
      email: updatedContact.contact.email,
      avatarUrl: updatedContact.contact.avatarUrl,
      nickname: updatedContact.nickname,
      defaultRole: updatedContact.defaultRole,
      createdAt: updatedContact.createdAt,
    };
  });

  // DELETE /v1/team/contacts/:id - Remove contact
  fastify.delete('/contacts/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const contact = await prisma.teamContact.findFirst({
      where: { id, ownerId: userId },
    });

    if (!contact) {
      return reply.status(404).send({ error: 'Contact not found' });
    }

    await prisma.teamContact.delete({ where: { id } });

    return { success: true };
  });

  // GET /v1/team/collaborators - Auto-derived from past project members
  fastify.get('/collaborators', async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    // Get all projects the user is a member of
    const userProjects = await prisma.projectMember.findMany({
      where: { userId },
      select: { projectId: true },
    });

    const projectIds = userProjects.map((p: any) => p.projectId);

    // Get all other members from those projects
    const collaborators = await prisma.projectMember.findMany({
      where: {
        projectId: { in: projectIds },
        userId: { not: userId },
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
      distinct: ['userId'],
    });

    // Also get existing team contacts to exclude them
    const existingContacts = await prisma.teamContact.findMany({
      where: { ownerId: userId },
      select: { contactId: true },
    });

    const existingContactIds = new Set(existingContacts.map((c: any) => c.contactId));

    // Filter out users who are already team contacts
    const uniqueCollaborators = collaborators.filter(
      (c: any) => !existingContactIds.has(c.user.id)
    );

    return uniqueCollaborators.map((c: any) => ({
      userId: c.user.id,
      name: c.user.name,
      email: c.user.email,
      avatarUrl: c.user.avatarUrl,
    }));
  });
}
