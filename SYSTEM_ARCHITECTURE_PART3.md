# LifeOS - System Architecture (Part 3)
## Database Design, AI/ML, and Infrastructure

---

## 6. DATABASE DESIGN

### 6.1 Database Strategy

**Multi-Database Approach:**

1. **PostgreSQL** - Primary relational database
   - User data, tasks, goals, habits
   - Transactional data requiring ACID
   - Structured data with relationships

2. **MongoDB** - Document store
   - Integration configurations
   - User preferences (flexible schemas)
   - Activity logs
   - Temporary data

3. **Redis** - In-memory cache
   - Session storage
   - API rate limiting
   - Real-time data
   - Pub/sub for WebSocket

4. **Elasticsearch** - Search engine
   - Full-text search across all entities
   - Analytics and aggregations
   - Log storage and analysis

5. **Vector Database (Pinecone/Weaviate)** - Semantic search
   - Task embeddings
   - Goal embeddings
   - AI-powered search

### 6.2 PostgreSQL Schema

#### 6.2.1 Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  name VARCHAR(255) NOT NULL,
  avatar_url TEXT,
  timezone VARCHAR(50) DEFAULT 'UTC',
  locale VARCHAR(10) DEFAULT 'en-US',
  
  -- OAuth
  google_id VARCHAR(255) UNIQUE,
  apple_id VARCHAR(255) UNIQUE,
  
  -- Subscription
  subscription_tier VARCHAR(50) DEFAULT 'free',
  subscription_status VARCHAR(50) DEFAULT 'active',
  subscription_expires_at TIMESTAMP,
  
  -- Preferences
  preferences JSONB DEFAULT '{}',
  
  -- Metadata
  email_verified BOOLEAN DEFAULT FALSE,
  email_verified_at TIMESTAMP,
  last_login_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_google_id ON users(google_id);
CREATE INDEX idx_users_subscription_tier ON users(subscription_tier);
CREATE INDEX idx_users_created_at ON users(created_at);
```

#### 6.2.2 Tasks Table

```sql
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Basic Info
  title VARCHAR(500) NOT NULL,
  description TEXT,
  status VARCHAR(50) DEFAULT 'todo',
  priority VARCHAR(50) DEFAULT 'medium',
  
  -- Scheduling
  due_date TIMESTAMP,
  start_date TIMESTAMP,
  estimated_minutes INTEGER,
  actual_minutes INTEGER,
  
  -- Organization
  project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
  parent_task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  goal_id UUID REFERENCES goals(id) ON DELETE SET NULL,
  tags TEXT[] DEFAULT '{}',
  
  -- AI Features
  ai_priority_score FLOAT,
  ai_estimated_minutes INTEGER,
  energy_level VARCHAR(50), -- low, medium, high
  
  -- Ordering
  order_index INTEGER DEFAULT 0,
  
  -- Metadata
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP,
  
  -- Full-text search
  search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B')
  ) STORED
);

