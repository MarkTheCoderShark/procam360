import { FastifyRequest, FastifyReply } from 'fastify';

export async function authenticate(request: FastifyRequest, reply: FastifyReply) {
  try {
    const authHeader = request.headers.authorization;
    
    if (!authHeader?.startsWith('Bearer ')) {
      return reply.status(401).send({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);
    const decoded = await (request.server as any).jwt.verify(token);
    
    (request as any).userId = decoded.userId;
  } catch (error) {
    return reply.status(401).send({ error: 'Invalid or expired token' });
  }
}

export async function requirePro(request: FastifyRequest, reply: FastifyReply) {
  const prisma = (request.server as any).prisma;
  const userId = (request as any).userId;

  if (!userId) {
    return reply.status(401).send({ error: 'Authentication required' });
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { subscriptionTier: true, subscriptionExpiresAt: true },
  });

  if (!user) {
    return reply.status(404).send({ error: 'User not found' });
  }

  const isPro = user.subscriptionTier !== 'FREE' && 
    (!user.subscriptionExpiresAt || user.subscriptionExpiresAt > new Date());

  if (!isPro) {
    return reply.status(403).send({ 
      error: 'Pro subscription required',
      code: 'PRO_REQUIRED',
    });
  }

  (request as any).isPro = true;
}

export async function checkSubscriptionLimits(request: FastifyRequest, reply: FastifyReply) {
  const prisma = (request.server as any).prisma;
  const userId = (request as any).userId;

  if (!userId) {
    return reply.status(401).send({ error: 'Authentication required' });
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { subscriptionTier: true, subscriptionExpiresAt: true },
  });

  if (!user) {
    return reply.status(404).send({ error: 'User not found' });
  }

  const isPro = user.subscriptionTier !== 'FREE' && 
    (!user.subscriptionExpiresAt || user.subscriptionExpiresAt > new Date());

  (request as any).isPro = isPro;
  (request as any).subscriptionTier = user.subscriptionTier;
}

export const FREE_TIER_LIMITS = {
  maxProjects: 3,
  maxPhotosPerProject: 100,
} as const;
