# LifeOS - System Architecture (Part 4)
## AI/ML, API Design, and Real-Time Systems

---

## 7. AI/ML ARCHITECTURE (Continued)

#### 7.2.1 OpenAI GPT-4 Integration (Continued)

```python
# ai-service/src/services/llm_service.py (continued)

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
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_tokens=10
        )
        
        try:
            return int(response.choices[0].message.content.strip())
        except:
            return 30  # Default fallback
    
    async def prioritize_tasks(self, tasks: List[Dict[str, Any]], context: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        AI-powered task prioritization using multiple factors.
        """
        system_prompt = """You are a productivity expert. Prioritize tasks based on:
        1. Urgency (due date proximity)
        2. Importance (impact on goals)
        3. Effort (estimated time)
        4. Dependencies
        5. User's energy level and time of day
        
        Return tasks in priority order with a priority score (0-100).
        """
        
        user_prompt = f"""Prioritize these tasks:
        
        Tasks: {json.dumps(tasks, indent=2)}
        
        Context:
        - Current time: {context['currentTime']}
        - User's energy level: {context['energyLevel']}
        - Available time today: {context['availableMinutes']} minutes
        - User's goals: {context['activeGoals']}
        """
        
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            response_format={"type": "json_object"},
            temperature=0.5
        )
        
        result = json.loads(response.choices[0].message.content)
        return result['prioritizedTasks']
    
    async def generate_daily_briefing(self, user_data: Dict[str, Any]) -> str:
        """
        Generate personalized daily briefing.
        """
        prompt = f"""Generate a motivating daily briefing for the user.
        
        User Data:
        - Name: {user_data['name']}
        - Tasks today: {len(user_data['tasks'])}
        - Meetings: {len(user_data['meetings'])}
        - Habits to complete: {user_data['habits']}
        - Goal progress: {user_data['goalProgress']}%
        - Weather: {user_data['weather']}
        
        Top 3 priorities:
        {json.dumps(user_data['topPriorities'], indent=2)}
        
        Create a brief, motivating message (2-3 paragraphs) that:
        1. Greets the user
        2. Highlights key tasks and meetings
        3. Provides motivation
        4. Suggests optimal approach for the day
        """
        
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7,
            max_tokens=300
        )
        
        return response.choices[0].message.content
    
    async def suggest_goal_actions(self, goal: Dict[str, Any], progress: float) -> List[str]:
        """
        Suggest actionable steps to achieve a goal.
        """
        prompt = f"""Suggest 3-5 specific, actionable steps to achieve this goal:
        
        Goal: {goal['title']}
        Description: {goal['description']}
        Target Date: {goal['targetDate']}
        Current Progress: {progress}%
        
        Make suggestions:
        - Specific and actionable
        - Time-bound
        - Realistic given current progress
        - Ordered by priority
        
        Return as JSON array of strings.
        """
        
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0.6
        )
        
        result = json.loads(response.choices[0].message.content)
        return result['actions']
    
    async def analyze_habit_failure(self, habit: Dict[str, Any], completions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze why a habit is failing and suggest improvements.
        """
        prompt = f"""Analyze this habit and suggest improvements:
        
        Habit: {habit['title']}
        Frequency: {habit['frequency']}
        Current Streak: {habit['currentStreak']}
        Completion Rate: {habit['completionRate']}%
        
        Recent Completions:
        {json.dumps(completions[-14:], indent=2)}
        
        Provide:
        1. Root cause analysis (why is it failing?)
        2. Specific recommendations (3-5 actionable suggestions)
        3. Optimal timing suggestion
        4. Motivation strategy
        
        Return as JSON.
        """
        
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0.6
        )
        
        return json.loads(response.choices[0].message.content)

llm_service = LLMService()
```

### 7.3 Machine Learning Models

#### 7.3.1 Task Duration Prediction Model