-- Indexes
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_goal_id ON tasks(goal_id);
CREATE INDEX idx_tasks_user_status ON tasks(user_id, status);
CREATE INDEX idx_tasks_user_due_date ON tasks(user_id, due_date);
CREATE INDEX idx_tasks_search_vector ON tasks USING GIN(search_vector);
CREATE INDEX idx_tasks_tags ON tasks USING GIN(tags);
```

#### 6.2.3 Goals Table

```sql
CREATE TABLE goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Basic Info
  title VARCHAR(500) NOT NULL,
  description TEXT,
  category VARCHAR(100), -- career, health, finance, learning, etc.
  
  -- Goal Type
  goal_type VARCHAR(50) DEFAULT 'outcome', -- outcome, habit, learning
  
  -- Timeline
  start_date DATE NOT NULL,
  target_date DATE NOT NULL,
  
  -- Measurement
  metric_type VARCHAR(50), -- number, percentage, boolean, custom
  target_value FLOAT,
  current_value FLOAT DEFAULT 0,
  unit VARCHAR(50),
  
  -- Progress
  progress_percentage FLOAT DEFAULT 0,
  status VARCHAR(50) DEFAULT 'active', -- active, completed, abandoned, paused
  
  -- Hierarchy
  parent_goal_id UUID REFERENCES goals(id) ON DELETE CASCADE,
  
  -- AI Features
  ai_success_probability FLOAT,
  ai_recommended_actions JSONB,
  
  -- Metadata
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Indexes
CREATE INDEX idx_goals_user_id ON goals(user_id);
CREATE INDEX idx_goals_status ON goals(status);
CREATE INDEX idx_goals_category ON goals(category);
CREATE INDEX idx_goals_target_date ON goals(target_date);
CREATE INDEX idx_goals_user_status ON goals(user_id, status);
```

#### 6.2.4 Goal Milestones Table

```sql
CREATE TABLE goal_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  
  title VARCHAR(500) NOT NULL,
  description TEXT,
  target_date DATE NOT NULL,
  
  status VARCHAR(50) DEFAULT 'pending', -- pending, completed, missed
  
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_goal_milestones_goal_id ON goal_milestones(goal_id);
CREATE INDEX idx_goal_milestones_status ON goal_milestones(status);
```

#### 6.2.5 Habits Table

```sql
CREATE TABLE habits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Basic Info
  title VARCHAR(500) NOT NULL,
  description TEXT,
  category VARCHAR(100),
  
  -- Frequency
  frequency_type VARCHAR(50) DEFAULT 'daily', -- daily, weekly, custom
  frequency_value INTEGER DEFAULT 1, -- e.g., 3 times per week
  frequency_days INTEGER[] DEFAULT '{}', -- [1,3,5] for Mon, Wed, Fri
  
  -- Timing
  preferred_time TIME,
  reminder_enabled BOOLEAN DEFAULT TRUE,
  reminder_time TIME,
  
  -- Tracking
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  total_completions INTEGER DEFAULT 0,
  
  -- Status
  status VARCHAR(50) DEFAULT 'active', -- active, paused, archived
  
  -- AI Features
  ai_optimal_time TIME,
  ai_success_rate FLOAT,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Indexes
CREATE INDEX idx_habits_user_id ON habits(user_id);
CREATE INDEX idx_habits_status ON habits(status);
CREATE INDEX idx_habits_category ON habits(category);
```

#### 6.2.6 Habit Completions Table

```sql
CREATE TABLE habit_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id UUID NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  completion_date DATE NOT NULL,
  completion_time TIME,
  
  -- Optional tracking
  notes TEXT,
  mood VARCHAR(50), -- great, good, okay, bad
  energy_level VARCHAR(50), -- high, medium, low
  
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(habit_id, completion_date)
);

-- Indexes
CREATE INDEX idx_habit_completions_habit_id ON habit_completions(habit_id);
CREATE INDEX idx_habit_completions_user_id ON habit_completions(user_id);
CREATE INDEX idx_habit_completions_date ON habit_completions(completion_date);
```

#### 6.2.7 Calendar Events Table

```sql
CREATE TABLE calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Event Info
  title VARCHAR(500) NOT NULL,
  description TEXT,
  location TEXT,
  
  -- Timing
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP NOT NULL,
  all_day BOOLEAN DEFAULT FALSE,
  timezone VARCHAR(50),
  
  -- Recurrence
  recurrence_rule TEXT, -- iCal RRULE format
  recurrence_exception_dates DATE[],
  
  -- External Sync
  external_calendar_id VARCHAR(255),
  external_event_id VARCHAR(255),
  external_provider VARCHAR(50), -- google, outlook, apple
  
  -- Task Link
  task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Indexes
CREATE INDEX idx_calendar_events_user_id ON calendar_events(user_id);
CREATE INDEX idx_calendar_events_start_time ON calendar_events(start_time);
CREATE INDEX idx_calendar_events_end_time ON calendar_events(end_time);
CREATE INDEX idx_calendar_events_external ON calendar_events(external_calendar_id, external_event_id);
```

#### 6.2.8 Projects Table

```sql
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  title VARCHAR(500) NOT NULL,
  description TEXT,
  color VARCHAR(7), -- hex color
  icon VARCHAR(50),
  
  status VARCHAR(50) DEFAULT 'active', -- active, completed, archived
  
  -- Dates
  start_date DATE,
  target_date DATE,
  completed_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_projects_status ON projects(status);
