# LifeOS - System Architecture (Part 5)
## Real-Time Systems, Security, and Infrastructure

---

## 8. API DESIGN (Continued)

#### 8.3.1 GraphQL Schema (Continued)

```graphql
type Query {
  # Analytics
  analytics: Analytics!
  productivityMetrics(
    startDate: Date!
    endDate: Date!
  ): ProductivityMetrics!
  
  # AI
  dailyBriefing: String!
  aiInsights: AIInsights!
}

type Mutation {
  # Auth
  signup(input: SignupInput!): AuthPayload!
  login(input: LoginInput!): AuthPayload!
  logout: Boolean!
  
  # Tasks
  createTask(input: CreateTaskInput!): Task!
  updateTask(id: ID!, input: UpdateTaskInput!): Task!
  deleteTask(id: ID!): Boolean!
  completeTask(id: ID!): Task!
  
  # Goals
  createGoal(input: CreateGoalInput!): Goal!
  updateGoal(id: ID!, input: UpdateGoalInput!): Goal!
  deleteGoal(id: ID!): Boolean!
  completeGoal(id: ID!): Goal!
  
  # Habits
  createHabit(input: CreateHabitInput!): Habit!
  updateHabit(id: ID!, input: UpdateHabitInput!): Habit!
  deleteHabit(id: ID!): Boolean!
  completeHabit(id: ID!, date: Date!): HabitCompletion!
  
  # AI
  chatWithAI(message: String!, context: ChatContext): String!
  parseNaturalLanguageTask(text: String!): Task!
}

type Subscription {
  # Real-time updates
  taskUpdated(userId: ID!): Task!
  goalProgressUpdated(userId: ID!): Goal!
  habitCompleted(userId: ID!): HabitCompletion!
  notificationReceived(userId: ID!): Notification!
}

# Input Types
input CreateTaskInput {
  title: String!
  description: String
  priority: Priority
  dueDate: DateTime
  estimatedMinutes: Int
  tags: [String!]
  projectId: ID
  goalId: ID
}

input UpdateTaskInput {
  title: String
  description: String
  status: TaskStatus
  priority: Priority
  dueDate: DateTime
  estimatedMinutes: Int
  actualMinutes: Int
  tags: [String!]
}

# Enums
enum TaskStatus {
  TODO
  IN_PROGRESS
  DONE
}

enum Priority {
  LOW
  MEDIUM
  HIGH
}

enum GoalStatus {
  ACTIVE
  COMPLETED
  ABANDONED
  PAUSED
}

enum SubscriptionTier {
  FREE
  PRO
  TEAM
  ENTERPRISE
}

# Scalars
scalar DateTime
scalar Date
scalar JSON
```

### 8.4 API Rate Limiting

```typescript
// src/middleware/rateLimit.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { redisClient } from '@/config/redis';

// Different rate limits for different tiers
const rateLimitConfig = {
  free: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // 100 requests per window
  },
  pro: {
    windowMs: 15 * 60 * 1000,
    max: 1000,
  },
  team: {
    windowMs: 15 * 60 * 1000,
    max: 5000,
  },
  enterprise: {
    windowMs: 15 * 60 * 1000,
    max: 10000,
  },
};

export const createRateLimiter = (tier: string = 'free') => {
  const config = rateLimitConfig[tier] || rateLimitConfig.free;
  
  return rateLimit({
    store: new RedisStore({
      client: redisClient,
      prefix: 'rate_limit:',
    }),
    windowMs: config.windowMs,
    max: config.max,
    message: {
      error: 'Too many requests, please try again later.',
      retryAfter: config.windowMs / 1000,
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      res.status(429).json({
        error: 'Rate limit exceeded',
        retryAfter: Math.ceil(config.windowMs / 1000),
        tier: tier,
        limit: config.max,
      });
    },
  });
};

// AI endpoint rate limiting (more restrictive)
export const aiRateLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'ai_rate_limit:',
  }),
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 AI requests per minute
  message: {
    error: 'AI rate limit exceeded. Please wait before making more requests.',
  },
});
```

### 8.5 API Versioning Strategy

```typescript
// API versioning through URL path
// /api/v1/tasks
// /api/v2/tasks

// Version detection middleware
export const apiVersion = (req: Request, res: Response, next: NextFunction) => {
  const version = req.path.split('/')[2]; // Extract v1, v2, etc.
  req.apiVersion = version;
  next();
};

// Deprecation warnings
export const deprecationWarning = (version: string, deprecatedIn: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (req.apiVersion === version) {
      res.setHeader('X-API-Deprecated', 'true');
      res.setHeader('X-API-Deprecated-In', deprecatedIn);
      res.setHeader('X-API-Sunset-Date', '2027-01-01');
    }
    next();
  };
};
```