```python
# ai-service/src/ml/task_duration_model.py
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import LabelEncoder
import joblib

class TaskDurationModel:
    def __init__(self):
        self.model = RandomForestRegressor(n_estimators=100, random_state=42)
        self.label_encoders = {}
        self.is_trained = False
    
    def prepare_features(self, task: Dict[str, Any]) -> np.ndarray:
        """
        Extract features from task for prediction.
        """
        features = []
        
        # Text features (title length, word count)
        features.append(len(task['title']))
        features.append(len(task['title'].split()))
        
        # Category (encoded)
        if 'category' not in self.label_encoders:
            self.label_encoders['category'] = LabelEncoder()
        category_encoded = self.label_encoders['category'].transform([task.get('category', 'other')])[0]
        features.append(category_encoded)
        
        # Priority (encoded)
        priority_map = {'low': 0, 'medium': 1, 'high': 2}
        features.append(priority_map.get(task.get('priority', 'medium'), 1))
        
        # Has description
        features.append(1 if task.get('description') else 0)
        
        # Number of subtasks
        features.append(len(task.get('subtasks', [])))
        
        # Day of week (if due date exists)
        if task.get('dueDate'):
            due_date = datetime.fromisoformat(task['dueDate'])
            features.append(due_date.weekday())
        else:
            features.append(-1)
        
        return np.array(features).reshape(1, -1)
    
    def train(self, historical_tasks: List[Dict[str, Any]]):
        """
        Train model on historical task data.
        """
        X = []
        y = []
        
        for task in historical_tasks:
            if task.get('actualMinutes'):
                features = self.prepare_features(task)
                X.append(features[0])
                y.append(task['actualMinutes'])
        
        X = np.array(X)
        y = np.array(y)
        
        self.model.fit(X, y)
        self.is_trained = True
        
        # Save model
        joblib.dump(self.model, 'models/task_duration_model.pkl')
        joblib.dump(self.label_encoders, 'models/label_encoders.pkl')
    
    def predict(self, task: Dict[str, Any]) -> int:
        """
        Predict task duration in minutes.
        """
        if not self.is_trained:
            return 30  # Default fallback
        
        features = self.prepare_features(task)
        prediction = self.model.predict(features)[0]
        
        # Round to nearest 5 minutes
        return int(round(prediction / 5) * 5)
    
    def update_with_feedback(self, task: Dict[str, Any], actual_minutes: int):
        """
        Online learning: update model with new data.
        """
        features = self.prepare_features(task)
        self.model.fit(features, [actual_minutes])

task_duration_model = TaskDurationModel()
```

#### 7.3.2 Goal Success Prediction Model

