import { FastifyInstance, FastifyRequest } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { authenticate } from '../middleware/auth.js';

interface RegisterDeviceBody {
  token: string;
  platform: string;
}

interface PreferencesBody {
  newPhotos?: boolean;
  newComments?: boolean;
  projectInvites?: boolean;
  syncComplete?: boolean;
}

export async function notificationRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.post<{ Body: RegisterDeviceBody }>(
    '/register',
    async (request, reply) => {
      const { token, platform } = request.body;
      const userId = (request.user as { id: string }).id;

      await (fastify as any).prisma.deviceToken.upsert({
        where: { token },
        update: { userId, platform, updatedAt: new Date() },
        create: { userId, token, platform },
      });

      return reply.status(200).send({});
    }
  );

  fastify.post<{ Body: { token: string } }>(
    '/unregister',
    async (request, reply) => {
      const { token } = request.body;

      await (fastify as any).prisma.deviceToken.deleteMany({
        where: { token, userId: (request.user as { id: string }).id },
      });

      return reply.status(200).send({});
    }
  );

  fastify.get('/preferences', async (request, reply) => {
    const userId = (request.user as { id: string }).id;

    let prefs = await (fastify as any).prisma.notificationPreferences.findUnique({
      where: { userId },
    });

    if (!prefs) {
      prefs = await (fastify as any).prisma.notificationPreferences.create({
        data: { userId },
      });
    }

    return {
      newPhotos: prefs.newPhotos,
      newComments: prefs.newComments,
      projectInvites: prefs.projectInvites,
      syncComplete: prefs.syncComplete,
    };
  });

  fastify.patch<{ Body: PreferencesBody }>(
    '/preferences',
    async (request, reply) => {
      const userId = (request.user as { id: string }).id;
      const { newPhotos, newComments, projectInvites, syncComplete } = request.body;

      const prefs = await (fastify as any).prisma.notificationPreferences.upsert({
        where: { userId },
        update: {
          ...(newPhotos !== undefined && { newPhotos }),
          ...(newComments !== undefined && { newComments }),
          ...(projectInvites !== undefined && { projectInvites }),
          ...(syncComplete !== undefined && { syncComplete }),
        },
        create: {
          userId,
          newPhotos: newPhotos ?? true,
          newComments: newComments ?? true,
          projectInvites: projectInvites ?? true,
          syncComplete: syncComplete ?? false,
        },
      });

      return {
        newPhotos: prefs.newPhotos,
        newComments: prefs.newComments,
        projectInvites: prefs.projectInvites,
        syncComplete: prefs.syncComplete,
      };
    }
  );
}
