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