```python
# ai-service/src/ml/goal_success_model.py
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
from datetime import datetime, timedelta

class GoalSuccessModel:
    def __init__(self):
        self.model = GradientBoostingClassifier(n_estimators=100, random_state=42)
        self.is_trained = False
    
    def prepare_features(self, goal: Dict[str, Any], user_stats: Dict[str, Any]) -> np.ndarray:
        """
        Extract features for goal success prediction.
        """
        features = []
        
        # Goal characteristics
        start_date = datetime.fromisoformat(goal['startDate'])
        target_date = datetime.fromisoformat(goal['targetDate'])
        total_days = (target_date - start_date).days
        elapsed_days = (datetime.now() - start_date).days
        
        features.append(total_days)  # Total duration
        features.append(elapsed_days)  # Days elapsed
        features.append(goal.get('progressPercentage', 0))  # Current progress
        
        # Expected vs actual progress
        expected_progress = (elapsed_days / total_days) * 100 if total_days > 0 else 0
        features.append(goal.get('progressPercentage', 0) - expected_progress)
        
        # User historical performance
        features.append(user_stats.get('goalCompletionRate', 0))
        features.append(user_stats.get('averageTaskCompletionRate', 0))
        features.append(user_stats.get('habitConsistencyScore', 0))
        
        # Goal complexity
        features.append(len(goal.get('milestones', [])))
        features.append(len(goal.get('linkedTasks', [])))
        
        # Engagement metrics
        features.append(user_stats.get('daysActive', 0))
        features.append(user_stats.get('averageSessionDuration', 0))
        
        return np.array(features).reshape(1, -1)
    
    def predict_success_probability(self, goal: Dict[str, Any], user_stats: Dict[str, Any]) -> float:
        """
        Predict probability of goal success (0-1).
        """
        if not self.is_trained:
            # Simple heuristic if model not trained
            progress = goal.get('progressPercentage', 0)
            start_date = datetime.fromisoformat(goal['startDate'])
            target_date = datetime.fromisoformat(goal['targetDate'])
            total_days = (target_date - start_date).days
            elapsed_days = (datetime.now() - start_date).days
            
            expected_progress = (elapsed_days / total_days) * 100 if total_days > 0 else 0
            
            if progress >= expected_progress:
                return min(0.9, 0.5 + (progress / 200))
            else:
                return max(0.1, 0.5 - ((expected_progress - progress) / 200))
        
        features = self.prepare_features(goal, user_stats)
        probability = self.model.predict_proba(features)[0][1]
        
        return probability
    
    def train(self, historical_goals: List[Dict[str, Any]]):
        """
        Train model on historical goal data.
        """
        X = []
        y = []
        
        for goal_data in historical_goals:
            goal = goal_data['goal']
            user_stats = goal_data['userStats']
            success = goal_data['success']  # 1 if completed, 0 if abandoned
            
            features = self.prepare_features(goal, user_stats)
            X.append(features[0])
            y.append(success)
        
        X = np.array(X)
        y = np.array(y)
        
        self.model.fit(X, y)
        self.is_trained = True
        
        joblib.dump(self.model, 'models/goal_success_model.pkl')

goal_success_model = GoalSuccessModel()
```

### 7.4 Vector Database for Semantic Search

```python
# ai-service/src/services/vector_service.py
from pinecone import Pinecone, ServerlessSpec
from openai import OpenAI
import numpy as np

class VectorService:
    def __init__(self):
        self.pinecone = Pinecone(api_key=os.getenv('PINECONE_API_KEY'))
        self.openai = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        
        # Create index if not exists
        index_name = 'lifeos-embeddings'
        if index_name not in self.pinecone.list_indexes().names():
            self.pinecone.create_index(
                name=index_name,
                dimension=1536,  # OpenAI embedding dimension
                metric='cosine',
                spec=ServerlessSpec(cloud='aws', region='us-east-1')
            )
        
        self.index = self.pinecone.Index(index_name)
    
    async def generate_embedding(self, text: str) -> List[float]:
        """
        Generate embedding for text using OpenAI.
        """
        response = await self.openai.embeddings.create(
            model="text-embedding-3-small",
            input=text
        )
        return response.data[0].embedding
    
    async def index_task(self, task: Dict[str, Any]):
        """
        Index a task for semantic search.
        """
        # Combine title and description for embedding
        text = f"{task['title']} {task.get('description', '')}"
        embedding = await self.generate_embedding(text)
        
        # Store in Pinecone
        self.index.upsert(vectors=[{
            'id': f"task_{task['id']}",
            'values': embedding,
            'metadata': {
                'userId': task['userId'],
                'type': 'task',
                'title': task['title'],
                'status': task['status'],
                'priority': task['priority'],
            }
        }])
    
    async def index_goal(self, goal: Dict[str, Any]):
        """
        Index a goal for semantic search.
        """
        text = f"{goal['title']} {goal.get('description', '')}"
        embedding = await self.generate_embedding(text)
        
        self.index.upsert(vectors=[{
            'id': f"goal_{goal['id']}",
            'values': embedding,
            'metadata': {
                'userId': goal['userId'],
                'type': 'goal',
                'title': goal['title'],
                'status': goal['status'],
            }
        }])
    
    async def semantic_search(self, query: str, user_id: str, top_k: int = 10) -> List[Dict[str, Any]]:
        """
        Perform semantic search across tasks and goals.
        """
        # Generate query embedding
        query_embedding = await self.generate_embedding(query)
        
        # Search in Pinecone
        results = self.index.query(
            vector=query_embedding,
            filter={'userId': user_id},
            top_k=top_k,
            include_metadata=True
        )
        
        return [
            {
                'id': match['id'],
                'score': match['score'],
                'metadata': match['metadata']
            }
            for match in results['matches']
        ]
    
    async def find_similar_tasks(self, task_id: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """
        Find similar tasks for recommendations.
        """
        # Get task embedding
        task_vector = self.index.fetch(ids=[f"task_{task_id}"])
        
        if not task_vector['vectors']:
            return []
        
        embedding = task_vector['vectors'][f"task_{task_id}"]['values']
        
        # Find similar
        results = self.index.query(
            vector=embedding,
            filter={'type': 'task'},
            top_k=top_k + 1,  # +1 to exclude self
            include_metadata=True
        )
        
        # Exclude the query task itself
        return [
            {
                'id': match['id'],
                'score': match['score'],
                'metadata': match['metadata']
            }
            for match in results['matches']
            if match['id'] != f"task_{task_id}"
        ]

vector_service = VectorService()
```

