# LifeOS - System Architecture (Part 2)
## Backend, Database, and API Design

---

## 4. FRONTEND ARCHITECTURE (Continued)

#### 4.1.5 Routing Strategy (Continued)

```
app/
├── (auth)/
│   ├── login/page.tsx          # /login
│   ├── signup/page.tsx         # /signup
│   └── layout.tsx              # Auth layout (no sidebar)
├── (dashboard)/
│   ├── layout.tsx              # Dashboard layout (with sidebar)
│   ├── page.tsx                # /dashboard (home)
│   ├── tasks/
│   │   ├── page.tsx           # /dashboard/tasks
│   │   ├── [id]/page.tsx      # /dashboard/tasks/[id]
│   │   └── new/page.tsx       # /dashboard/tasks/new
│   ├── goals/
│   │   ├── page.tsx           # /dashboard/goals
│   │   └── [id]/page.tsx      # /dashboard/goals/[id]
│   ├── habits/
│   │   ├── page.tsx           # /dashboard/habits
│   │   └── [id]/page.tsx      # /dashboard/habits/[id]
│   ├── calendar/page.tsx      # /dashboard/calendar
│   ├── analytics/page.tsx     # /dashboard/analytics
│   └── settings/
│       ├── page.tsx           # /dashboard/settings
│       ├── profile/page.tsx   # /dashboard/settings/profile
│       └── integrations/page.tsx
└── api/                        # API routes
    ├── auth/
    │   ├── login/route.ts
    │   ├── signup/route.ts
    │   └── refresh/route.ts
    └── webhooks/
        ├── calendar/route.ts
        └── slack/route.ts
```

#### 4.1.6 Performance Optimization

**Code Splitting:**
```typescript
// Dynamic imports for heavy components
import dynamic from 'next/dynamic';

const CalendarView = dynamic(() => import('@/components/features/calendar/CalendarView'), {
  loading: () => <LoadingSpinner />,
  ssr: false, // Don't render on server
});

const AnalyticsDashboard = dynamic(() => import('@/components/features/analytics/Dashboard'), {
  loading: () => <LoadingSpinner />,
});
```

**Image Optimization:**
```typescript
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="Hero image"
  width={1200}
  height={600}
  priority // Load immediately
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>
```

**Caching Strategy:**
```typescript
// app/tasks/page.tsx
export const revalidate = 60; // Revalidate every 60 seconds

export default async function TasksPage() {
  const tasks = await fetch('https://api.lifeos.com/tasks', {
    next: { revalidate: 60 }
  });
  
  return <TaskList tasks={tasks} />;
}
```

### 4.2 Mobile Application (React Native)

#### 4.2.1 Project Structure

```
lifeos-mobile/
├── src/
│   ├── screens/              # Screen components
│   │   ├── Auth/
│   │   │   ├── LoginScreen.tsx
│   │   │   └── SignupScreen.tsx
│   │   ├── Tasks/
│   │   │   ├── TaskListScreen.tsx
│   │   │   └── TaskDetailScreen.tsx
│   │   ├── Goals/
│   │   ├── Habits/
│   │   └── Calendar/
│   ├── components/           # Reusable components
│   │   ├── ui/
│   │   └── features/
│   ├── navigation/           # Navigation setup
│   │   ├── AppNavigator.tsx
│   │   ├── AuthNavigator.tsx
│   │   └── TabNavigator.tsx
│   ├── services/            # API services
│   │   ├── api.ts
│   │   ├── auth.ts
│   │   └── storage.ts
│   ├── store/               # State management
│   │   ├── authStore.ts
│   │   └── taskStore.ts
│   ├── hooks/               # Custom hooks
│   ├── utils/               # Utilities
│   ├── types/               # TypeScript types
│   └── constants/           # Constants
├── assets/                  # Images, fonts
├── app.json                 # Expo config
├── package.json
└── tsconfig.json
```

#### 4.2.2 Navigation Setup

```typescript
// src/navigation/AppNavigator.tsx
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useAuthStore } from '@/store/authStore';
import AuthNavigator from './AuthNavigator';
import TabNavigator from './TabNavigator';

const Stack = createNativeStackNavigator();

export default function AppNavigator() {
  const { isAuthenticated } = useAuthStore();
  
  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {isAuthenticated ? (
          <Stack.Screen name="Main" component={TabNavigator} />
        ) : (
          <Stack.Screen name="Auth" component={AuthNavigator} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}
```