```

#### 6.2.9 Notifications Table

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Notification Info
  type VARCHAR(50) NOT NULL, -- task_due, goal_milestone, habit_reminder, etc.
  title VARCHAR(500) NOT NULL,
  body TEXT,
  
  -- Delivery
  channels VARCHAR(50)[] DEFAULT '{}', -- push, email, sms
  scheduled_for TIMESTAMP NOT NULL,
  sent_at TIMESTAMP,
  
  -- Status
  status VARCHAR(50) DEFAULT 'pending', -- pending, sent, failed, cancelled
  
  -- Related Entity
  entity_type VARCHAR(50), -- task, goal, habit
  entity_id UUID,
  
  -- Metadata
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_scheduled_for ON notifications(scheduled_for);
CREATE INDEX idx_notifications_entity ON notifications(entity_type, entity_id);
```

#### 6.2.10 Analytics Events Table

```sql
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  
  -- Event Info
  event_name VARCHAR(100) NOT NULL,
  event_category VARCHAR(50),
  
  -- Properties
  properties JSONB DEFAULT '{}',
  
  -- Context
  session_id VARCHAR(255),
  device_type VARCHAR(50),
  platform VARCHAR(50),
  app_version VARCHAR(50),
  
  -- Location
  ip_address INET,
  country VARCHAR(2),
  city VARCHAR(100),
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_name ON analytics_events(event_name);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at);
CREATE INDEX idx_analytics_events_properties ON analytics_events USING GIN(properties);
```

#### 6.2.11 Integrations Table

```sql
CREATE TABLE integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Integration Info
  provider VARCHAR(50) NOT NULL, -- google, slack, notion, etc.
  integration_type VARCHAR(50) NOT NULL, -- calendar, email, messaging
  
  -- Credentials (encrypted)
  access_token TEXT,
  refresh_token TEXT,
  token_expires_at TIMESTAMP,
  
  -- Configuration
  config JSONB DEFAULT '{}',
  
  -- Status
  status VARCHAR(50) DEFAULT 'active', -- active, error, disconnected
  last_sync_at TIMESTAMP,
  last_error TEXT,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_integrations_user_id ON integrations(user_id);
CREATE INDEX idx_integrations_provider ON integrations(provider);
CREATE INDEX idx_integrations_status ON integrations(status);
```

### 6.3 Database Optimization

#### 6.3.1 Indexing Strategy

**Primary Indexes:**
- All foreign keys
- Frequently queried columns (user_id, status, dates)
- Composite indexes for common query patterns

**Full-Text Search:**
```sql
-- Enable pg_trgm extension for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create GIN index for full-text search
CREATE INDEX idx_tasks_search_vector ON tasks USING GIN(search_vector);

-- Create trigram index for fuzzy matching
CREATE INDEX idx_tasks_title_trgm ON tasks USING GIN(title gin_trgm_ops);
```

**Partial Indexes:**
```sql
-- Index only active tasks
CREATE INDEX idx_tasks_active ON tasks(user_id, due_date) 
WHERE status != 'done' AND deleted_at IS NULL;

-- Index only upcoming events
CREATE INDEX idx_calendar_events_upcoming ON calendar_events(user_id, start_time)
WHERE start_time > NOW();
```

#### 6.3.2 Partitioning Strategy

**Time-Based Partitioning for Analytics:**
```sql
-- Partition analytics_events by month
CREATE TABLE analytics_events (
  id UUID NOT NULL,
  user_id UUID,
  event_name VARCHAR(100) NOT NULL,
  properties JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE analytics_events_2026_01 PARTITION OF analytics_events
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE analytics_events_2026_02 PARTITION OF analytics_events
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- Auto-create partitions with pg_partman extension
```