---

## 8. API DESIGN

### 8.1 RESTful API Endpoints

#### 8.1.1 Authentication Endpoints

```
POST   /api/v1/auth/signup              # Create new account
POST   /api/v1/auth/login               # Login with email/password
POST   /api/v1/auth/logout              # Logout
POST   /api/v1/auth/refresh             # Refresh access token
POST   /api/v1/auth/forgot-password     # Request password reset
POST   /api/v1/auth/reset-password      # Reset password with token
POST   /api/v1/auth/verify-email        # Verify email address
POST   /api/v1/auth/google              # Google OAuth login
POST   /api/v1/auth/apple               # Apple OAuth login
```

#### 8.1.2 User Endpoints

```
GET    /api/v1/users/me                 # Get current user profile
PATCH  /api/v1/users/me                 # Update user profile
DELETE /api/v1/users/me                 # Delete account
GET    /api/v1/users/me/preferences     # Get user preferences
PATCH  /api/v1/users/me/preferences     # Update preferences
GET    /api/v1/users/me/stats           # Get user statistics
```

#### 8.1.3 Task Endpoints

```
GET    /api/v1/tasks                    # List all tasks
POST   /api/v1/tasks                    # Create new task
GET    /api/v1/tasks/:id                # Get task by ID
PATCH  /api/v1/tasks/:id                # Update task
DELETE /api/v1/tasks/:id                # Delete task
POST   /api/v1/tasks/:id/complete       # Mark task as complete
POST   /api/v1/tasks/:id/uncomplete     # Mark task as incomplete
GET    /api/v1/tasks/prioritized        # Get AI-prioritized tasks
GET    /api/v1/tasks/upcoming           # Get upcoming tasks
GET    /api/v1/tasks/overdue            # Get overdue tasks
GET    /api/v1/tasks/search             # Search tasks
POST   /api/v1/tasks/bulk               # Bulk create tasks
PATCH  /api/v1/tasks/bulk               # Bulk update tasks
DELETE /api/v1/tasks/bulk               # Bulk delete tasks
```

#### 8.1.4 Goal Endpoints

```
GET    /api/v1/goals                    # List all goals
POST   /api/v1/goals                    # Create new goal
GET    /api/v1/goals/:id                # Get goal by ID
PATCH  /api/v1/goals/:id                # Update goal
DELETE /api/v1/goals/:id                # Delete goal
POST   /api/v1/goals/:id/complete       # Mark goal as complete
GET    /api/v1/goals/:id/progress       # Get goal progress
GET    /api/v1/goals/:id/milestones     # Get goal milestones
POST   /api/v1/goals/:id/milestones     # Create milestone
GET    /api/v1/goals/:id/tasks          # Get linked tasks
GET    /api/v1/goals/:id/insights       # Get AI insights
```

#### 8.1.5 Habit Endpoints