```typescript
// src/navigation/TabNavigator.tsx
import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Ionicons } from '@expo/vector-icons';
import TaskListScreen from '@/screens/Tasks/TaskListScreen';
import GoalsScreen from '@/screens/Goals/GoalsScreen';
import HabitsScreen from '@/screens/Habits/HabitsScreen';
import CalendarScreen from '@/screens/Calendar/CalendarScreen';
import ProfileScreen from '@/screens/Profile/ProfileScreen';

const Tab = createBottomTabNavigator();

export default function TabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName;
          
          if (route.name === 'Tasks') {
            iconName = focused ? 'checkmark-circle' : 'checkmark-circle-outline';
          } else if (route.name === 'Goals') {
            iconName = focused ? 'trophy' : 'trophy-outline';
          } else if (route.name === 'Habits') {
            iconName = focused ? 'flame' : 'flame-outline';
          } else if (route.name === 'Calendar') {
            iconName = focused ? 'calendar' : 'calendar-outline';
          } else if (route.name === 'Profile') {
            iconName = focused ? 'person' : 'person-outline';
          }
          
          return <Ionicons name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#6366f1',
        tabBarInactiveTintColor: 'gray',
      })}
    >
      <Tab.Screen name="Tasks" component={TaskListScreen} />
      <Tab.Screen name="Goals" component={GoalsScreen} />
      <Tab.Screen name="Habits" component={HabitsScreen} />
      <Tab.Screen name="Calendar" component={CalendarScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
}
```

#### 4.2.3 Offline Support

```typescript
// src/services/storage.ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';

class OfflineStorage {
  private pendingActions: any[] = [];
  
  async savePendingAction(action: any) {
    this.pendingActions.push(action);
    await AsyncStorage.setItem(
      'pending_actions',
      JSON.stringify(this.pendingActions)
    );
  }
  
  async syncPendingActions() {
    const isConnected = await NetInfo.fetch().then(state => state.isConnected);
    
    if (!isConnected) return;
    
    const actions = await AsyncStorage.getItem('pending_actions');
    if (!actions) return;
    
    this.pendingActions = JSON.parse(actions);
    
    for (const action of this.pendingActions) {
      try {
        await this.executeAction(action);
      } catch (error) {
        console.error('Failed to sync action:', error);
      }
    }
    
    this.pendingActions = [];
    await AsyncStorage.removeItem('pending_actions');
  }
  
  private async executeAction(action: any) {
    // Execute the pending action
    switch (action.type) {
      case 'CREATE_TASK':
        await api.tasks.create(action.payload);
        break;
      case 'UPDATE_TASK':
        await api.tasks.update(action.payload.id, action.payload.data);
        break;
      case 'DELETE_TASK':
        await api.tasks.delete(action.payload.id);
        break;
    }
  }
}

export const offlineStorage = new OfflineStorage();
```

---

## 5. BACKEND ARCHITECTURE

### 5.1 Microservices Overview

#### 5.1.1 Service Catalog

| Service | Port | Language | Database | Purpose |
|---------|------|----------|----------|---------|
| API Gateway | 3000 | Node.js | - | Request routing, rate limiting |
| Auth Service | 3001 | Node.js | PostgreSQL, Redis | Authentication, authorization |
| User Service | 3002 | Node.js | PostgreSQL | User profiles, preferences |
| Task Service | 3003 | Node.js | PostgreSQL | Task CRUD, prioritization |
| Goal Service | 3004 | Node.js | PostgreSQL | Goal tracking, progress |
| Habit Service | 3005 | Node.js | PostgreSQL | Habit tracking, streaks |
| Calendar Service | 3006 | Node.js | PostgreSQL | Calendar sync, events |
| AI Service | 3007 | Python | PostgreSQL, Vector DB | LLM integration, predictions |
| Notification Service | 3008 | Node.js | PostgreSQL, Redis | Push, email, SMS |
| Integration Service | 3009 | Node.js | MongoDB | Third-party integrations |
| Analytics Service | 3010 | Node.js | PostgreSQL, Elasticsearch | User analytics, insights |
| Search Service | 3011 | Node.js | Elasticsearch | Full-text search |
| Media Service | 3012 | Node.js | S3 | File uploads, processing |

#### 5.1.2 Service Communication

**Synchronous (REST):**
```
Client → API Gateway → Service
```

**Asynchronous (Message Queue):**
```
Service A → RabbitMQ → Service B
```

**Event-Driven:**
```
Service A publishes event → Event Bus → Service B subscribes
```

### 5.2 Auth Service

#### 5.2.1 Project Structure