#### 6.3.3 Query Optimization

**Materialized Views for Analytics:**
```sql
-- User productivity stats
CREATE MATERIALIZED VIEW user_productivity_stats AS
SELECT
  user_id,
  DATE(created_at) as date,
  COUNT(*) FILTER (WHERE status = 'done') as tasks_completed,
  COUNT(*) FILTER (WHERE status != 'done') as tasks_pending,
  AVG(actual_minutes) FILTER (WHERE status = 'done') as avg_task_duration,
  COUNT(DISTINCT project_id) as active_projects
FROM tasks
WHERE deleted_at IS NULL
GROUP BY user_id, DATE(created_at);

-- Refresh strategy
CREATE INDEX idx_user_productivity_stats ON user_productivity_stats(user_id, date);

-- Refresh daily
REFRESH MATERIALIZED VIEW CONCURRENTLY user_productivity_stats;
```

**Common Table Expressions (CTEs):**
```sql
-- Get user's task summary with subtask counts
WITH task_subtasks AS (
  SELECT
    parent_task_id,
    COUNT(*) as subtask_count,
    COUNT(*) FILTER (WHERE status = 'done') as completed_subtasks
  FROM tasks
  WHERE parent_task_id IS NOT NULL
  GROUP BY parent_task_id
)
SELECT
  t.*,
  COALESCE(ts.subtask_count, 0) as subtask_count,
  COALESCE(ts.completed_subtasks, 0) as completed_subtasks
FROM tasks t
LEFT JOIN task_subtasks ts ON t.id = ts.parent_task_id
WHERE t.user_id = $1 AND t.parent_task_id IS NULL;
```

#### 6.3.4 Connection Pooling

```typescript
// src/config/database.ts
import { Sequelize } from 'sequelize';

export const sequelize = new Sequelize(
  process.env.DATABASE_URL!,
  {
    dialect: 'postgres',
    pool: {
      max: 20,        // Maximum connections
      min: 5,         // Minimum connections
      acquire: 30000, // Max time to acquire connection (ms)
      idle: 10000,    // Max idle time before releasing (ms)
    },
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    dialectOptions: {
      ssl: process.env.NODE_ENV === 'production' ? {
        require: true,
        rejectUnauthorized: false,
      } : false,
    },
  }
);
```

### 6.4 MongoDB Schema

#### 6.4.1 Integration Configurations

```typescript
// Integration configuration document
interface IntegrationConfig {
  _id: ObjectId;
  userId: string;
  provider: string; // 'google', 'slack', 'notion'
  type: string; // 'calendar', 'email', 'messaging'
  
  // Configuration
  config: {
    syncEnabled: boolean;
    syncFrequency: number; // minutes
    syncDirection: 'one-way' | 'two-way';
    filters: {
      calendars?: string[];
      labels?: string[];
      channels?: string[];
    };
    mappings: {
      [key: string]: any;
    };
  };
  
  // Sync State
  lastSyncAt: Date;
  lastSyncStatus: 'success' | 'error';
  lastSyncError?: string;
  nextSyncAt: Date;
  
  // Metadata
  createdAt: Date;
  updatedAt: Date;
}
```

#### 6.4.2 Activity Logs

```typescript
// Activity log document
interface ActivityLog {
  _id: ObjectId;
  userId: string;
  
  // Activity Info
  action: string; // 'task.created', 'goal.completed', etc.
  entityType: string; // 'task', 'goal', 'habit'
  entityId: string;
  
  // Changes
  changes: {
    before: any;
    after: any;
  };
  
  // Context
  source: string; // 'web', 'mobile', 'api'
  ipAddress: string;
  userAgent: string;
  
  // Metadata
  timestamp: Date;
}

// Indexes
db.activity_logs.createIndex({ userId: 1, timestamp: -1 });
db.activity_logs.createIndex({ entityType: 1, entityId: 1 });
db.activity_logs.createIndex({ timestamp: 1 }, { expireAfterSeconds: 7776000 }); // 90 days TTL
```

#### 6.4.3 User Preferences

