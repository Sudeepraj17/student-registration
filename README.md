# Student Registration — Vercel + Render + Supabase

## 1. Supabase (database)
1. Create a project at supabase.com.
2. Open **SQL Editor → New Query**, paste `schema.sql`, run it.
3. Go to **Project Settings → Database → Connection string** and copy the
   **Connection pooling** URI (port `6543`, host like
   `aws-0-region.pooler.supabase.com`). Use pooled, not the direct `5432`
   connection — Render's free tier opens/closes connections often, and the
   pooler handles that better than a direct Postgres connection.
   Note your **password** (set at project creation, resettable in Database settings).

## 2. Render (backend)
1. Push the `backend/` folder to a GitHub repo.
2. Render dashboard → **New → Web Service** → connect the repo.
3. Settings:
   - **Root Directory:** `backend`
   - **Runtime:** Java
   - **Build Command:** `./mvnw clean package -DskipTests`
   - **Start Command:** `java -jar target/student-registration-1.0.0.jar`
4. **Environment variables** (Render → Environment):
   | Key | Value |
   |---|---|
   | `SPRING_DATASOURCE_URL` | `jdbc:postgresql://aws-0-region.pooler.supabase.com:6543/postgres` |
   | `SPRING_DATASOURCE_USERNAME` | `postgres.your-project-ref` (pooler username format) |
   | `SPRING_DATASOURCE_PASSWORD` | your Supabase DB password |
   | `FRONTEND_URL` | `https://your-app.vercel.app` (set after step 3, or leave as `*` initially) |

   Render sets `PORT` automatically — `application.properties` already reads it.
5. Deploy. Once live, note the backend URL, e.g. `https://student-registration-api.onrender.com`.
   Test it: `curl https://your-service.onrender.com/students` should return `[]`.

## 3. Vercel (frontend)
1. Put `frontend/index.html` in its own repo (or a `frontend/` folder Vercel points at).
2. In `index.html`, set:
   ```js
   const API_BASE_URL = 'https://your-service.onrender.com';
   ```
3. Vercel dashboard → **Add New → Project** → import the repo.
   - No framework/build step needed for a static HTML file — Vercel serves it as-is.
   - If the repo has other files, set **Root Directory** to `frontend`.
4. Deploy. Vercel gives you `https://your-app.vercel.app`.
5. Go back to Render and set `FRONTEND_URL` to that exact Vercel URL, then redeploy the backend so CORS allows it.

## 4. The full request flow
```
Browser (Vercel-hosted index.html)
   │  user clicks "Save Student"
   ▼
fetch('https://your-service.onrender.com/students', { method: 'POST', body: {...} })
   │  crosses the internet — Vercel and Render are separate hosts,
   │  so this is a cross-origin request (that's why CORS/FRONTEND_URL matters)
   ▼
Render: Spring Boot app receives HTTP request
   StudentController → StudentService → StudentRepository (Spring Data JPA)
   │  JPA translates the save() call into SQL
   ▼
Supabase Postgres (via SPRING_DATASOURCE_URL / USERNAME / PASSWORD env vars)
   │  INSERT INTO students ... / SELECT * FROM students
   ▼
Row(s) returned → mapped back to Student objects → serialized to JSON
   ▼
Response travels back through Render → over the internet → back to fetch() in the browser
   ▼
JS updates the DOM (renderStudents) — no page reload
```

**How Spring Boot connects to Supabase:** nothing is hardcoded. `application.properties`
reads `${SPRING_DATASOURCE_URL}`, `${SPRING_DATASOURCE_USERNAME}`, `${SPRING_DATASOURCE_PASSWORD}`
from environment variables, which you set once in Render's dashboard. Spring's
autoconfiguration sees a Postgres driver on the classpath and a datasource URL, and
wires up a HikariCP connection pool automatically — no manual JDBC code needed.

**Why three separate services:** Vercel is optimized for serving static/frontend assets
fast via CDN; Render runs your long-lived JVM process (Vercel doesn't run persistent
backend servers); Supabase is a managed Postgres instance neither of the other two
provides. Each does one job — that's the whole lesson in this stack.