---

## 9. AUTHENTICATION & AUTHORIZATION

### 9.1 JWT Token Strategy

```typescript
// src/services/tokenService.ts
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';

interface TokenPayload {
  userId: string;
  email: string;
  role: string;
  sessionId: string;
}

export class TokenService {
  private accessTokenSecret = process.env.ACCESS_TOKEN_SECRET!;
  private refreshTokenSecret = process.env.REFRESH_TOKEN_SECRET!;
  
  generateAccessToken(payload: TokenPayload): string {
    return jwt.sign(
      {
        ...payload,
        type: 'access',
        jti: uuidv4(), // JWT ID for token revocation
      },
      this.accessTokenSecret,
      {
        expiresIn: '15m',
        issuer: 'lifeos-api',
        audience: 'lifeos-client',
      }
    );
  }
  
  generateRefreshToken(payload: TokenPayload): string {
    return jwt.sign(
      {
        ...payload,
        type: 'refresh',
        jti: uuidv4(),
      },
      this.refreshTokenSecret,
      {
        expiresIn: '7d',
        issuer: 'lifeos-api',
        audience: 'lifeos-client',
      }
    );
  }
  
  verifyAccessToken(token: string): TokenPayload {
    try {
      const payload = jwt.verify(token, this.accessTokenSecret, {
        issuer: 'lifeos-api',
        audience: 'lifeos-client',
      }) as any;
      
      // Check if token is revoked
      if (this.isTokenRevoked(payload.jti)) {
        throw new Error('Token has been revoked');
      }
      
      return payload;
    } catch (error) {
      throw new Error('Invalid access token');
    }
  }
  
  verifyRefreshToken(token: string): TokenPayload {
    try {
      const payload = jwt.verify(token, this.refreshTokenSecret, {
        issuer: 'lifeos-api',
        audience: 'lifeos-client',
      }) as any;
      
      if (this.isTokenRevoked(payload.jti)) {
        throw new Error('Token has been revoked');
      }
      
      return payload;
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }
  
  async revokeToken(jti: string): Promise<void> {
    // Store revoked token ID in Redis with expiration
    await redisClient.setex(
      `revoked_token:${jti}`,
      7 * 24 * 60 * 60, // 7 days
      '1'
    );
  }
  
  async isTokenRevoked(jti: string): Promise<boolean> {
    const revoked = await redisClient.get(`revoked_token:${jti}`);
    return revoked === '1';
  }
}

export const tokenService = new TokenService();
```

### 9.2 Role-Based Access Control (RBAC)

```typescript
// src/models/Role.ts
export enum Role {
  USER = 'user',
  PRO_USER = 'pro_user',
  TEAM_ADMIN = 'team_admin',
  ENTERPRISE_ADMIN = 'enterprise_admin',
  SUPER_ADMIN = 'super_admin',
}

export enum Permission {
  // Task permissions
  TASK_CREATE = 'task:create',
  TASK_READ = 'task:read',
  TASK_UPDATE = 'task:update',
  TASK_DELETE = 'task:delete',
  
  // Goal permissions
  GOAL_CREATE = 'goal:create',
  GOAL_READ = 'goal:read',
  GOAL_UPDATE = 'goal:update',
  GOAL_DELETE = 'goal:delete',
  
  // Team permissions
  TEAM_CREATE = 'team:create',
  TEAM_MANAGE = 'team:manage',
  TEAM_INVITE = 'team:invite',
  
  // Admin permissions
  USER_MANAGE = 'user:manage',
  ANALYTICS_VIEW = 'analytics:view',
  SETTINGS_MANAGE = 'settings:manage',
}

// Role-Permission mapping
export const rolePermissions: Record<Role, Permission[]> = {
  [Role.USER]: [
    Permission.TASK_CREATE,
    Permission.TASK_READ,
    Permission.TASK_UPDATE,
    Permission.TASK_DELETE,
    Permission.GOAL_CREATE,
    Permission.GOAL_READ,
    Permission.GOAL_UPDATE,
    Permission.GOAL_DELETE,
  ],
  [Role.PRO_USER]: [
    ...rolePermissions[Role.USER],
    Permission.ANALYTICS_VIEW,
  ],
  [Role.TEAM_ADMIN]: [
    ...rolePermissions[Role.PRO_USER],
    Permission.TEAM_CREATE,
    Permission.TEAM_MANAGE,
    Permission.TEAM_INVITE,
  ],
  [Role.ENTERPRISE_ADMIN]: [
    ...rolePermissions[Role.TEAM_ADMIN],
    Permission.USER_MANAGE,
    Permission.SETTINGS_MANAGE,
  ],
  [Role.SUPER_ADMIN]: Object.values(Permission),
};

// Authorization middleware
export const requirePermission = (...permissions: Permission[]) => {
  return async (req: AuthRequest, res: Response, next: NextFunction) => {
    const user = await User.findByPk(req.userId);
    
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    const userPermissions = rolePermissions[user.role as Role] || [];
    const hasPermission = permissions.every(p => userPermissions.includes(p));
    
    if (!hasPermission) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You do not have permission to perform this action',
        required: permissions,
      });
    }
    
    next();
  };
};
```