```
auth-service/
├── src/
│   ├── controllers/
│   │   ├── authController.ts
│   │   └── userController.ts
│   ├── services/
│   │   ├── authService.ts
│   │   ├── tokenService.ts
│   │   └── passwordService.ts
│   ├── models/
│   │   └── User.ts
│   ├── middleware/
│   │   ├── authenticate.ts
│   │   ├── authorize.ts
│   │   └── rateLimit.ts
│   ├── routes/
│   │   └── authRoutes.ts
│   ├── utils/
│   │   ├── jwt.ts
│   │   └── validation.ts
│   ├── config/
│   │   ├── database.ts
│   │   └── redis.ts
│   └── index.ts
├── tests/
├── Dockerfile
├── package.json
└── tsconfig.json
```

#### 5.2.2 Authentication Flow

```typescript
// src/services/authService.ts
import bcrypt from 'bcrypt';
import { User } from '@/models/User';
import { tokenService } from './tokenService';
import { redisClient } from '@/config/redis';

export class AuthService {
  async signup(email: string, password: string, name: string) {
    // Check if user exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      throw new Error('User already exists');
    }
    
    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Create user
    const user = await User.create({
      email,
      password: hashedPassword,
      name,
    });
    
    // Generate tokens
    const accessToken = tokenService.generateAccessToken(user.id);
    const refreshToken = tokenService.generateRefreshToken(user.id);
    
    // Store refresh token in Redis
    await redisClient.set(
      `refresh_token:${user.id}`,
      refreshToken,
      'EX',
      7 * 24 * 60 * 60 // 7 days
    );
    
    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      accessToken,
      refreshToken,
    };
  }
  
  async login(email: string, password: string) {
    // Find user
    const user = await User.findOne({ where: { email } });
    if (!user) {
      throw new Error('Invalid credentials');
    }
    
    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      throw new Error('Invalid credentials');
    }
    
    // Generate tokens
    const accessToken = tokenService.generateAccessToken(user.id);
    const refreshToken = tokenService.generateRefreshToken(user.id);
    
    // Store refresh token
    await redisClient.set(
      `refresh_token:${user.id}`,
      refreshToken,
      'EX',
      7 * 24 * 60 * 60
    );
    
    // Update last login
    await user.update({ lastLoginAt: new Date() });
    
    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      accessToken,
      refreshToken,
    };
  }
  
  async refreshToken(refreshToken: string) {
    // Verify refresh token
    const payload = tokenService.verifyRefreshToken(refreshToken);
    
    // Check if token exists in Redis
    const storedToken = await redisClient.get(`refresh_token:${payload.userId}`);
    if (storedToken !== refreshToken) {
      throw new Error('Invalid refresh token');
    }
    
    // Generate new access token
    const accessToken = tokenService.generateAccessToken(payload.userId);
    
    return { accessToken };
  }
  
  async logout(userId: string) {
    // Remove refresh token from Redis
    await redisClient.del(`refresh_token:${userId}`);
  }
  
  async googleOAuth(googleToken: string) {
    // Verify Google token
    const googleUser = await this.verifyGoogleToken(googleToken);
    
    // Find or create user
    let user = await User.findOne({ where: { email: googleUser.email } });
    
    if (!user) {
      user = await User.create({
        email: googleUser.email,
        name: googleUser.name,
        googleId: googleUser.id,
        emailVerified: true,
      });
    }
    
    // Generate tokens
    const accessToken = tokenService.generateAccessToken(user.id);
    const refreshToken = tokenService.generateRefreshToken(user.id);
    
    await redisClient.set(
      `refresh_token:${user.id}`,
      refreshToken,
      'EX',
      7 * 24 * 60 * 60
    );
    
    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      accessToken,
      refreshToken,
    };
  }
  
  private async verifyGoogleToken(token: string) {
    // Verify with Google OAuth API
    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${token}`
    );
    const data = await response.json();
    
    if (data.error) {
      throw new Error('Invalid Google token');
    }
    
    return {
      id: data.sub,
      email: data.email,
      name: data.name,
    };
  }
}

export const authService = new AuthService();
```

```typescript
// src/services/tokenService.ts
import jwt from 'jsonwebtoken';

const ACCESS_TOKEN_SECRET = process.env.ACCESS_TOKEN_SECRET!;
const REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET!;
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY = '7d';

export class TokenService {
  generateAccessToken(userId: string): string {
    return jwt.sign(
      { userId, type: 'access' },
      ACCESS_TOKEN_SECRET,
      { expiresIn: ACCESS_TOKEN_EXPIRY }
    );
  }
  
