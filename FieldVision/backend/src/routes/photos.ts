import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { authenticate, checkSubscriptionLimits, requirePro, FREE_TIER_LIMITS } from '../middleware/auth.js';
import { getStorageService } from '../services/storage.js';
import { TranscriptionService } from '../services/transcription.js';

const createPhotoSchema = z.object({
  projectId: z.string().uuid(),
  folderId: z.string().uuid().optional(),
  capturedAt: z.string().datetime(),
  latitude: z.number(),
  longitude: z.number(),
  mediaType: z.enum(['PHOTO', 'VIDEO']).default('PHOTO'),
  remoteUrl: z.string().url(),
  thumbnailUrl: z.string().url().optional(),
  note: z.string().optional(),
});

const updatePhotoSchema = z.object({
  folderId: z.string().uuid().nullable().optional(),
  note: z.string().optional(),
});

export async function photoRoutes(fastify: FastifyInstance) {
  const storageService = getStorageService();
  const transcriptionService = new TranscriptionService();

  fastify.addHook('preHandler', authenticate);

  fastify.post('/', { preHandler: checkSubscriptionLimits }, async (request: FastifyRequest, reply: FastifyReply) => {
    const body = createPhotoSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;
    const isPro = (request as any).isPro;

    const member = await prisma.projectMember.findFirst({
      where: { projectId: body.projectId, userId },
    });

    if (!member || member.role === 'VIEWER') {
      return reply.status(403).send({ error: 'Not authorized to add photos to this project' });
    }

    if (!isPro) {
      const photoCount = await prisma.photo.count({
        where: { projectId: body.projectId },
      });

      if (photoCount >= FREE_TIER_LIMITS.maxPhotosPerProject) {
        return reply.status(403).send({
          error: `Free accounts are limited to ${FREE_TIER_LIMITS.maxPhotosPerProject} photos per project. Upgrade to Pro for unlimited photos.`,
          code: 'PHOTO_LIMIT_REACHED',
          limit: FREE_TIER_LIMITS.maxPhotosPerProject,
        });
      }
    }

    const photo = await prisma.photo.create({
      data: {
        ...body,
        capturedAt: new Date(body.capturedAt),
        uploaderId: userId,
      },
      include: {
        uploader: { select: { id: true, name: true } },
        _count: { select: { comments: true } },
      },
    });

    return {
      id: photo.id,
      uploaderId: photo.uploader.id,
      uploaderName: photo.uploader.name,
      capturedAt: photo.capturedAt,
      latitude: photo.latitude,
      longitude: photo.longitude,
      mediaType: photo.mediaType,
      remoteUrl: photo.remoteUrl,
      thumbnailUrl: photo.thumbnailUrl,
      note: photo.note,
      voiceNoteUrl: photo.voiceNoteUrl,
      voiceNoteTranscription: photo.voiceNoteTranscription,
      folderId: photo.folderId,
      commentCount: photo._count.comments,
      createdAt: photo.createdAt,
      updatedAt: photo.updatedAt,
    };
  });

  fastify.get('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const photo = await prisma.photo.findUnique({
      where: { id },
      include: {
        project: { include: { members: true } },
        uploader: { select: { id: true, name: true, avatarUrl: true } },
        folder: { select: { id: true, name: true } },
        comments: {
          include: { user: { select: { id: true, name: true, avatarUrl: true } } },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!photo) {
      return reply.status(404).send({ error: 'Photo not found' });
    }

    const isMember = photo.project.members.some((m: any) => m.userId === userId);
    if (!isMember) {
      return reply.status(403).send({ error: 'Not authorized to view this photo' });
    }

    return {
      id: photo.id,
      uploaderId: photo.uploader.id,
      uploaderName: photo.uploader.name,
      uploaderAvatarUrl: photo.uploader.avatarUrl,
      capturedAt: photo.capturedAt,
      latitude: photo.latitude,
      longitude: photo.longitude,
      mediaType: photo.mediaType,
      remoteUrl: photo.remoteUrl,
      thumbnailUrl: photo.thumbnailUrl,
      note: photo.note,
      voiceNoteUrl: photo.voiceNoteUrl,
      voiceNoteTranscription: photo.voiceNoteTranscription,
      folder: photo.folder,
      comments: photo.comments.map((c: any) => ({
        id: c.id,
        userId: c.user.id,
        userName: c.user.name,
        userAvatarUrl: c.user.avatarUrl,
        text: c.text,
        createdAt: c.createdAt,
      })),
      createdAt: photo.createdAt,
      updatedAt: photo.updatedAt,
    };
  });

  fastify.patch('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const body = updatePhotoSchema.parse(request.body);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const photo = await prisma.photo.findUnique({
      where: { id },
      include: { project: { include: { members: true } } },
    });

    if (!photo) {
      return reply.status(404).send({ error: 'Photo not found' });
    }

    const member = photo.project.members.find((m: any) => m.userId === userId);
    if (!member || member.role === 'VIEWER') {
      return reply.status(403).send({ error: 'Not authorized to update this photo' });
    }

    const updated = await prisma.photo.update({
      where: { id },
      data: body,
    });

    return updated;
  });

  fastify.delete('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const photo = await prisma.photo.findUnique({
      where: { id },
      include: { project: { include: { members: true } } },
    });

    if (!photo) {
      return reply.status(404).send({ error: 'Photo not found' });
    }

    const member = photo.project.members.find((m: any) => m.userId === userId);
    if (!member || member.role === 'VIEWER') {
      return reply.status(403).send({ error: 'Not authorized to delete this photo' });
    }

    await prisma.photo.delete({ where: { id } });

    return { success: true };
  });

  fastify.post('/:id/comments', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const { text } = request.body as { text: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const photo = await prisma.photo.findUnique({
      where: { id },
      include: { project: { include: { members: true } } },
    });

    if (!photo) {
      return reply.status(404).send({ error: 'Photo not found' });
    }

    const isMember = photo.project.members.some((m: any) => m.userId === userId);
    if (!isMember) {
      return reply.status(403).send({ error: 'Not authorized to comment on this photo' });
    }

    const comment = await prisma.comment.create({
      data: {
        photoId: id,
        userId,
        text,
      },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });

    return {
      id: comment.id,
      userId: comment.user.id,
      userName: comment.user.name,
      userAvatarUrl: comment.user.avatarUrl,
      text: comment.text,
      createdAt: comment.createdAt,
    };
  });

  fastify.post('/:id/voice-note', { preHandler: requirePro }, async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const photo = await prisma.photo.findUnique({
      where: { id },
      include: { project: { include: { members: true } } },
    });

    if (!photo) {
      return reply.status(404).send({ error: 'Photo not found' });
    }

    const member = photo.project.members.find((m: any) => m.userId === userId);
    if (!member || member.role === 'VIEWER') {
      return reply.status(403).send({ error: 'Not authorized to add voice notes' });
    }

    const data = await request.file();
    if (!data) {
      return reply.status(400).send({ error: 'No audio file provided' });
    }

    const buffer = await data.toBuffer();
    const fileName = `${id}-${Date.now()}.m4a`;
    const uploadResult = await storageService.uploadFile(buffer, fileName, 'audio/m4a', 'voice-notes');

    const transcription = await transcriptionService.transcribe(buffer);

    const updated = await prisma.photo.update({
      where: { id },
      data: {
        voiceNoteUrl: uploadResult.url,
        voiceNoteTranscription: transcription,
      },
    });

    return {
      transcription: updated.voiceNoteTranscription,
      voiceNoteUrl: updated.voiceNoteUrl,
    };
  });

  fastify.post('/upload-url', async (request: FastifyRequest, reply: FastifyReply) => {
    const { projectId, filename, contentType } = request.body as {
      projectId: string;
      filename: string;
      contentType: string;
    };

    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;

    const member = await prisma.projectMember.findFirst({
      where: { projectId, userId },
    });

    if (!member || member.role === 'VIEWER') {
      return reply.status(403).send({ error: 'Not authorized to upload to this project' });
    }

    const photoUpload = await storageService.getSignedUploadUrl(
      filename,
      `projects/${projectId}/photos`
    );

    const thumbnailUpload = await storageService.getSignedUploadUrl(
      `thumb-${filename}`,
      `projects/${projectId}/thumbnails`
    );

    return {
      uploadUrl: photoUpload.signedUrl,
      mediaUrl: photoUpload.publicUrl,
      thumbnailUploadUrl: thumbnailUpload.signedUrl,
      thumbnailUrl: thumbnailUpload.publicUrl,
    };
  });
}