### 9.3 OAuth 2.0 Integration

```typescript
// src/services/oauthService.ts
import { OAuth2Client } from 'google-auth-library';
import axios from 'axios';

export class OAuthService {
  private googleClient: OAuth2Client;
  
  constructor() {
    this.googleClient = new OAuth2Client(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );
  }
  
  // Google OAuth
  async verifyGoogleToken(token: string) {
    const ticket = await this.googleClient.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    
    const payload = ticket.getPayload();
    
    return {
      id: payload!.sub,
      email: payload!.email,
      name: payload!.name,
      picture: payload!.picture,
      emailVerified: payload!.email_verified,
    };
  }
  
  getGoogleAuthUrl(): string {
    return this.googleClient.generateAuthUrl({
      access_type: 'offline',
      scope: [
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/gmail.readonly',
      ],
      prompt: 'consent',
    });
  }
  
  async getGoogleTokens(code: string) {
    const { tokens } = await this.googleClient.getToken(code);
    return tokens;
  }
  
  // Apple OAuth
  async verifyAppleToken(token: string) {
    // Verify Apple ID token
    const response = await axios.get('https://appleid.apple.com/auth/keys');
    const keys = response.data.keys;
    
    // JWT verification logic with Apple's public keys
    // ... implementation details
    
    return {
      id: 'apple_user_id',
      email: 'user@example.com',
      name: 'User Name',
    };
  }
}

export const oauthService = new OAuthService();
```

---

## 10. REAL-TIME SYSTEMS

### 10.1 WebSocket Architecture

```typescript
// src/services/websocketService.ts
import { Server as SocketIOServer } from 'socket.io';
import { Server as HTTPServer } from 'http';
import { tokenService } from './tokenService';
import { redisClient } from '@/config/redis';

export class WebSocketService {
  private io: SocketIOServer;
  
  constructor(httpServer: HTTPServer) {
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: process.env.FRONTEND_URL,
        credentials: true,
      },
      transports: ['websocket', 'polling'],
    });
    
    this.setupMiddleware();
    this.setupEventHandlers();
  }
  
  private setupMiddleware() {
    // Authentication middleware
    this.io.use(async (socket, next) => {
      try {
        const token = socket.handshake.auth.token;
        const payload = tokenService.verifyAccessToken(token);
        
        socket.data.userId = payload.userId;
        socket.data.email = payload.email;
        
        next();
      } catch (error) {
        next(new Error('Authentication failed'));
      }
    });
  }
  
  private setupEventHandlers() {
    this.io.on('connection', (socket) => {
      const userId = socket.data.userId;
      
      console.log(`User connected: ${userId}`);
      
      // Join user's personal room
      socket.join(`user:${userId}`);
      
      // Track active users
      this.trackActiveUser(userId);
      
      // Handle task updates
      socket.on('task:update', async (data) => {
        // Broadcast to user's other devices
        socket.to(`user:${userId}`).emit('task:updated', data);
        
        // Publish to Redis for other server instances
        await redisClient.publish('task_updates', JSON.stringify({
          userId,
          taskId: data.taskId,
          action: 'updated',
        }));
      });
      
      // Handle goal updates
      socket.on('goal:update', async (data) => {
        socket.to(`user:${userId}`).emit('goal:updated', data);
        
        await redisClient.publish('goal_updates', JSON.stringify({
          userId,
          goalId: data.goalId,
          progress: data.progress,
        }));
      });
      
      // Handle habit completion
      socket.on('habit:complete', async (data) => {
        socket.to(`user:${userId}`).emit('habit:completed', data);
        
        await redisClient.publish('habit_completions', JSON.stringify({
          userId,
          habitId: data.habitId,
          date: data.date,
        }));
      });
      
      // Handle typing indicators for AI chat
      socket.on('ai:typing', () => {
        socket.to(`user:${userId}`).emit('ai:typing');
      });
      
      // Handle disconnection
      socket.on('disconnect', () => {
        console.log(`User disconnected: ${userId}`);
        this.removeActiveUser(userId);
      });
    });
    
    // Subscribe to Redis pub/sub for cross-server communication
    this.subscribeToRedis();
  }
  
  private async trackActiveUser(userId: string) {
    await redisClient.sadd('active_users', userId);
    await redisClient.expire(`active_user:${userId}`, 300); // 5 minutes
  }
  
  private async removeActiveUser(userId: string) {
    await redisClient.srem('active_users', userId);
  }
  
  private subscribeToRedis() {
    const subscriber = redisClient.duplicate();
    
    subscriber.subscribe('task_updates', 'goal_updates', 'habit_completions');
    
    subscriber.on('message', (channel, message) => {
      const data = JSON.parse(message);
      
      switch (channel) {
        case 'task_updates':
          this.io.to(`user:${data.userId}`).emit('task:updated', data);
          break;
        case 'goal_updates':
          this.io.to(`user:${data.userId}`).emit('goal:updated', data);
          break;
        case 'habit_completions':
          this.io.to(`user:${data.userId}`).emit('habit:completed', data);
          break;
      }
    });
  }
  
  // Broadcast to specific user
  public emitToUser(userId: string, event: string, data: any) {
    this.io.to(`user:${userId}`).emit(event, data);
  }
  
  // Broadcast to all users
  public broadcast(event: string, data: any) {
    this.io.emit(event, data);
  }
}
```