  generateRefreshToken(userId: string): string {
    return jwt.sign(
      { userId, type: 'refresh' },
      REFRESH_TOKEN_SECRET,
      { expiresIn: REFRESH_TOKEN_EXPIRY }
    );
  }
  
  verifyAccessToken(token: string): { userId: string } {
    try {
      const payload = jwt.verify(token, ACCESS_TOKEN_SECRET) as any;
      return { userId: payload.userId };
    } catch (error) {
      throw new Error('Invalid access token');
    }
  }
  
  verifyRefreshToken(token: string): { userId: string } {
    try {
      const payload = jwt.verify(token, REFRESH_TOKEN_SECRET) as any;
      return { userId: payload.userId };
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }
}

export const tokenService = new TokenService();
```

#### 5.2.3 Authorization Middleware

```typescript
// src/middleware/authenticate.ts
import { Request, Response, NextFunction } from 'express';
import { tokenService } from '@/services/tokenService';

export interface AuthRequest extends Request {
  userId?: string;
}

export const authenticate = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }
    
    const token = authHeader.substring(7);
    const { userId } = tokenService.verifyAccessToken(token);
    
    req.userId = userId;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};
```

```typescript
// src/middleware/authorize.ts
import { Response, NextFunction } from 'express';
import { AuthRequest } from './authenticate';
import { User } from '@/models/User';

export const authorize = (...roles: string[]) => {
  return async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      const user = await User.findByPk(req.userId);
      
      if (!user) {
        return res.status(401).json({ error: 'User not found' });
      }
      
      if (!roles.includes(user.role)) {
        return res.status(403).json({ error: 'Insufficient permissions' });
      }
      
      next();
    } catch (error) {
      return res.status(500).json({ error: 'Authorization failed' });
    }
  };
};
```

### 5.3 Task Service

#### 5.3.1 Task Model

```typescript
// src/models/Task.ts
import { DataTypes, Model } from 'sequelize';
import { sequelize } from '@/config/database';

export interface TaskAttributes {
  id: string;
  userId: string;
  title: string;
  description: string | null;
  status: 'todo' | 'in_progress' | 'done';
  priority: 'low' | 'medium' | 'high';
  dueDate: Date | null;
  estimatedMinutes: number | null;
  actualMinutes: number | null;
  tags: string[];
  projectId: string | null;
  parentTaskId: string | null;
  order: number;
  createdAt: Date;
  updatedAt: Date;
  completedAt: Date | null;
}

export class Task extends Model<TaskAttributes> implements TaskAttributes {
  public id!: string;
  public userId!: string;
  public title!: string;
  public description!: string | null;
  public status!: 'todo' | 'in_progress' | 'done';
  public priority!: 'low' | 'medium' | 'high';
  public dueDate!: Date | null;
  public estimatedMinutes!: number | null;
  public actualMinutes!: number | null;
  public tags!: string[];
  public projectId!: string | null;
  public parentTaskId!: string | null;
  public order!: number;
  public createdAt!: Date;
  public updatedAt!: Date;
  public completedAt!: Date | null;
}

Task.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
    },
    title: {
      type: DataTypes.STRING(500),
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM('todo', 'in_progress', 'done'),
      defaultValue: 'todo',
    },
    priority: {
      type: DataTypes.ENUM('low', 'medium', 'high'),
      defaultValue: 'medium',
    },
    dueDate: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    estimatedMinutes: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    actualMinutes: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    tags: {
      type: DataTypes.ARRAY(DataTypes.STRING),
      defaultValue: [],
    },
    projectId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    parentTaskId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    order: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    completedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    tableName: 'tasks',
    indexes: [
      { fields: ['userId'] },
      { fields: ['status'] },
      { fields: ['priority'] },
      { fields: ['dueDate'] },
      { fields: ['projectId'] },
      { fields: ['userId', 'status'] },
      { fields: ['userId', 'dueDate'] },
    ],
  }
);
```

#### 5.3.2 Task Service Logic

```typescript
// src/services/taskService.ts
import { Task } from '@/models/Task';
import { Op } from 'sequelize';
import { eventBus } from '@/utils/eventBus';
import { aiService } from '@/services/aiService';

export class TaskService {
  async create(userId: string, data: Partial<TaskAttributes>) {
    // AI-powered time estimation
    if (!data.estimatedMinutes && data.title) {
      data.estimatedMinutes = await aiService.estimateTaskDuration(data.title);
    }
    
    // AI-powered priority suggestion
    if (!data.priority && data.title) {
      data.priority = await aiService.suggestPriority(data.title, data.dueDate);
    }
    
    const task = await Task.create({
      ...data,
      userId,
    });
    
    // Publish event
    eventBus.publish('task.created', { task });
    
    return task;
  }
  
