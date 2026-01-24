import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.js';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(1),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

const appleSignInSchema = z.object({
  identityToken: z.string(),
  name: z.string().optional(),
  email: z.string().email().optional(),
});

const changePasswordSchema = z.object({
  currentPassword: z.string(),
  newPassword: z.string().min(8),
});

const updateProfileSchema = z.object({
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
});

export async function authRoutes(fastify: FastifyInstance) {
  fastify.post('/register', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = registerSchema.parse(request.body);
    const prisma = (fastify as any).prisma;

    const existingUser = await prisma.user.findUnique({
      where: { email: body.email },
    });

    if (existingUser) {
      return reply.status(400).send({ error: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(body.password, 12);

    const user = await prisma.user.create({
      data: {
        email: body.email,
        password: hashedPassword,
        name: body.name,
      },
    });

    const { accessToken, refreshToken } = await generateTokens(fastify, prisma, user.id);

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
      },
    };
  });

  fastify.post('/login', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = loginSchema.parse(request.body);
    const prisma = (fastify as any).prisma;

    const user = await prisma.user.findUnique({
      where: { email: body.email },
    });

    if (!user || !user.password) {
      return reply.status(401).send({ error: 'Invalid credentials' });
    }

    const validPassword = await bcrypt.compare(body.password, user.password);
    if (!validPassword) {
      return reply.status(401).send({ error: 'Invalid credentials' });
    }

    const { accessToken, refreshToken } = await generateTokens(fastify, prisma, user.id);

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
      },
    };
  });

  fastify.post('/apple', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = appleSignInSchema.parse(request.body);
    const prisma = (fastify as any).prisma;

    const appleId = extractAppleIdFromToken(body.identityToken);
    
    if (!appleId) {
      return reply.status(400).send({ error: 'Invalid Apple identity token' });
    }

    let user = await prisma.user.findUnique({
      where: { appleId },
    });

    if (!user) {
      if (!body.email) {
        return reply.status(400).send({ error: 'Email required for first sign in' });
      }

      user = await prisma.user.create({
        data: {
          appleId,
          email: body.email,
          name: body.name || 'Apple User',
        },
      });
    }

    const { accessToken, refreshToken } = await generateTokens(fastify, prisma, user.id);

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
      },
    };
  });

  fastify.post('/refresh', async (request: FastifyRequest, reply: FastifyReply) => {
    const { refreshToken: token } = request.body as { refreshToken: string };
    const prisma = (fastify as any).prisma;

    if (!token) {
      return reply.status(400).send({ error: 'Refresh token required' });
    }

    const storedToken = await prisma.refreshToken.findUnique({
      where: { token },
      include: { user: true },
    });

    if (!storedToken || storedToken.expiresAt < new Date()) {
      return reply.status(401).send({ error: 'Invalid or expired refresh token' });
    }

    await prisma.refreshToken.delete({ where: { id: storedToken.id } });

    const { accessToken, refreshToken } = await generateTokens(fastify, prisma, storedToken.userId);

    return { accessToken, refreshToken };
  });

  fastify.post('/logout', async (request: FastifyRequest, reply: FastifyReply) => {
    const { refreshToken: token } = request.body as { refreshToken: string };
    const prisma = (fastify as any).prisma;

    if (token) {
      await prisma.refreshToken.deleteMany({ where: { token } });
    }

    return { success: true };
  });

  fastify.get('/me', { preHandler: authenticate }, async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        avatarUrl: true,
        subscriptionTier: true,
        subscriptionExpiresAt: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }

    const isPro = user.subscriptionTier !== 'FREE' && 
      (!user.subscriptionExpiresAt || user.subscriptionExpiresAt > new Date());

    return {
      ...user,
      isPro,
    };
  });

  fastify.patch('/me', { preHandler: authenticate }, async (request: FastifyRequest, reply: FastifyReply) => {
    const body = updateProfileSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    if (body.email) {
      const existingUser = await prisma.user.findFirst({
        where: {
          email: body.email,
          NOT: { id: userId },
        },
      });

      if (existingUser) {
        return reply.status(400).send({ error: 'Email already in use' });
      }
    }

    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        ...(body.name && { name: body.name }),
        ...(body.email && { email: body.email }),
      },
      select: {
        id: true,
        email: true,
        name: true,
        avatarUrl: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return user;
  });

  fastify.patch('/password', { preHandler: authenticate }, async (request: FastifyRequest, reply: FastifyReply) => {
    const body = changePasswordSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }

    if (!user.password) {
      return reply.status(400).send({ 
        error: 'Cannot change password for Apple Sign-In accounts. Please use Apple ID to manage your account.',
        code: 'APPLE_ACCOUNT'
      });
    }

    const validPassword = await bcrypt.compare(body.currentPassword, user.password);
    if (!validPassword) {
      return reply.status(401).send({ error: 'Current password is incorrect' });
    }

    const hashedPassword = await bcrypt.hash(body.newPassword, 12);
    await prisma.user.update({
      where: { id: userId },
      data: { password: hashedPassword },
    });

    await prisma.refreshToken.deleteMany({ where: { userId } });

    const { accessToken, refreshToken } = await generateTokens(fastify, prisma, userId);

    return { 
      success: true, 
      message: 'Password changed successfully',
      accessToken,
      refreshToken,
    };
  });

  fastify.delete('/account', { preHandler: authenticate }, async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        projects: {
          include: {
            project: {
              include: {
                members: true,
              },
            },
          },
        },
      },
    });

    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }

    for (const membership of user.projects) {
      if (membership.role === 'ADMIN') {
        const adminCount = membership.project.members.filter((m: { role: string }) => m.role === 'ADMIN').length;
        if (adminCount === 1 && membership.project.members.length > 1) {
          return reply.status(400).send({
            error: `You are the only admin of project "${membership.project.name}". Please transfer ownership or remove other members before deleting your account.`,
            code: 'SOLE_ADMIN',
            projectId: membership.project.id,
            projectName: membership.project.name,
          });
        }
      }
    }

    await prisma.refreshToken.deleteMany({ where: { userId } });
    await prisma.deviceToken.deleteMany({ where: { userId } });
    await prisma.notificationPreferences.deleteMany({ where: { userId } });
    await prisma.comment.deleteMany({ where: { userId } });
    await prisma.shareLink.deleteMany({ where: { createdById: userId } });
    
    for (const membership of user.projects) {
      if (membership.project.members.length === 1) {
        await prisma.project.delete({ where: { id: membership.projectId } });
      } else {
        await prisma.projectMember.delete({ where: { id: membership.id } });
      }
    }
    
    await prisma.photo.deleteMany({ where: { uploaderId: userId } });
    await prisma.user.delete({ where: { id: userId } });

    return { 
      success: true, 
      message: 'Account deleted successfully. All your data has been permanently removed.' 
    };
  });
}

async function generateTokens(fastify: FastifyInstance, prisma: any, userId: string) {
  const accessToken = fastify.jwt.sign(
    { userId },
    { expiresIn: '15m' }
  );

  const refreshToken = fastify.jwt.sign(
    { userId, type: 'refresh' },
    { expiresIn: '30d' }
  );

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);

  await prisma.refreshToken.create({
    data: {
      token: refreshToken,
      userId,
      expiresAt,
    },
  });

  return { accessToken, refreshToken };
}

function extractAppleIdFromToken(identityToken: string): string | null {
  try {
    const parts = identityToken.split('.');
    if (parts.length !== 3) return null;
    
    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
    return payload.sub || null;
  } catch {
    return null;
  }
}
