import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.js';

const createProjectSchema = z.object({
  name: z.string().min(1),
  address: z.string().min(1),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  clientName: z.string().optional(),
  status: z.enum(['WALKTHROUGH', 'IN_PROGRESS', 'COMPLETED']).default('WALKTHROUGH'),
});

const updateProjectSchema = z.object({
  name: z.string().min(1).optional(),
  address: z.string().min(1).optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  clientName: z.string().optional(),
  status: z.enum(['WALKTHROUGH', 'IN_PROGRESS', 'COMPLETED']).optional(),
});

const createFolderSchema = z.object({
  name: z.string().min(1),
  folderType: z.enum(['LOCATION', 'PHASE', 'CUSTOM']).default('CUSTOM'),
});

export async function projectRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const projects = await prisma.project.findMany({
      where: {
        members: {
          some: { userId },
        },
      },
      include: {
        _count: {
          select: { photos: true, folders: true },
        },
        folders: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    return projects.map((p: any) => ({
      id: p.id,
      name: p.name,
      address: p.address,
      latitude: p.latitude,
      longitude: p.longitude,
      clientName: p.clientName,
      status: p.status,
      photoCount: p._count.photos,
      folderCount: p._count.folders,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      folders: p.folders,
    }));
  });

  fastify.get('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const project = await prisma.project.findFirst({
      where: {
        id,
        members: { some: { userId } },
      },
      include: {
        _count: { select: { photos: true, folders: true } },
        folders: {
          orderBy: { sortOrder: 'asc' },
          include: { _count: { select: { photos: true } } },
        },
        members: {
          include: { user: { select: { id: true, name: true, email: true, avatarUrl: true } } },
        },
      },
    });

    if (!project) {
      return reply.status(404).send({ error: 'Project not found' });
    }

    return {
      id: project.id,
      name: project.name,
      address: project.address,
      latitude: project.latitude,
      longitude: project.longitude,
      clientName: project.clientName,
      status: project.status,
      photoCount: project._count.photos,
      folderCount: project._count.folders,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      folders: project.folders.map((f: any) => ({
        id: f.id,
        name: f.name,
        folderType: f.folderType,
        sortOrder: f.sortOrder,
        photoCount: f._count.photos,
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
      })),
      members: project.members.map((m: any) => ({
        id: m.user.id,
        name: m.user.name,
        email: m.user.email,
        avatarUrl: m.user.avatarUrl,
        role: m.role,
      })),
    };
  });

  fastify.post('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = createProjectSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const project = await prisma.project.create({
      data: {
        ...body,
        members: {
          create: {
            userId,
            role: 'ADMIN',
          },
        },
      },
      include: {
        _count: { select: { photos: true, folders: true } },
      },
    });

    return {
      id: project.id,
      name: project.name,
      address: project.address,
      latitude: project.latitude,
      longitude: project.longitude,
      clientName: project.clientName,
      status: project.status,
      photoCount: project._count.photos,
      folderCount: project._count.folders,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
    };
  });

  fastify.patch('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const body = updateProjectSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId: id, userId, role: 'ADMIN' },
    });

    if (!member) {
      return reply.status(403).send({ error: 'Not authorized to update this project' });
    }

    const project = await prisma.project.update({
      where: { id },
      data: body,
      include: { _count: { select: { photos: true, folders: true } } },
    });

    return {
      id: project.id,
      name: project.name,
      address: project.address,
      latitude: project.latitude,
      longitude: project.longitude,
      clientName: project.clientName,
      status: project.status,
      photoCount: project._count.photos,
      folderCount: project._count.folders,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
    };
  });

  fastify.delete('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId: id, userId, role: 'ADMIN' },
    });

    if (!member) {
      return reply.status(403).send({ error: 'Not authorized to delete this project' });
    }

    await prisma.project.delete({ where: { id } });

    return { success: true };
  });

  fastify.post('/:id/folders', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const body = createFolderSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId: id, userId },
    });

    if (!member) {
      return reply.status(403).send({ error: 'Not a member of this project' });
    }

    const folderCount = await prisma.folder.count({ where: { projectId: id } });

    const folder = await prisma.folder.create({
      data: {
        ...body,
        projectId: id,
        sortOrder: folderCount,
      },
      include: { _count: { select: { photos: true } } },
    });

    return {
      id: folder.id,
      name: folder.name,
      folderType: folder.folderType,
      sortOrder: folder.sortOrder,
      photoCount: folder._count.photos,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt,
    };
  });

  fastify.get('/:id/photos', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const { page = '1', limit = '50', folderId, startDate, endDate } = request.query as any;
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId: id, userId },
    });

    if (!member) {
      return reply.status(403).send({ error: 'Not a member of this project' });
    }

    const where: any = { projectId: id };
    if (folderId) where.folderId = folderId;
    if (startDate) where.capturedAt = { ...where.capturedAt, gte: new Date(startDate) };
    if (endDate) where.capturedAt = { ...where.capturedAt, lte: new Date(endDate) };

    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const skip = (pageNum - 1) * limitNum;

    const [photos, total] = await Promise.all([
      prisma.photo.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: { capturedAt: 'desc' },
        include: {
          uploader: { select: { id: true, name: true } },
          _count: { select: { comments: true } },
        },
      }),
      prisma.photo.count({ where }),
    ]);

    return {
      data: photos.map((p: any) => ({
        id: p.id,
        uploaderId: p.uploader.id,
        uploaderName: p.uploader.name,
        capturedAt: p.capturedAt,
        latitude: p.latitude,
        longitude: p.longitude,
        mediaType: p.mediaType,
        remoteUrl: p.remoteUrl,
        thumbnailUrl: p.thumbnailUrl,
        note: p.note,
        voiceNoteUrl: p.voiceNoteUrl,
        voiceNoteTranscription: p.voiceNoteTranscription,
        folderId: p.folderId,
        commentCount: p._count.comments,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      })),
      page: pageNum,
      limit: limitNum,
      total,
      hasMore: skip + photos.length < total,
    };
  });
}
