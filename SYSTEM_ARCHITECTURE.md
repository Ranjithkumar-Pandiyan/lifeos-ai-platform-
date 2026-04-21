# LifeOS - System Architecture Document
## Enterprise-Grade Architecture for 1M+ Users

**Version:** 1.0  
**Last Updated:** April 21, 2026  
**Status:** Design Phase

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Technology Stack](#3-technology-stack)
4. [Frontend Architecture](#4-frontend-architecture)
5. [Backend Architecture](#5-backend-architecture)
6. [Database Design](#6-database-design)
7. [AI/ML Architecture](#7-aiml-architecture)
8. [API Design](#8-api-design)
9. [Authentication & Authorization](#9-authentication--authorization)
10. [Real-Time Systems](#10-real-time-systems)
11. [Integration Architecture](#11-integration-architecture)
12. [Infrastructure & DevOps](#12-infrastructure--devops)
13. [Security Architecture](#13-security-architecture)
14. [Performance & Scalability](#14-performance--scalability)
15. [Monitoring & Observability](#15-monitoring--observability)
16. [Disaster Recovery](#16-disaster-recovery)

---

## 1. EXECUTIVE SUMMARY

LifeOS is built on a modern, cloud-native, microservices architecture designed to scale to 1M+ users while maintaining sub-200ms response times and 99.9% uptime. The system leverages cutting-edge technologies including:

- **Frontend:** Next.js 14 (React 18) with TypeScript for web, React Native for mobile
- **Backend:** Node.js microservices with TypeScript, Python for AI/ML services
- **Databases:** PostgreSQL (primary), MongoDB (flexible schemas), Redis (caching), Elasticsearch (search)
- **AI/ML:** OpenAI GPT-4, custom ML models, vector databases for semantic search
- **Infrastructure:** AWS (primary), Kubernetes for orchestration, Terraform for IaC
- **Real-Time:** WebSocket for live updates, Server-Sent Events for notifications

**Key Architectural Principles:**
1. **Microservices:** Independent, scalable services
2. **API-First:** Well-defined contracts between services
3. **Cloud-Native:** Designed for cloud from day one
4. **Security-First:** Zero-trust architecture
5. **Data-Driven:** Analytics and ML at the core
6. **Developer Experience:** Fast iteration, easy debugging

---

## 2. ARCHITECTURE OVERVIEW

### 2.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│  Web App (Next.js)  │  iOS App (React Native)  │  Android App   │
└──────────────┬──────────────────┬──────────────────┬────────────┘
               │                  │                  │
               └──────────────────┼──────────────────┘
                                  │
                         ┌────────▼────────┐
                         │   CDN (CloudFront)  │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │  API Gateway     │
                         │  (Kong/AWS ALB)  │
                         └────────┬────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
┌───────▼────────┐    ┌──────────▼──────────┐    ┌────────▼────────┐
│  Auth Service  │    │   API Services       │    │  AI Service     │
│  (Node.js)     │    │   (Microservices)    │    │  (Python)       │
└───────┬────────┘    └──────────┬──────────┘    └────────┬────────┘
        │                         │                         │
        │             ┌───────────┼───────────┐            │
        │             │           │           │            │
┌───────▼────────┐ ┌──▼────┐ ┌──▼────┐ ┌───▼────┐ ┌─────▼─────┐
│  PostgreSQL    │ │ Redis │ │MongoDB│ │Elastic │ │  Vector   │
│  (Primary DB)  │ │(Cache)│ │(Docs) │ │(Search)│ │    DB     │
└────────────────┘ └───────┘ └───────┘ └────────┘ └───────────┘
        │
┌───────▼────────┐
│  Message Queue │
│  (RabbitMQ)    │
└────────────────┘
        │
┌───────▼────────┐
│  Worker Nodes  │
│  (Background)  │
└────────────────┘
```

### 2.2 Microservices Architecture

**Core Services:**

1. **Auth Service** - Authentication, authorization, user sessions
2. **User Service** - User profiles, preferences, settings
3. **Task Service** - Task CRUD, prioritization, scheduling
4. **Goal Service** - Goal tracking, progress calculation, milestones
5. **Habit Service** - Habit tracking, streaks, analytics
6. **Calendar Service** - Calendar sync, event management
7. **AI Service** - LLM integration, predictions, recommendations
8. **Notification Service** - Push, email, SMS notifications
9. **Integration Service** - Third-party API integrations
10. **Analytics Service** - User analytics, insights, reporting
11. **Search Service** - Full-text search, semantic search
12. **Media Service** - File uploads, image processing

**Supporting Services:**

13. **API Gateway** - Request routing, rate limiting, authentication
14. **Service Discovery** - Service registration and discovery (Consul)
15. **Config Service** - Centralized configuration management
16. **Logging Service** - Centralized logging (ELK stack)
17. **Monitoring Service** - Metrics, alerts, dashboards (Prometheus/Grafana)

### 2.3 Communication Patterns

**Synchronous (REST/GraphQL):**
- Client ↔ API Gateway ↔ Services
- Service ↔ Service (for immediate responses)

**Asynchronous (Message Queue):**
- Event-driven communication between services
- Background job processing
- Email sending, notifications

**Real-Time (WebSocket/SSE):**
- Live updates (task completion, goal progress)
- Collaborative features (shared goals, team tasks)
- AI assistant streaming responses

---

## 3. TECHNOLOGY STACK

### 3.1 Technology Selection Matrix

| Category | Technology | Justification | Alternatives Considered |
|----------|-----------|---------------|------------------------|
| **Frontend Framework** | Next.js 14 | SSR/SSG, React 18, excellent DX, Vercel deployment | Remix, SvelteKit, Nuxt.js |
| **Mobile Framework** | React Native | Code sharing with web, large ecosystem, Expo | Flutter, Native (Swift/Kotlin) |
| **Backend Language** | Node.js + TypeScript | JavaScript everywhere, async I/O, large ecosystem | Go, Python, Java |
| **AI/ML Language** | Python | Best ML libraries, OpenAI SDK, data science tools | Node.js, Julia |
| **Primary Database** | PostgreSQL 15 | ACID, JSON support, mature, excellent performance | MySQL, CockroachDB |
| **Document Store** | MongoDB 6 | Flexible schemas, good for rapid iteration | DynamoDB, Couchbase |
| **Cache** | Redis 7 | Fast, versatile, pub/sub, sessions | Memcached, Hazelcast |
| **Search Engine** | Elasticsearch 8 | Full-text search, analytics, scalable | Algolia, Meilisearch, Typesense |
| **Message Queue** | RabbitMQ | Reliable, flexible routing, dead letter queues | Kafka, AWS SQS, Redis Streams |
| **API Gateway** | Kong | Open source, plugins, rate limiting | AWS API Gateway, Nginx, Traefik |
| **Container Orchestration** | Kubernetes | Industry standard, cloud-agnostic, mature | Docker Swarm, ECS, Nomad |
| **IaC** | Terraform | Multi-cloud, declarative, state management | Pulumi, CloudFormation, CDK |
| **CI/CD** | GitHub Actions | Integrated with GitHub, free for public repos | GitLab CI, CircleCI, Jenkins |
| **Monitoring** | Prometheus + Grafana | Open source, powerful, flexible | Datadog, New Relic, Dynatrace |
| **Logging** | ELK Stack | Centralized, searchable, visualizations | Splunk, Loki, CloudWatch |
| **Error Tracking** | Sentry | Real-time, source maps, release tracking | Rollbar, Bugsnag, Raygun |
| **Cloud Provider** | AWS | Mature, comprehensive services, global reach | GCP, Azure, DigitalOcean |

### 3.2 Detailed Technology Justifications

#### Frontend: Next.js 14 + React 18

**Why Next.js:**
- **Server-Side Rendering (SSR):** Better SEO, faster initial load
- **Static Site Generation (SSG):** Pre-render pages for performance
- **API Routes:** Backend functionality without separate server
- **Image Optimization:** Automatic image optimization and lazy loading
- **File-Based Routing:** Intuitive routing based on file structure
- **TypeScript Support:** First-class TypeScript support
- **Vercel Deployment:** One-click deployment with edge functions
- **React Server Components:** Latest React features

**Why React 18:**
- **Concurrent Rendering:** Better performance for complex UIs
- **Automatic Batching:** Fewer re-renders
- **Suspense:** Better loading states
- **Transitions:** Smooth UI updates
- **Largest Ecosystem:** Most libraries, components, developers

**Alternatives Considered:**
- **Remix:** Great DX, but smaller ecosystem
- **SvelteKit:** Faster, but smaller community
- **Nuxt.js:** Vue-based, but we prefer React ecosystem

#### Mobile: React Native + Expo

**Why React Native:**
- **Code Sharing:** Share business logic with web app (60-80% code reuse)
- **Single Language:** JavaScript/TypeScript everywhere
- **Large Ecosystem:** Thousands of libraries
- **Hot Reload:** Fast development iteration
- **Native Performance:** Near-native performance
- **Expo:** Simplifies development, OTA updates

**Alternatives Considered:**
- **Flutter:** Faster, but Dart language, less code sharing with web
- **Native (Swift/Kotlin):** Best performance, but 2x development time

#### Backend: Node.js + TypeScript

**Why Node.js:**
- **JavaScript Everywhere:** Same language as frontend
- **Async I/O:** Perfect for I/O-bound operations (API calls, DB queries)
- **NPM Ecosystem:** Largest package ecosystem
- **Microservices:** Lightweight, fast startup times
- **Real-Time:** Excellent WebSocket support
- **JSON Native:** Natural fit for JSON APIs

**Why TypeScript:**
- **Type Safety:** Catch errors at compile time
- **Better IDE Support:** Autocomplete, refactoring
- **Self-Documenting:** Types serve as documentation
- **Easier Refactoring:** Confident large-scale changes
- **Industry Standard:** Most new Node.js projects use TypeScript

**Alternatives Considered:**
- **Go:** Faster, but less ecosystem, harder to hire
- **Python:** Great for AI, but slower for APIs
- **Java/Spring Boot:** Enterprise-grade, but verbose, slower iteration

#### AI/ML: Python + OpenAI

**Why Python:**
- **ML Libraries:** TensorFlow, PyTorch, scikit-learn
- **OpenAI SDK:** Official Python SDK
- **Data Science:** Pandas, NumPy, Jupyter
- **Fast Prototyping:** Quick to test ML models
- **Community:** Largest ML community

**Why OpenAI GPT-4:**
- **State-of-the-Art:** Best language understanding
- **Function Calling:** Can trigger LifeOS actions
- **Streaming:** Real-time responses
- **Fine-Tuning:** Can customize for LifeOS
- **Embeddings:** For semantic search

**Alternatives Considered:**
- **Anthropic Claude:** Great, but less ecosystem
- **Self-Hosted LLMs:** Cheaper at scale, but requires ML expertise
- **Google PaLM:** Good, but less flexible

#### Database: PostgreSQL

**Why PostgreSQL:**
- **ACID Compliance:** Data integrity guaranteed
- **JSON Support:** Flexible schemas when needed (JSONB)
- **Performance:** Excellent query performance with proper indexing
- **Extensions:** PostGIS, pg_trgm, full-text search
- **Mature:** 30+ years of development
- **Open Source:** No vendor lock-in
- **Scalability:** Proven at massive scale (Instagram, Uber)

**Alternatives Considered:**
- **MySQL:** Good, but PostgreSQL has better JSON support
- **CockroachDB:** Distributed, but more complex, higher cost

#### Cache: Redis

**Why Redis:**
- **Speed:** In-memory, sub-millisecond latency
- **Versatile:** Cache, sessions, pub/sub, queues
- **Data Structures:** Strings, hashes, lists, sets, sorted sets
- **Persistence:** Optional disk persistence
- **Clustering:** Built-in clustering for scale
- **Lua Scripting:** Complex operations atomically

**Alternatives Considered:**
- **Memcached:** Simpler, but less features
- **Hazelcast:** Distributed, but more complex

#### Search: Elasticsearch

**Why Elasticsearch:**
- **Full-Text Search:** Powerful text search with relevance scoring
- **Analytics:** Aggregations for insights
- **Scalable:** Distributed by design
- **Real-Time:** Near real-time indexing
- **Flexible:** Schema-less, handles any data structure
- **Kibana:** Excellent visualization tool

**Alternatives Considered:**
- **Algolia:** Faster, easier, but expensive at scale
- **Meilisearch:** Open source, fast, but less mature
- **Typesense:** Fast, but smaller ecosystem

#### Message Queue: RabbitMQ

**Why RabbitMQ:**
- **Reliable:** Message persistence, acknowledgments
- **Flexible Routing:** Exchanges, queues, bindings
- **Dead Letter Queues:** Handle failed messages
- **Priority Queues:** Prioritize important messages
- **Management UI:** Easy monitoring
- **Mature:** Battle-tested

**Alternatives Considered:**
- **Kafka:** Better for event streaming, but overkill for our use case
- **AWS SQS:** Managed, but vendor lock-in
- **Redis Streams:** Simpler, but less features

#### Cloud: AWS

**Why AWS:**
- **Comprehensive:** Every service we need
- **Mature:** Most stable, proven at scale
- **Global:** Regions worldwide for low latency
- **Ecosystem:** Largest third-party ecosystem
- **Pricing:** Competitive, especially with reserved instances
- **Hiring:** Easiest to find AWS-experienced engineers

**Services We'll Use:**
- **EC2:** Virtual machines for Kubernetes nodes
- **EKS:** Managed Kubernetes
- **RDS:** Managed PostgreSQL
- **ElastiCache:** Managed Redis
- **S3:** Object storage for files, backups
- **CloudFront:** CDN for global content delivery
- **Route 53:** DNS management
- **SES:** Email sending
- **SNS:** Push notifications
- **Lambda:** Serverless functions for background tasks
- **CloudWatch:** Logging and monitoring
- **Secrets Manager:** Secure credential storage
- **IAM:** Identity and access management

**Alternatives Considered:**
- **GCP:** Great for ML, but smaller ecosystem
- **Azure:** Good for enterprises, but less startup-friendly
- **DigitalOcean:** Simpler, cheaper, but less services

---

## 4. FRONTEND ARCHITECTURE

### 4.1 Web Application (Next.js)

#### 4.1.1 Project Structure

```
lifeos-web/
├── public/                    # Static assets
│   ├── images/
│   ├── icons/
│   └── fonts/
├── src/
│   ├── app/                   # Next.js 14 App Router
│   │   ├── (auth)/           # Auth routes group
│   │   │   ├── login/
│   │   │   ├── signup/
│   │   │   └── reset-password/
│   │   ├── (dashboard)/      # Dashboard routes group
│   │   │   ├── tasks/
│   │   │   ├── goals/
│   │   │   ├── habits/
│   │   │   ├── calendar/
│   │   │   └── analytics/
│   │   ├── api/              # API routes
│   │   │   ├── auth/
│   │   │   └── webhooks/
│   │   ├── layout.tsx        # Root layout
│   │   ├── page.tsx          # Home page
│   │   └── error.tsx         # Error boundary
│   ├── components/           # React components
│   │   ├── ui/              # Base UI components
│   │   │   ├── Button/
│   │   │   ├── Input/
│   │   │   ├── Modal/
│   │   │   ├── Card/
│   │   │   └── ...
│   │   ├── features/        # Feature-specific components
│   │   │   ├── tasks/
│   │   │   │   ├── TaskList/
│   │   │   │   ├── TaskItem/
│   │   │   │   ├── TaskForm/
│   │   │   │   └── TaskFilters/
│   │   │   ├── goals/
│   │   │   ├── habits/
│   │   │   └── calendar/
│   │   ├── layout/          # Layout components
│   │   │   ├── Header/
│   │   │   ├── Sidebar/
│   │   │   ├── Footer/
│   │   │   └── Navigation/
│   │   └── shared/          # Shared components
│   │       ├── LoadingSpinner/
│   │       ├── ErrorBoundary/
│   │       └── EmptyState/
│   ├── lib/                 # Utilities and helpers
│   │   ├── api/            # API client
│   │   │   ├── client.ts
│   │   │   ├── tasks.ts
│   │   │   ├── goals.ts
│   │   │   └── habits.ts
│   │   ├── hooks/          # Custom React hooks
│   │   │   ├── useAuth.ts
│   │   │   ├── useTasks.ts
│   │   │   ├── useGoals.ts
│   │   │   └── useHabits.ts
│   │   ├── utils/          # Utility functions
│   │   │   ├── date.ts
│   │   │   ├── format.ts
│   │   │   └── validation.ts
│   │   ├── constants/      # Constants
│   │   │   ├── routes.ts
│   │   │   └── config.ts
│   │   └── types/          # TypeScript types
│   │       ├── task.ts
│   │       ├── goal.ts
│   │       └── habit.ts
│   ├── store/              # State management (Zustand)
│   │   ├── authStore.ts
│   │   ├── taskStore.ts
│   │   ├── goalStore.ts
│   │   └── habitStore.ts
│   ├── styles/             # Global styles
│   │   ├── globals.css
│   │   ├── variables.css
│   │   └── themes/
│   └── middleware.ts       # Next.js middleware
├── tests/                  # Tests
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── .env.local             # Environment variables
├── next.config.js         # Next.js configuration
├── tsconfig.json          # TypeScript configuration
├── tailwind.config.js     # Tailwind CSS configuration
└── package.json           # Dependencies
```

#### 4.1.2 State Management Strategy

**Zustand for Global State:**

```typescript
// src/store/taskStore.ts
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

interface Task {
  id: string;
  title: string;
  description: string;
  status: 'todo' | 'in_progress' | 'done';
  priority: 'low' | 'medium' | 'high';
  dueDate: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

interface TaskStore {
  tasks: Task[];
  isLoading: boolean;
  error: string | null;
  
  // Actions
  fetchTasks: () => Promise<void>;
  createTask: (task: Omit<Task, 'id' | 'createdAt' | 'updatedAt'>) => Promise<void>;
  updateTask: (id: string, updates: Partial<Task>) => Promise<void>;
  deleteTask: (id: string) => Promise<void>;
  completeTask: (id: string) => Promise<void>;
}

export const useTaskStore = create<TaskStore>()(
  devtools(
    persist(
      (set, get) => ({
        tasks: [],
        isLoading: false,
        error: null,
        
        fetchTasks: async () => {
          set({ isLoading: true, error: null });
          try {
            const response = await fetch('/api/tasks');
            const tasks = await response.json();
            set({ tasks, isLoading: false });
          } catch (error) {
            set({ error: error.message, isLoading: false });
          }
        },
        
        createTask: async (taskData) => {
          set({ isLoading: true, error: null });
          try {
            const response = await fetch('/api/tasks', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(taskData),
            });
            const newTask = await response.json();
            set((state) => ({
              tasks: [...state.tasks, newTask],
              isLoading: false,
            }));
          } catch (error) {
            set({ error: error.message, isLoading: false });
          }
        },
        
        updateTask: async (id, updates) => {
          set({ isLoading: true, error: null });
          try {
            const response = await fetch(`/api/tasks/${id}`, {
              method: 'PATCH',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(updates),
            });
            const updatedTask = await response.json();
            set((state) => ({
              tasks: state.tasks.map((task) =>
                task.id === id ? updatedTask : task
              ),
              isLoading: false,
            }));
          } catch (error) {
            set({ error: error.message, isLoading: false });
          }
        },
        
        deleteTask: async (id) => {
          set({ isLoading: true, error: null });
          try {
            await fetch(`/api/tasks/${id}`, { method: 'DELETE' });
            set((state) => ({
              tasks: state.tasks.filter((task) => task.id !== id),
              isLoading: false,
            }));
          } catch (error) {
            set({ error: error.message, isLoading: false });
          }
        },
        
        completeTask: async (id) => {
          await get().updateTask(id, { status: 'done' });
        },
      }),
      {
        name: 'task-storage',
        partialize: (state) => ({ tasks: state.tasks }), // Only persist tasks
      }
    )
  )
);
```

**Why Zustand:**
- Lightweight (1KB)
- Simple API
- No boilerplate
- TypeScript support
- DevTools integration
- Persistence middleware
- No Provider wrapper needed

**Alternatives Considered:**
- **Redux Toolkit:** More powerful, but more boilerplate
- **Jotai:** Atomic state, but less mature
- **Recoil:** Facebook-backed, but complex

#### 4.1.3 API Client Layer

```typescript
// src/lib/api/client.ts
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';

class APIClient {
  private client: AxiosInstance;
  
  constructor() {
    this.client = axios.create({
      baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api',
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
    
    // Request interceptor (add auth token)
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('auth_token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );
    
    // Response interceptor (handle errors)
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          // Token expired, try to refresh
          try {
            const refreshToken = localStorage.getItem('refresh_token');
            const response = await axios.post('/api/auth/refresh', {
              refreshToken,
            });
            const { token } = response.data;
            localStorage.setItem('auth_token', token);
            
            // Retry original request
            error.config.headers.Authorization = `Bearer ${token}`;
            return this.client.request(error.config);
          } catch (refreshError) {
            // Refresh failed, redirect to login
            localStorage.removeItem('auth_token');
            localStorage.removeItem('refresh_token');
            window.location.href = '/login';
          }
        }
        return Promise.reject(error);
      }
    );
  }
  
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get<T>(url, config);
    return response.data;
  }
  
  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.post<T>(url, data, config);
    return response.data;
  }
  
  async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.put<T>(url, data, config);
    return response.data;
  }
  
  async patch<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.patch<T>(url, data, config);
    return response.data;
  }
  
  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.delete<T>(url, config);
    return response.data;
  }
}

export const apiClient = new APIClient();
```

```typescript
// src/lib/api/tasks.ts
import { apiClient } from './client';
import { Task, CreateTaskDTO, UpdateTaskDTO } from '@/lib/types/task';

export const taskAPI = {
  getAll: () => apiClient.get<Task[]>('/tasks'),
  
  getById: (id: string) => apiClient.get<Task>(`/tasks/${id}`),
  
  create: (data: CreateTaskDTO) => apiClient.post<Task>('/tasks', data),
  
  update: (id: string, data: UpdateTaskDTO) =>
    apiClient.patch<Task>(`/tasks/${id}`, data),
  
  delete: (id: string) => apiClient.delete(`/tasks/${id}`),
  
  complete: (id: string) =>
    apiClient.patch<Task>(`/tasks/${id}/complete`, {}),
  
  search: (query: string) =>
    apiClient.get<Task[]>(`/tasks/search?q=${encodeURIComponent(query)}`),
  
  getByStatus: (status: string) =>
    apiClient.get<Task[]>(`/tasks?status=${status}`),
  
  getByPriority: (priority: string) =>
    apiClient.get<Task[]>(`/tasks?priority=${priority}`),
};
```

#### 4.1.4 Component Architecture

**Atomic Design Pattern:**

1. **Atoms:** Basic building blocks (Button, Input, Icon)
2. **Molecules:** Simple combinations (SearchBar, FormField)
3. **Organisms:** Complex components (TaskList, GoalCard)
4. **Templates:** Page layouts
5. **Pages:** Actual pages

**Example Component:**

```typescript
// src/components/features/tasks/TaskItem/TaskItem.tsx
import React from 'react';
import { Task } from '@/lib/types/task';
import { Button } from '@/components/ui/Button';
import { Checkbox } from '@/components/ui/Checkbox';
import { Badge } from '@/components/ui/Badge';
import { formatDate } from '@/lib/utils/date';
import styles from './TaskItem.module.css';

interface TaskItemProps {
  task: Task;
  onComplete: (id: string) => void;
  onEdit: (task: Task) => void;
  onDelete: (id: string) => void;
}

export const TaskItem: React.FC<TaskItemProps> = ({
  task,
  onComplete,
  onEdit,
  onDelete,
}) => {
  const priorityColors = {
    low: 'blue',
    medium: 'yellow',
    high: 'red',
  };
  
  return (
    <div className={styles.taskItem}>
      <Checkbox
        checked={task.status === 'done'}
        onChange={() => onComplete(task.id)}
        aria-label={`Mark "${task.title}" as complete`}
      />
      
      <div className={styles.content}>
        <h3 className={styles.title}>{task.title}</h3>
        {task.description && (
          <p className={styles.description}>{task.description}</p>
        )}
        
        <div className={styles.meta}>
          <Badge color={priorityColors[task.priority]}>
            {task.priority}
          </Badge>
          
          {task.dueDate && (
            <span className={styles.dueDate}>
              Due: {formatDate(task.dueDate)}
            </span>
          )}
        </div>
      </div>
      
      <div className={styles.actions}>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onEdit(task)}
          aria-label="Edit task"
        >
          Edit
        </Button>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onDelete(task.id)}
          aria-label="Delete task"
        >
          Delete
        </Button>
      </div>
    </div>
  );
};
```

#### 4.1.5 Routing Strategy

**Next.js App Router (File-Based):**

```
app/
├── (auth)/
│   ├── login/page.tsx          # /login
│   ├── signup/page.tsx         # /signup
│   └── layout.tsx              # Auth layout (no sidebar)
├── (dashboard)/
│   ├── layout.tsx              # Dashboard layout (with sidebar)
│   ├─