```
GET    /api/v1/habits                   # List all habits
POST   /api/v1/habits                   # Create new habit
GET    /api/v1/habits/:id               # Get habit by ID
PATCH  /api/v1/habits/:id               # Update habit
DELETE /api/v1/habits/:id               # Delete habit
POST   /api/v1/habits/:id/complete      # Mark habit complete for today
GET    /api/v1/habits/:id/completions   # Get completion history
GET    /api/v1/habits/:id/stats         # Get habit statistics
GET    /api/v1/habits/:id/insights      # Get AI insights
```

#### 8.1.6 Calendar Endpoints

```
GET    /api/v1/calendar/events          # List calendar events
POST   /api/v1/calendar/events          # Create event
GET    /api/v1/calendar/events/:id      # Get event by ID
PATCH  /api/v1/calendar/events/:id      # Update event
DELETE /api/v1/calendar/events/:id      # Delete event
POST   /api/v1/calendar/sync            # Trigger calendar sync
GET    /api/v1/calendar/availability    # Get availability
```

#### 8.1.7 AI Assistant Endpoints

```
POST   /api/v1/ai/chat                  # Chat with AI assistant
POST   /api/v1/ai/parse-task            # Parse natural language task
POST   /api/v1/ai/estimate-duration     # Estimate task duration
POST   /api/v1/ai/prioritize            # Get AI prioritization
POST   /api/v1/ai/schedule              # Get AI scheduling suggestions
GET    /api/v1/ai/daily-briefing        # Get daily briefing
POST   /api/v1/ai/goal-suggestions      # Get goal action suggestions
POST   /api/v1/ai/habit-analysis        # Analyze habit patterns
```

#### 8.1.8 Integration Endpoints

```
GET    /api/v1/integrations             # List all integrations
POST   /api/v1/integrations/google      # Connect Google
POST   /api/v1/integrations/slack       # Connect Slack
POST   /api/v1/integrations/notion      # Connect Notion
DELETE /api/v1/integrations/:id         # Disconnect integration
POST   /api/v1/integrations/:id/sync    # Trigger sync
GET    /api/v1/integrations/:id/status  # Get sync status
```

#### 8.1.9 Analytics Endpoints

```
GET    /api/v1/analytics/overview       # Get analytics overview
GET    /api/v1/analytics/productivity   # Get productivity metrics
GET    /api/v1/analytics/goals          # Get goal analytics
GET    /api/v1/analytics/habits         # Get habit analytics
GET    /api/v1/analytics/time           # Get time tracking analytics
GET    /api/v1/analytics/insights       # Get AI insights
```

### 8.2 API Request/Response Examples

#### 8.2.1 Create Task

**Request:**
```http
POST /api/v1/tasks
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Finish Q2 product roadmap",
  "description": "Complete the product roadmap for Q2 including feature prioritization and timeline",
  "priority": "high",
  "dueDate": "2026-04-30T17:00:00Z",
  "estimatedMinutes": 240,
  "tags": ["work", "product", "planning"],
  "projectId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:**
```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "userId": "user-123",
  "title": "Finish Q2 product roadmap",
  "description": "Complete the product roadmap for Q2 including feature prioritization and timeline",
  "status": "todo",
  "priority": "high",
  "dueDate": "2026-04-30T17:00:00Z",
  "estimatedMinutes": 240,
  "actualMinutes": null,
  "tags": ["work", "product", "planning"],
  "projectId": "550e8400-e29b-41d4-a716-446655440000",
  "aiPriorityScore": 92.5,
  "energyLevel": "high",
  "createdAt": "2026-04-21T15:00:00Z",
  "updatedAt": "2026-04-21T15:00:00Z"
}
```

#### 8.2.2 Get AI-Prioritized Tasks

**Request:**
```http
GET /api/v1/tasks/prioritized
Authorization: Bearer <access_token>
```

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "tasks": [
    {
      "id": "task-1",
      "title": "Finish Q2 product roadmap",
      "priority": "high",
      "dueDate": "2026-04-30T17:00:00Z",
      "aiPriorityScore": 95.2,
      "reasoning": "Due in 9 days, high impact on Q2 goals, requires deep work"
    },
    {
      "id": "task-2",
      "title": "Review design mockups",
      "priority": "medium",
      "dueDate": "2026-04-25T12:00:00Z",
      "aiPriorityScore": 87.3,
      "reasoning": "Due in 4 days, blocking designer, quick review"
    }
  ],
  "recommendations": {
    "focusTime": "09:00-11:00",
    "suggestedOrder": ["task-1", "task-2"],
    "estimatedCompletionTime": "14:30"
  }
}
```

