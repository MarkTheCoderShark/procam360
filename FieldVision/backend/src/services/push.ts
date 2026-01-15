import { PrismaClient } from '@prisma/client';

interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export class PushService {
  private prisma: PrismaClient;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
  }

  async sendToUser(userId: string, payload: PushPayload): Promise<void> {
    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId },
    });

    const prefs = await this.prisma.notificationPreferences.findUnique({
      where: { userId },
    });

    if (!prefs) return;

    const notificationType = payload.data?.type;
    if (notificationType) {
      const shouldSend = this.checkPreferences(prefs, notificationType);
      if (!shouldSend) return;
    }

    for (const token of tokens) {
      if (token.platform === 'ios') {
        await this.sendAPNS(token.token, payload);
      }
    }
  }

  async sendToProjectMembers(
    projectId: string,
    payload: PushPayload,
    excludeUserId?: string
  ): Promise<void> {
    const members = await this.prisma.projectMember.findMany({
      where: { projectId },
      select: { userId: true },
    });

    const userIds = members
      .map((m) => m.userId)
      .filter((id) => id !== excludeUserId);

    for (const userId of userIds) {
      await this.sendToUser(userId, payload);
    }
  }

  private checkPreferences(
    prefs: { newPhotos: boolean; newComments: boolean; projectInvites: boolean; syncComplete: boolean },
    type: string
  ): boolean {
    switch (type) {
      case 'new_photo':
        return prefs.newPhotos;
      case 'new_comment':
        return prefs.newComments;
      case 'project_invite':
        return prefs.projectInvites;
      case 'sync_complete':
        return prefs.syncComplete;
      default:
        return true;
    }
  }

  private async sendAPNS(deviceToken: string, payload: PushPayload): Promise<void> {
    const apnsHost = process.env.APNS_HOST || 'api.sandbox.push.apple.com';
    const teamId = process.env.APPLE_TEAM_ID;
    const keyId = process.env.APNS_KEY_ID;
    const bundleId = process.env.IOS_BUNDLE_ID || 'com.fieldvision.app';

    if (!teamId || !keyId) {
      console.log('APNS not configured, skipping push notification');
      return;
    }

    const apnsPayload = {
      aps: {
        alert: {
          title: payload.title,
          body: payload.body,
        },
        sound: 'default',
        badge: 1,
      },
      ...payload.data,
    };

    try {
      const jwt = await this.generateAPNSToken(teamId, keyId);
      
      const response = await fetch(
        `https://${apnsHost}/3/device/${deviceToken}`,
        {
          method: 'POST',
          headers: {
            'authorization': `bearer ${jwt}`,
            'apns-topic': bundleId,
            'apns-push-type': 'alert',
            'apns-priority': '10',
            'content-type': 'application/json',
          },
          body: JSON.stringify(apnsPayload),
        }
      );

      if (!response.ok) {
        const error = await response.text();
        console.error('APNS error:', error);
        
        if (response.status === 410) {
          await this.prisma.deviceToken.delete({
            where: { token: deviceToken },
          });
        }
      }
    } catch (error) {
      console.error('Failed to send APNS notification:', error);
    }
  }

  private async generateAPNSToken(teamId: string, keyId: string): Promise<string> {
    const crypto = await import('crypto');
    const fs = await import('fs');
    const path = await import('path');

    const keyPath = process.env.APNS_KEY_PATH || path.join(process.cwd(), 'AuthKey.p8');
    
    let privateKey: string;
    try {
      privateKey = fs.readFileSync(keyPath, 'utf8');
    } catch {
      console.warn('APNS key file not found at:', keyPath);
      return '';
    }

    const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: keyId })).toString('base64url');
    const claims = Buffer.from(
      JSON.stringify({
        iss: teamId,
        iat: Math.floor(Date.now() / 1000),
      })
    ).toString('base64url');

    const signatureInput = `${header}.${claims}`;
    const sign = crypto.createSign('SHA256');
    sign.update(signatureInput);
    const signature = sign.sign(privateKey, 'base64url');

    return `${header}.${claims}.${signature}`;
  }
}

export function createPushService(prisma: PrismaClient): PushService {
  return new PushService(prisma);
}
