import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import multipart from '@fastify/multipart';
import { PrismaClient } from '@prisma/client';
import { authRoutes } from './routes/auth.js';
import { projectRoutes } from './routes/projects.js';
import { photoRoutes } from './routes/photos.js';
import { shareRoutes } from './routes/share.js';
import { notificationRoutes } from './routes/notifications.js';
import { searchRoutes } from './routes/search.js';
import { createPushService } from './services/push.js';

const prisma = new PrismaClient();

const fastify = Fastify({
  logger: true,
});

fastify.register(cors, {
  origin: true,
  credentials: true,
});

fastify.register(jwt, {
  secret: process.env.JWT_SECRET || 'your-super-secret-key-change-in-production',
});

fastify.register(multipart, {
  limits: {
    fileSize: 100 * 1024 * 1024,
  },
});

fastify.decorate('prisma', prisma);
fastify.decorate('pushService', createPushService(prisma));

fastify.addHook('onClose', async () => {
  await prisma.$disconnect();
});

fastify.register(authRoutes, { prefix: '/v1/auth' });
fastify.register(projectRoutes, { prefix: '/v1/projects' });
fastify.register(photoRoutes, { prefix: '/v1/photos' });
fastify.register(shareRoutes, { prefix: '/v1/share' });
fastify.register(notificationRoutes, { prefix: '/v1/notifications' });
fastify.register(searchRoutes, { prefix: '/v1/search' });

fastify.get('/health', async () => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

const start = async () => {
  try {
    const port = parseInt(process.env.PORT || '3000', 10);
    const host = process.env.HOST || '0.0.0.0';
    
    await fastify.listen({ port, host });
    console.log(`Server running at http://${host}:${port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