  async getAll(userId: string, filters?: {
    status?: string;
    priority?: string;
    projectId?: string;
    search?: string;
  }) {
    const where: any = { userId };
    
    if (filters?.status) {
      where.status = filters.status;
    }
    
    if (filters?.priority) {
      where.priority = filters.priority;
    }
    
    if (filters?.projectId) {
      where.projectId = filters.projectId;
    }
    
    if (filters?.search) {
      where[Op.or] = [
        { title: { [Op.iLike]: `%${filters.search}%` } },
        { description: { [Op.iLike]: `%${filters.search}%` } },
      ];
    }
    
    const tasks = await Task.findAll({
      where,
      order: [
        ['order', 'ASC'],
        ['createdAt', 'DESC'],
      ],
    });
    
    return tasks;
  }
  
  async getById(userId: string, taskId: string) {
    const task = await Task.findOne({
      where: { id: taskId, userId },
    });
    
    if (!task) {
      throw new Error('Task not found');
    }
    
    return task;
  }
  
  async update(userId: string, taskId: string, data: Partial<TaskAttributes>) {
    const task = await this.getById(userId, taskId);
    
    await task.update(data);
    
    // Publish event
    eventBus.publish('task.updated', { task });
    
    return task;
  }
  
  async delete(userId: string, taskId: string) {
    const task = await this.getById(userId, taskId);
    
    await task.destroy();
    
    // Publish event
    eventBus.publish('task.deleted', { taskId });
  }
  
  async complete(userId: string, taskId: string) {
    const task = await this.getById(userId, taskId);
    
    await task.update({
      status: 'done',
      completedAt: new Date(),
    });
    
    // Publish event
    eventBus.publish('task.completed', { task });
    
    // Update goal progress if task is linked to a goal
    if (task.goalId) {
      eventBus.publish('goal.task_completed', {
        goalId: task.goalId,
        taskId: task.id,
      });
    }
    
    return task;
  }
  
  async getPrioritized(userId: string) {
    // Get all incomplete tasks
    const tasks = await Task.findAll({
      where: {
        userId,
        status: { [Op.ne]: 'done' },
      },
    });
    
    // AI-powered prioritization
    const prioritizedTasks = await aiService.prioritizeTasks(tasks);
    
    return prioritizedTasks;
  }
  
  async getUpcoming(userId: string, days: number = 7) {
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + days);
    
    const tasks = await Task.findAll({
      where: {
        userId,
        status: { [Op.ne]: 'done' },
        dueDate: {
          [Op.between]: [new Date(), endDate],
        },
      },
      order: [['dueDate', 'ASC']],
    });
    
    return tasks;
  }
  
  async getOverdue(userId: string) {
    const tasks = await Task.findAll({
      where: {
        userId,
        status: { [Op.ne]: 'done' },
        dueDate: {
          [Op.lt]: new Date(),
        },
      },
      order: [['dueDate', 'ASC']],
    });
    
    return tasks;
  }
}

export const taskService = new TaskService();
```

#### 5.3.3 Task Controller

```typescript
// src/controllers/taskController.ts
import { Response } from 'express';
import { AuthRequest } from '@/middleware/authenticate';
import { taskService } from '@/services/taskService';

export class TaskController {
  async create(req: AuthRequest, res: Response) {
    try {
      const task = await taskService.create(req.userId!, req.body);
      res.status(201).json(task);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
  
  async getAll(req: AuthRequest, res: Response) {
    try {
      const tasks = await taskService.getAll(req.userId!, req.query);
      res.json(tasks);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
  
  async getById(req: AuthRequest, res: Response) {
    try {
      const task = await taskService.getById(req.userId!, req.params.id);
      res.json(task);
    } catch (error) {
      res.status(404).json({ error: error.message });
    }
  }
  
  async update(req: AuthRequest, res: Response) {
    try {
      const task = await taskService.update(
        req.userId!,
        req.params.id,
        req.body
      );
      res.json(task);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
  
  async delete(req: AuthRequest, res: Response) {
    try {
      await taskService.delete(req.userId!, req.params.id);
      res.status(204).send();
    } catch (error) {
      res.status(404).json({ error: error.message });
    }
  }
  
  async complete(req: AuthRequest, res: Response) {
    try {
      const task = await taskService.complete(req.userId!, req.params.id);
      res.json(task);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
  
  async getPrioritized(req: AuthRequest, res: Response) {
    try {
      const tasks = await taskService.getPrioritized