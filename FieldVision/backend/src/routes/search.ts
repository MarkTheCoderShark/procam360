import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.js';

const searchQuerySchema = z.object({
  q: z.string().min(1).max(200),
  type: z.enum(['all', 'projects', 'photos']).default('all'),
  projectId: z.string().uuid().optional(),
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(50).default(20),
});

export async function searchRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const query = searchQuerySchema.parse(request.query);
    const prisma = (fastify as any).prisma;
    const userId = (request as any).userId;
    
    const searchTerm = query.q.toLowerCase();
    const skip = (query.page - 1) * query.limit;

    const userProjectIds = await prisma.projectMember.findMany({
      where: { userId },
      select: { projectId: true },
    });
    const projectIds = userProjectIds.map((p: any) => p.projectId);

    if (projectIds.length === 0) {
      return {
        projects: [],
        photos: [],
        query: query.q,
        page: query.page,
        limit: query.limit,
        totalProjects: 0,
        totalPhotos: 0,
      };
    }

    let projects: any[] = [];
    let photos: any[] = [];
    let totalProjects = 0;
    let totalPhotos = 0;

    if (query.type === 'all' || query.type === 'projects') {
      const projectWhere = {
        id: { in: projectIds },
        OR: [
          { name: { contains: searchTerm, mode: 'insensitive' as const } },
          { address: { contains: searchTerm, mode: 'insensitive' as const } },
          { clientName: { contains: searchTerm, mode: 'insensitive' as const } },
        ],
      };

      [projects, totalProjects] = await Promise.all([
        prisma.project.findMany({
          where: projectWhere,
          skip: query.type === 'projects' ? skip : 0,
          take: query.type === 'projects' ? query.limit : 5,
          orderBy: { updatedAt: 'desc' },
          include: {
            _count: { select: { photos: true, folders: true } },
          },
        }),
        prisma.project.count({ where: projectWhere }),
      ]);
    }

    if (query.type === 'all' || query.type === 'photos') {
      const photoProjectIds = query.projectId 
        ? [query.projectId].filter(id => projectIds.includes(id))
        : projectIds;

      if (photoProjectIds.length > 0) {
        const photoWhere = {
          projectId: { in: photoProjectIds },
          OR: [
            { note: { contains: searchTerm, mode: 'insensitive' as const } },
            { voiceNoteTranscription: { contains: searchTerm, mode: 'insensitive' as const } },
          ],
        };

        [photos, totalPhotos] = await Promise.all([
          prisma.photo.findMany({
            where: photoWhere,
            skip: query.type === 'photos' ? skip : 0,
            take: query.type === 'photos' ? query.limit : 10,
            orderBy: { capturedAt: 'desc' },
            include: {
              project: { select: { id: true, name: true } },
              uploader: { select: { id: true, name: true } },
              _count: { select: { comments: true } },
            },
          }),
          prisma.photo.count({ where: photoWhere }),
        ]);
      }
    }

    return {
      projects: projects.map((p: any) => ({
        id: p.id,
        name: p.name,
        address: p.address,
        clientName: p.clientName,
        status: p.status,
        photoCount: p._count.photos,
        folderCount: p._count.folders,
        updatedAt: p.updatedAt,
      })),
      photos: photos.map((p: any) => ({
        id: p.id,
        projectId: p.project.id,
        projectName: p.project.name,
        uploaderName: p.uploader.name,
        capturedAt: p.capturedAt,
        mediaType: p.mediaType,
        thumbnailUrl: p.thumbnailUrl,
        note: p.note,
        voiceNoteTranscription: p.voiceNoteTranscription,
        commentCount: p._count.comments,
      })),
      query: query.q,
      page: query.page,
      limit: query.limit,
      totalProjects,
      totalPhotos,
      hasMoreProjects: totalProjects > (query.type === 'projects' ? skip + projects.length : 5),
      hasMorePhotos: totalPhotos > (query.type === 'photos' ? skip + photos.length : 10),
    };
  });
}
