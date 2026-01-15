import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import { authenticate } from '../middleware/auth.js';
import crypto from 'crypto';

const createShareLinkSchema = z.object({
  folderIds: z.array(z.string().uuid()).optional(),
  dateRangeStart: z.string().datetime().optional(),
  dateRangeEnd: z.string().datetime().optional(),
  expiresAt: z.string().datetime().optional(),
  password: z.string().optional(),
  allowDownload: z.boolean().default(false),
  allowComments: z.boolean().default(false),
});

export async function shareRoutes(fastify: FastifyInstance) {
  fastify.post('/:projectId', { preHandler: authenticate }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { projectId } = request.params as { projectId: string };
    const body = createShareLinkSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId, userId, role: 'ADMIN' },
    });

    if (!member) {
      return reply.status(403).send({ error: 'Only admins can create share links' });
    }

    const token = crypto.randomBytes(32).toString('hex');
    const passwordHash = body.password ? await bcrypt.hash(body.password, 12) : null;

    const shareLink = await prisma.shareLink.create({
      data: {
        projectId,
        createdById: userId,
        token,
        folderIds: body.folderIds || [],
        dateRangeStart: body.dateRangeStart ? new Date(body.dateRangeStart) : null,
        dateRangeEnd: body.dateRangeEnd ? new Date(body.dateRangeEnd) : null,
        expiresAt: body.expiresAt ? new Date(body.expiresAt) : null,
        passwordHash,
        allowDownload: body.allowDownload,
        allowComments: body.allowComments,
      },
    });

    const baseUrl = process.env.WEB_URL || 'https://fieldvision.app';

    return {
      id: shareLink.id,
      token: shareLink.token,
      shareUrl: `${baseUrl}/share/${shareLink.token}`,
      folderIds: shareLink.folderIds,
      dateRangeStart: shareLink.dateRangeStart,
      dateRangeEnd: shareLink.dateRangeEnd,
      expiresAt: shareLink.expiresAt,
      passwordProtected: !!shareLink.passwordHash,
      allowDownload: shareLink.allowDownload,
      allowComments: shareLink.allowComments,
      isActive: shareLink.isActive,
      createdAt: shareLink.createdAt,
    };
  });

  fastify.get('/:token', async (request: FastifyRequest, reply: FastifyReply) => {
    const { token } = request.params as { token: string };
    const password = request.headers['x-share-password'] as string | undefined;
    const prisma = (fastify as any).prisma;

    const shareLink = await prisma.shareLink.findUnique({
      where: { token },
      include: {
        project: {
          select: {
            id: true,
            name: true,
            address: true,
            latitude: true,
            longitude: true,
            folders: {
              select: {
                id: true,
                name: true,
                _count: { select: { photos: true } },
              },
            },
          },
        },
      },
    });

    if (!shareLink) {
      return reply.status(404).send({ error: 'Share link not found' });
    }

    if (!shareLink.isActive) {
      return reply.status(410).send({ error: 'This share link has been disabled' });
    }

    if (shareLink.expiresAt && shareLink.expiresAt < new Date()) {
      return reply.status(410).send({ error: 'This share link has expired' });
    }

    if (shareLink.passwordHash) {
      if (!password) {
        return reply.status(401).send({ error: 'Password required', passwordRequired: true });
      }

      const validPassword = await bcrypt.compare(password, shareLink.passwordHash);
      if (!validPassword) {
        return reply.status(401).send({ error: 'Invalid password' });
      }
    }

    await prisma.shareLink.update({
      where: { id: shareLink.id },
      data: {
        accessCount: { increment: 1 },
        lastAccessedAt: new Date(),
      },
    });

    const photoWhere: any = { projectId: shareLink.projectId };
    if (shareLink.folderIds.length > 0) {
      photoWhere.folderId = { in: shareLink.folderIds };
    }
    if (shareLink.dateRangeStart) {
      photoWhere.capturedAt = { ...photoWhere.capturedAt, gte: shareLink.dateRangeStart };
    }
    if (shareLink.dateRangeEnd) {
      photoWhere.capturedAt = { ...photoWhere.capturedAt, lte: shareLink.dateRangeEnd };
    }

    const photos = await prisma.photo.findMany({
      where: photoWhere,
      orderBy: { capturedAt: 'desc' },
      select: {
        id: true,
        remoteUrl: true,
        thumbnailUrl: true,
        capturedAt: true,
        latitude: true,
        longitude: true,
        note: true,
        folderId: true,
        comments: {
          select: {
            id: true,
            text: true,
            createdAt: true,
            user: { select: { name: true } },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    const folders = shareLink.folderIds.length > 0
      ? shareLink.project.folders.filter((f: any) => shareLink.folderIds.includes(f.id))
      : shareLink.project.folders;

    return {
      id: shareLink.project.id,
      name: shareLink.project.name,
      address: shareLink.project.address,
      photos: photos.map((p: any) => ({
        ...p,
        comments: p.comments.map((c: any) => ({
          id: c.id,
          text: c.text,
          userName: c.user.name,
          createdAt: c.createdAt,
        })),
      })),
      folders: folders.map((f: any) => ({
        id: f.id,
        name: f.name,
        photoCount: f._count?.photos || 0,
      })),
      allowDownload: shareLink.allowDownload,
      allowComments: shareLink.allowComments,
    };
  });

  fastify.get('/:token/photos', async (request: FastifyRequest, reply: FastifyReply) => {
    const { token } = request.params as { token: string };
    const { page = '1', limit = '50', password } = request.query as any;
    const prisma = (fastify as any).prisma;

    const shareLink = await prisma.shareLink.findUnique({
      where: { token },
    });

    if (!shareLink || !shareLink.isActive) {
      return reply.status(404).send({ error: 'Share link not found or disabled' });
    }

    if (shareLink.expiresAt && shareLink.expiresAt < new Date()) {
      return reply.status(410).send({ error: 'This share link has expired' });
    }

    if (shareLink.passwordHash) {
      if (!password) {
        return reply.status(401).send({ error: 'Password required' });
      }

      const validPassword = await bcrypt.compare(password, shareLink.passwordHash);
      if (!validPassword) {
        return reply.status(401).send({ error: 'Invalid password' });
      }
    }

    const where: any = { projectId: shareLink.projectId };

    if (shareLink.folderIds.length > 0) {
      where.folderId = { in: shareLink.folderIds };
    }

    if (shareLink.dateRangeStart) {
      where.capturedAt = { ...where.capturedAt, gte: shareLink.dateRangeStart };
    }

    if (shareLink.dateRangeEnd) {
      where.capturedAt = { ...where.capturedAt, lte: shareLink.dateRangeEnd };
    }

    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const skip = (pageNum - 1) * limitNum;

    const [photos, total] = await Promise.all([
      prisma.photo.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: { capturedAt: 'desc' },
        select: {
          id: true,
          capturedAt: true,
          latitude: true,
          longitude: true,
          mediaType: true,
          remoteUrl: shareLink.allowDownload,
          thumbnailUrl: true,
          note: true,
          folder: { select: { id: true, name: true } },
        },
      }),
      prisma.photo.count({ where }),
    ]);

    return {
      data: photos,
      page: pageNum,
      limit: limitNum,
      total,
      hasMore: skip + photos.length < total,
    };
  });

  fastify.post('/:token/comments', async (request: FastifyRequest, reply: FastifyReply) => {
    const { token } = request.params as { token: string };
    const { photoId, text, guestName } = request.body as { photoId: string; text: string; guestName: string };
    const prisma = (fastify as any).prisma;

    const shareLink = await prisma.shareLink.findUnique({
      where: { token },
    });

    if (!shareLink || !shareLink.isActive) {
      return reply.status(404).send({ error: 'Share link not found' });
    }

    if (!shareLink.allowComments) {
      return reply.status(403).send({ error: 'Comments are not allowed on this share link' });
    }

    if (shareLink.expiresAt && shareLink.expiresAt < new Date()) {
      return reply.status(410).send({ error: 'This share link has expired' });
    }

    const photo = await prisma.photo.findFirst({
      where: { id: photoId, projectId: shareLink.projectId },
    });

    if (!photo) {
      return reply.status(404).send({ error: 'Photo not found' });
    }

    let guestUser = await prisma.user.findFirst({
      where: { email: `guest-${shareLink.id}@fieldvision.guest` },
    });

    if (!guestUser) {
      guestUser = await prisma.user.create({
        data: {
          email: `guest-${shareLink.id}@fieldvision.guest`,
          name: guestName || 'Guest',
        },
      });
    }

    const comment = await prisma.comment.create({
      data: {
        photoId,
        userId: guestUser.id,
        text,
      },
    });

    return {
      id: comment.id,
      text: comment.text,
      userName: guestName || 'Guest',
      createdAt: comment.createdAt,
    };
  });

  fastify.delete('/:projectId/links/:linkId', { preHandler: authenticate }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { projectId, linkId } = request.params as { projectId: string; linkId: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId, userId, role: 'ADMIN' },
    });

    if (!member) {
      return reply.status(403).send({ error: 'Only admins can delete share links' });
    }

    await prisma.shareLink.update({
      where: { id: linkId },
      data: { isActive: false },
    });

    return { success: true };
  });
}