### 10.2 Server-Sent Events (SSE) for AI Streaming

```typescript
// src/controllers/aiController.ts
import { Response } from 'express';
import { AuthRequest } from '@/middleware/authenticate';
import { llmService } from '@/services/llmService';

export class AIController {
  async streamChat(req: AuthRequest, res: Response) {
    const { message, context } = req.body;
    const userId = req.userId!;
    
    // Set up SSE
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    
    try {
      // Stream AI response
      const stream = await llmService.streamChat(message, {
        userId,
        ...context,
      });
      
      for await (const chunk of stream) {
        res.write(`data: ${JSON.stringify({ type: 'content', delta: chunk })}\n\n`);
      }
      
      res.write(`data: ${JSON.stringify({ type: 'end' })}\n\n`);
      res.end();
    } catch (error) {
      res.write(`data: ${JSON.stringify({ type: 'error', message: error.message })}\n\n`);
      res.end();
    }
  }
}
```

---

## 11. INTEGRATION ARCHITECTURE

### 11.1 Google Calendar Integration

```typescript
// src/services/integrations/googleCalendarService.ts
import { google } from 'googleapis';
import { Integration } from '@/models/Integration';
import { CalendarEvent } from '@/models/CalendarEvent';

export class GoogleCalendarService {
  async syncCalendar(userId: string) {
    // Get user's Google integration
    const integration = await Integration.findOne({
      where: { userId, provider: 'google', type: 'calendar' },
    });
    
    if (!integration) {
      throw new Error('Google Calendar not connected');
    }
    
    // Set up OAuth2 client
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET
    );
    
    oauth2Client.setCredentials({
      access_token: integration.accessToken,
      refresh_token: integration.refreshToken,
    });
    
    const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
    
    try {
      // Fetch events from Google Calendar
      const response = await calendar.events.list({
        calendarId: 'primary',
        timeMin: new Date().toISOString(),
        maxResults: 100,
        singleEvents: true,
        orderBy: 'startTime',
      });
      
      const events = response.data.items || [];
      
      // Sync events to our database
      for (const event of events) {
        await this.syncEvent(userId, event);
      }
      
      // Update last sync time
      await integration.update({
        lastSyncAt: new Date(),
        lastSyncStatus: 'success',
      });
      
      return { synced: events.length };
    } catch (error) {
      await integration.update({
        lastSyncStatus: 'error',
        lastError: error.message,
      });
      
      throw error;
    }
  }
  
  private async syncEvent(userId: string, googleEvent: any) {
    // Check if event already exists
    let event = await CalendarEvent.findOne({
      where: {
        userId,
        externalEventId: googleEvent.id,
        externalProvider: 'google',
      },
    });
    
    const eventData = {
      title: googleEvent.summary,
      description: googleEvent.description,
      location: googleEvent.location,
      startTime: new Date(googleEvent.start.dateTime || googleEvent.start.date),
      endTime: new Date(googleEvent.end.dateTime || googleEvent.end.date),
      allDay: !googleEvent.start.dateTime,
      externalCalendarId: googleEvent.organizer.email,
      externalEventId: googleEvent.id,
      externalProvider: 'google',
    };
    
    if (event) {
      // Update existing event
      await event.update(eventData);
    } else {
      // Create new event
      event = await CalendarEvent.create({
        ...eventData,
        userId,
      });
    }
    
    return event;
  }
  
  async createEvent(userId: string, eventData: any) {
    const integration = await Integration.findOne({
      where: { userId, provider: 'google', type: 'calendar' },
    });
    
    if (!integration) {
      throw new Error('Google Calendar not connected');
    }
    
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET
    );
    
    oauth2Client.setCredentials({
      access_token: integration.accessToken,
      refresh_token: integration.refreshToken,
    });
    
    const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
    
    const event = {
      summary: eventData.title,
      description: eventData.description,
      location: eventData.location,
      start: {
        dateTime: eventData.startTime,
        timeZone: eventData.timezone || 'UTC',
      },
      end: {
        dateTime: eventData.endTime,
        timeZone: eventData.timezone || 'UTC',
      },
    };
    
    const response = await calendar.events.insert({
      calendarId: 'primary',
      requestBody: event,
    });
    
    return response.data;
  }
}

export const googleCalendarService = new GoogleCalendarService();
```