#### 8.2.3 Chat with AI Assistant

**Request:**
```http
POST /api/v1/ai/chat
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "message": "What should I focus on today?",
  "context": {
    "includeCalendar": true,
    "includeTasks": true,
    "includeGoals": true
  }
}
```

**Response (Streaming):**
```http
HTTP/1.1 200 OK
Content-Type: text/event-stream

data: {"type":"start","messageId":"msg-123"}

data: {"type":"content","delta":"Good morning! Based on your schedule and priorities, here's what I recommend:\n\n"}

data: {"type":"content","delta":"1. **Finish Q2 Product Roadmap** (2-3 hours)\n   - This is your top priority due in 9 days\n   - I've blocked 9-11am for deep work\n\n"}

data: {"type":"content","delta":"2. **Team Standup** (30 min at 11am)\n   - Already on your calendar\n\n"}

data: {"type":"content","delta":"3. **Review Design Mockups** (1 hour)\n   - Quick win, unblocks your designer\n\n"}

data: {"type":"end","messageId":"msg-123"}
```

### 8.3 GraphQL API

#### 8.3.1 Schema Definition

```graphql
# schema.graphql

type User {
  id: ID!
  email: String!
  name: String!
  avatarUrl: String
  timezone: String!
  locale: String!
  subscriptionTier: SubscriptionTier!
  preferences: UserPreferences!
  stats: UserStats!
  createdAt: DateTime!
}

type UserPreferences {
  theme: Theme!
  language: String!
  notifications: NotificationPreferences!
  ai: AIPreferences!
  workHours: WorkHours
}

type Task {
  id: ID!
  user: User!
  title: String!
  description: String
  status: TaskStatus!
  priority: Priority!
  dueDate: DateTime
  estimatedMinutes: Int
  actualMinutes: Int
  tags: [String!]!
  project: Project
  goal: Goal
  subtasks: [Task!]!
  aiPriorityScore: Float
  energyLevel: EnergyLevel
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Goal {
  id: ID!
  user: User!
  title: String!
  description: String
  category: String!
  startDate: Date!
  targetDate: Date!
  progress: Float!
  status: GoalStatus!
  milestones: [Milestone!]!
  tasks: [Task!]!
  insights: GoalInsights!
  createdAt: DateTime!
}

type Habit {
  id: ID!
  user: User!
  title: String!
  description: String
  frequency: HabitFrequency!
  currentStreak: Int!
  longestStreak: Int!
  completions: [HabitCompletion!]!
  stats: HabitStats!
  insights: HabitInsights!
  createdAt: DateTime!
}

type Query {
  # User
  me: User!
  
  # Tasks
  tasks(
    status: TaskStatus
    priority: Priority
    projectId: ID
    search: String
    limit: Int
    offset: Int
  ): TaskConnection!
  
  task(id: ID!): Task
  prioritizedTasks: [Task!]!
  upcomingTasks(days: Int): [Task!]!
  overdueTasks: [Task!]!
  
  # Goals
  goals(status: GoalStatus): [Goal!]!
  goal(id: ID!): Goal
  
  # Habits
  habits(status: HabitStatus): [Habit!]!
  habit(id: ID!): Habit
  
  # Calendar
  calendarEvents(
    startDate: DateTime!
    endDate: DateTime!
  ): [CalendarEvent!]!
  
  # Analytic