```typescript
// User preferences document
interface UserPreferences {
  _id: ObjectId;
  userId: string;
  
  // UI Preferences
  theme: 'light' | 'dark' | 'auto';
  language: string;
  dateFormat: string;
  timeFormat: '12h' | '24h';
  weekStartsOn: 0 | 1; // Sunday or Monday
  
  // Notification Preferences
  notifications: {
    push: {
      enabled: boolean;
      taskReminders: boolean;
      goalMilestones: boolean;
      habitReminders: boolean;
      dailyBriefing: boolean;
    };
    email: {
      enabled: boolean;
      frequency: 'realtime' | 'daily' | 'weekly';
      types: string[];
    };
  };
  
  // AI Preferences
  ai: {
    enabled: boolean;
    autoSchedule: boolean;
    autoPrioritize: boolean;
    suggestions: boolean;
    dailyBriefing: boolean;
    briefingTime: string; // '08:00'
  };
  
  // Work Preferences
  workHours: {
    enabled: boolean;
    start: string; // '09:00'
    end: string; // '17:00'
    days: number[]; // [1,2,3,4,5] for Mon-Fri
  };
  
  // Focus Time
  focusTime: {
    enabled: boolean;
    blocks: Array<{
      day: number;
      start: string;
      end: string;
    }>;
  };
  
  // Metadata
  updatedAt: Date;
}
```

### 6.5 Redis Data Structures

#### 6.5.1 Session Storage

```typescript
// Session key: session:{sessionId}
interface Session {
  userId: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: number; // Unix timestamp
  deviceInfo: {
    type: string;
    platform: string;
    appVersion: string;
  };
}

// Store session
await redis.setex(
  `session:${sessionId}`,
  7 * 24 * 60 * 60, // 7 days
  JSON.stringify(session)
);

// Get session
const sessionData = await redis.get(`session:${sessionId}`);
const session = JSON.parse(sessionData);
```

#### 6.5.2 Rate Limiting

```typescript
// Rate limit key: ratelimit:{userId}:{endpoint}
async function checkRateLimit(userId: string, endpoint: string): Promise<boolean> {
  const key = `ratelimit:${userId}:${endpoint}`;
  const limit = 100; // requests per minute
  const window = 60; // seconds
  
  const current = await redis.incr(key);
  
  if (current === 1) {
    await redis.expire(key, window);
  }
  
  return current <= limit;
}
```

#### 6.5.3 Real-Time Data

```typescript
// Active users set
await redis.sadd('active_users', userId);
await redis.expire(`active_users:${userId}`, 300); // 5 minutes

// Task updates pub/sub
await redis.publish('task_updates', JSON.stringify({
  userId,
  taskId,
  action: 'completed',
  timestamp: Date.now(),
}));

// Subscribe to updates
redis.subscribe('task_updates', (message) => {
  const update = JSON.parse(message);
  // Broadcast to WebSocket clients
});
```

#### 6.5.4 Caching

```typescript
// Cache user's tasks
const cacheKey = `tasks:${userId}`;
const cachedTasks = await redis.get(cacheKey);

if (cachedTasks) {
  return JSON.parse(cachedTasks);
}

const tasks = await Task.findAll({ where: { userId } });
await redis.setex(cacheKey, 300, JSON.stringify(tasks)); // 5 minutes

return tasks;
```

### 6.6 Elasticsearch Mapping

```json
{
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "userId": { "type": "keyword" },
      "type": { "type": "keyword" },
      "title": {
        "type": "text",
        "analyzer": "english",
        "fields": {
          "keyword": { "type": "keyword" },
          "suggest": { "type": "completion" }
        }
      },
      "description": {
        "type": "text",
        "analyzer": "english"
      },
      "status": { "type": "keyword" },
      "priority": { "type": "keyword" },
      "tags": { "type": "keyword" },
      "dueDate": { "type": "date" },
      "createdAt": { "type": "date" },
      "updatedAt": { "type": "date" }
    }
  }
}
```

### 6.7 Database Scaling Strategy

#### 6.7.1 Read Replicas