### 11.2 Slack Integration

```typescript
// src/services/integrations/slackService.ts
import { WebClient } from '@slack/web-api';
import { Integration } from '@/models/Integration';

export class SlackService {
  async sendNotification(userId: string, message: string) {
    const integration = await Integration.findOne({
      where: { userId, provider: 'slack' },
    });
    
    if (!integration) {
      return; // Slack not connected, skip
    }
    
    const client = new WebClient(integration.accessToken);
    
    try {
      await client.chat.postMessage({
        channel: integration.config.channelId,
        text: message,
        blocks: [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: message,
            },
          },
        ],
      });
    } catch (error) {
      console.error('Failed to send Slack notification:', error);
    }
  }
  
  async createTaskFromMessage(userId: string, messageId: string) {
    const integration = await Integration.findOne({
      where: { userId, provider: 'slack' },
    });
    
    if (!integration) {
      throw new Error('Slack not connected');
    }
    
    const client = new WebClient(integration.accessToken);
    
    // Get message content
    const response = await client.conversations.history({
      channel: integration.config.channelId,
      latest: messageId,
      limit: 1,
      inclusive: true,
    });
    
    const message = response.messages?.[0];
    
    if (!message) {
      throw new Error('Message not found');
    }
    
    // Create task from message
    const task = await taskService.create(userId, {
      title: message.text,
      description: `From Slack: ${message.text}`,
      tags: ['slack'],
    });
    
    // React to message with checkmark
    await client.reactions.add({
      channel: integration.config.channelId,
      timestamp: message.ts,
      name: 'white_check_mark',
    });
    
    return task;
  }
}

export const slackService = new SlackService();
```

---

## 12. INFRASTRUCTURE & DEVOPS

### 12.1 Docker Configuration

```dockerfile
# Dockerfile for Node.js services
FROM node:18-alpine AS base

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Production image
FROM node:18-alpine

WORKDIR /app

COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/dist ./dist
COPY --from=base /app/package.json ./

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

```dockerfile
# Dockerfile for Python AI service
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

EXPOSE 3007

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3007"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  # API Gateway
  api-gateway:
    build: ./api-gateway
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
    depends_on:
      - postgres
      - redis
  
  # Auth Service
  auth-service:
    build: ./auth-service
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - ACCESS_TOKEN_SECRET=${ACCESS_TOKEN_SECRET}
      - REFRESH_TOKEN_SECRET=${REFRESH_TOKEN_SECRET}
    depends_on:
      - postgres
      - redis
  
  # Task Service
  task-service:
    build: ./task-service
    ports:
      - "3003:3003"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
    depends_on:
      - postgres
      - redis
  
  # AI Service
  ai-service:
    build: ./ai-service
    ports:
      - "3007:3007"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - DATABASE_URL=${DATABASE_URL}
      - PINECONE_API_KEY=${PINECONE_API_KEY}
    depends_on:
      - postgres
  
  # PostgreSQL
  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=lifeos
      - POSTGRES_USER=lifeos
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  # Redis
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
  
  # MongoDB
  mongodb:
    image: mongo:6
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_ROOT_USERNAME=lifeos
      - MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}
    volumes:
      - mongo_data:/data/db
  
  # Elasticsearch
  elasticsearch:
    image: elasticsearch:8.11.0
    ports:
      - "9200:9200"
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    volumes:
      - es_data:/usr/share/elasticsearch/data

volumes:
  postgres_data:
  redis_data:
  mongo_data:
  es_data:
```

### 12.2 Kubernetes Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: task-service
  namespace: li