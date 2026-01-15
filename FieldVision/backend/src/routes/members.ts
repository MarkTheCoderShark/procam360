import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.js';

const inviteMemberSchema = z.object({
  email: z.string().email(),
  role: z.enum(['ADMIN', 'CREW', 'VIEWER']).default('CREW'),
});

const updateRoleSchema = z.object({
  role: z.enum(['ADMIN', 'CREW', 'VIEWER']),
});

export async function memberRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/:projectId/members', async (request: FastifyRequest, reply: FastifyReply) => {
    const { projectId } = request.params as { projectId: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId, userId },
    });

    if (!member) {
      return reply.status(403).send({ error: 'Not a member of this project' });
    }

    const members = await prisma.projectMember.findMany({
      where: { projectId },
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
      orderBy: { invitedAt: 'asc' },
    });

    return members.map((m: any) => ({
      id: m.id,
      userId: m.user.id,
      name: m.user.name,
      email: m.user.email,
      avatarUrl: m.user.avatarUrl,
      role: m.role,
      invitedAt: m.invitedAt,
      isCurrentUser: m.userId === userId,
    }));
  });

  fastify.post('/:projectId/members', async (request: FastifyRequest, reply: FastifyReply) => {
    const { projectId } = request.params as { projectId: string };
    const body = inviteMemberSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const adminMember = await prisma.projectMember.findFirst({
      where: { projectId, userId, role: 'ADMIN' },
    });

    if (!adminMember) {
      return reply.status(403).send({ error: 'Only admins can invite members' });
    }

    const userToInvite = await prisma.user.findUnique({
      where: { email: body.email },
    });

    if (!userToInvite) {
      return reply.status(404).send({ 
        error: 'User not found. They need to create an account first.',
        code: 'USER_NOT_FOUND'
      });
    }

    const existingMember = await prisma.projectMember.findFirst({
      where: { projectId, userId: userToInvite.id },
    });

    if (existingMember) {
      return reply.status(400).send({ error: 'User is already a member of this project' });
    }

    const project = await prisma.project.findUnique({
      where: { id: projectId },
      select: { name: true },
    });

    const inviter = await prisma.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });

    const newMember = await prisma.projectMember.create({
      data: {
        projectId,
        userId: userToInvite.id,
        role: body.role,
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
    });

    const pushService = (fastify as any).pushService;
    if (pushService && project && inviter) {
      await pushService.sendToUser(userToInvite.id, {
        title: 'Project Invitation',
        body: `${inviter.name} invited you to join "${project.name}"`,
        data: {
          type: 'project_invite',
          projectId,
          projectName: project.name,
        },
      });
    }

    return {
      id: newMember.id,
      userId: newMember.user.id,
      name: newMember.user.name,
      email: newMember.user.email,
      avatarUrl: newMember.user.avatarUrl,
      role: newMember.role,
      invitedAt: newMember.invitedAt,
    };
  });

  fastify.patch('/:projectId/members/:memberId', async (request: FastifyRequest, reply: FastifyReply) => {
    const { projectId, memberId } = request.params as { projectId: string; memberId: string };
    const body = updateRoleSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const adminMember = await prisma.projectMember.findFirst({
      where: { projectId, userId, role: 'ADMIN' },
    });

    if (!adminMember) {
      return reply.status(403).send({ error: 'Only admins can update member roles' });
    }

    const targetMember = await prisma.projectMember.findUnique({
      where: { id: memberId },
    });

    if (!targetMember || targetMember.projectId !== projectId) {
      return reply.status(404).send({ error: 'Member not found' });
    }

    if (targetMember.userId === userId && body.role !== 'ADMIN') {
      const adminCount = await prisma.projectMember.count({
        where: { projectId, role: 'ADMIN' },
      });

      if (adminCount <= 1) {
        return reply.status(400).send({ error: 'Cannot remove the last admin from the project' });
      }
    }

    const updatedMember = await prisma.projectMember.update({
      where: { id: memberId },
      data: { role: body.role },
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
    });

    return {
      id: updatedMember.id,
      userId: updatedMember.user.id,
      name: updatedMember.user.name,
      email: updatedMember.user.email,
      avatarUrl: updatedMember.user.avatarUrl,
      role: updatedMember.role,
      invitedAt: updatedMember.invitedAt,
    };
  });

  fastify.delete('/:projectId/members/:memberId', async (request: FastifyRequest, reply: FastifyReply) => {
    const { projectId, memberId } = request.params as { projectId: string; memberId: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const adminMember = await prisma.projectMember.findFirst({
      where: { projectId, userId, role: 'ADMIN' },
    });

    const targetMember = await prisma.projectMember.findUnique({
      where: { id: memberId },
    });

    if (!targetMember || targetMember.projectId !== projectId) {
      return reply.status(404).send({ error: 'Member not found' });
    }

    const isSelf = targetMember.userId === userId;

    if (!adminMember && !isSelf) {
      return reply.status(403).send({ error: 'Only admins can remove other members' });
    }

    if (targetMember.role === 'ADMIN') {
      const adminCount = await prisma.projectMember.count({
        where: { projectId, role: 'ADMIN' },
      });

      if (adminCount <= 1) {
        return reply.status(400).send({ error: 'Cannot remove the last admin from the project' });
      }
    }

    await prisma.projectMember.delete({ where: { id: memberId } });

    return { success: true };
  });
}