```
Primary (Write) ← Replication → Replica 1 (Read)
                              → Replica 2 (Read)
                              → Replica 3 (Read)
```

**Configuration:**
```typescript
// Master-slave configuration
const sequelize = new Sequelize({
  replication: {
    read: [
      { host: 'replica1.db.lifeos.com', username: 'reader', password: '...' },
      { host: 'replica2.db.lifeos.com', username: 'reader', password: '...' },
      { host: 'replica3.db.lifeos.com', username: 'reader', password: '...' },
    ],
    write: {
      host: 'primary.db.lifeos.com',
      username: 'writer',
      password: '...',
    },
  },
});
```

#### 6.7.2 Sharding Strategy

**Shard by User ID:**
```
Users 0-999999    → Shard 1
Users 1000000-1999999 → Shard 2
Users 2000000-2999999 → Shard 3
...
```

**Shard Key Function:**
```typescript
function getShardId(userId: string): number {
  const userIdNum = parseInt(userId.replace(/-/g, ''), 16);
  return userIdNum % NUM_SHARDS;
}
```

#### 6.7.3 Backup Strategy

**Automated Backups:**
- Full backup: Daily at 2 AM UTC
- Incremental backup: Every 6 hours
- Point-in-time recovery: 30 days
- Cross-region replication: Real-time

**Backup Script:**
```bash
#!/bin/bash
# Daily PostgreSQL backup

DATE=$(date +%Y-%m-%d)
BACKUP_DIR="/backups/postgresql"
DATABASE="lifeos"

# Create backup
pg_dump -h $DB_HOST -U $DB_USER -F c -b -v -f "$BACKUP_DIR/$DATABASE-$DATE.backup" $DATABASE

# Upload to S3
aws s3 cp "$BACKUP_DIR/$DATABASE-$DATE.backup" "s3://lifeos-backups/postgresql/$DATE/"

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "*.backup" -mtime +30 -delete
```

---

## 7. AI/ML ARCHITECTURE

### 7.1 AI Service Overview

**AI Capabilities:**
1. Natural language task creation
2. Task time estimation
3. Smart prioritization
4. Intelligent scheduling
5. Goal success prediction
6. Habit formation coaching
7. Personalized recommendations
8. Semantic search
9. Daily briefing generation
10. Meeting notes summarization

### 7.2 LLM Integration

#### 7.2.1 OpenAI GPT-4 Integration

```python
# ai-service/src/services/llm_service.py
from openai import OpenAI
from typing import List, Dict, Any
import json

class LLMService:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        self.model = "gpt-4-turbo-preview"
    
    async def parse_natural_language_task(self, text: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Parse natural language into structured task data.
        
        Example:
        Input: "Remind me to call mom next Tuesday at 3pm"
        Output: {
            "title": "Call mom",
            "dueDate": "2026-04-28T15:00:00Z",
            "priority": "medium"
        }
        """
        system_prompt = """You are a task parsing assistant. Extract structured task information from natural language.
        
        Return JSON with these fields:
        - title: string (required)
        - description: string (optional)
        - dueDate: ISO 8601 datetime (optional)
        - priority: "low" | "medium" | "high" (optional)
        - estimatedMinutes: number (optional)
        - tags: string[] (optional)
        """
        
        user_prompt = f"""Parse this task: "{text}"
        
        Context:
        - Current time: {context['currentTime']}
        - User timezone: {context['timezone']}
        - User's typical work hours: {context['workHours']}
        """
        
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            response_format={"type": "json_object"},
            temperature=0.3
        )
        
        return json.loads(response.choices[0].message.content)
    
    async def estimate_task_duration(self, title: str, description: str = None) -> int:
        """
        Estimate task duration in minutes using AI.
        """
        prompt = f"""Estimate how long this task will take in minutes:
        
        Title: {title}
        Description: {description or 'N/A'}
        
        Consider:
        - Task complexity
        - Typical time for similar tasks
        - Need for research or preparation
        
        Return only a number (minutes).
        """
        
        response = await self.client.chat.completions.create(
            model=sel