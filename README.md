# GitHub Pull Request & Review Scraper

A **Ruby-based data ingestion pipeline** for scraping pull requests, reviews, and repository metadata from the GitHub API using both **REST (Octokit)** and **GraphQL**. Built with **ActiveRecord 7.0**, **PostgreSQL**, and fully compatible with local `.env` configurations.

---

## Features

- **Incremental sync** of pull requests & reviews with timestamp tracking
- **GraphQL + REST hybrid client** with automatic rate limiting and retry logic
- **PostgreSQL-backed relational storage** with proper foreign key relationships
- **`TEST_MODE` support** for development (stops after first page of results)
- **Comprehensive error handling** with SSL retry logic and exponential backoff
- **Secure `.env` based configuration** with GitHub token authentication
- **Efficient upserts & deduplication** to prevent duplicate data
- **Thread-safe user caching** with batch processing for performance
- **Complete database migrations** with proper indexing and constraints
- **Organization-based repository discovery** (defaults to "vercel" organization)

---

## Requirements

- **Ruby** ~> 3.2
- **PostgreSQL** (required - no SQLite support in current implementation)
- **GitHub Personal Access Token (PAT)** with `repo` scope
- **Bundler** for dependency management

---

## Architecture

### Database Schema
- **`repositories`** - GitHub repositories with sync timestamps
- **`users`** - GitHub users (authors, reviewers) with STI disabled
- **`pull_requests`** - PR metadata with GitHub stats (additions, deletions, etc.)
- **`reviews`** - PR reviews with state and submission timestamps

### Services
- **`GitHubRepoImporter`** - Discovers and imports repositories using Octokit REST API
- **`GraphqlPullRequestImporter`** - Fetches PRs and reviews using GitHub GraphQL API
- **`GitHubRateLimiter`** - Monitors and enforces API rate limits
- **`GitHubGraphqlClient`** - Custom GraphQL client with retry logic
- **`GitHubUserHelper`** - Efficient user caching and batch processing

---

## Setup

1. **Clone the repository**
    ```bash
    git clone https://github.com/bobhampton/GitHub-Scraper.git
    cd GitHub-Scraper
    ```

2. **Install dependencies**
    ```bash
    bundle install
    ```

3. **Configure environment**

    Create a `.env` file in the project root:

    ```env
    GITHUB_TOKEN=your_github_personal_access_token
    GITHUB_ORG=your_target_organization
    PGUSER=your_postgres_username
    PGPASSWORD=your_postgres_password
    PGDATABASE=github_scraper_dev
    TEST_MODE=true
    ```

    > **⚠️ Security Note**: Keep your `.env` file secret and never commit it to version control!

4. **Set up PostgreSQL database**
    ```bash
    createdb github_scraper_dev
    ruby db/migrate_runner.rb
    ```

---

## Usage

### Basic Usage
Run the complete data pipeline:

```bash
ruby main.rb
```

This will:
1. Import all repositories from the configured organization (default: "vercel", configurable via GITHUB_ORG)
2. For each repository, fetch all pull requests and their reviews
3. Store everything in the PostgreSQL database with proper relationships

### Test Mode
For development and testing, set `TEST_MODE=true` in your `.env` file. This will:
- Stop after processing the first page of results
- Reduce API calls for faster testing cycles

### Rate Limiting
The scraper automatically handles GitHub API rate limits:
- Monitors remaining quota before each batch of requests
- Automatically sleeps when approaching limits
- Uses exponential backoff for retry logic

---

## Database Structure

The application creates these tables through migrations:

- **repositories**: Stores GitHub repository metadata
- **users**: GitHub users with unique login constraints  
- **pull_requests**: PR data with repository and author relationships
- **reviews**: PR review data linked to pull requests and reviewers

All tables include proper foreign key constraints and indexes for performance.

---

## Configuration

### Environment Variables
- `GITHUB_TOKEN`: Your GitHub Personal Access Token (required)
- `GITHUB_ORG`: Target GitHub organization (optional, defaults to "vercel")
- `PGUSER`: PostgreSQL username
- `PGPASSWORD`: PostgreSQL password (optional for local development)
- `PGDATABASE`: PostgreSQL database name (optional, defaults to "github_scraper_dev")
- `TEST_MODE`: Set to "true" for development mode

### Customization
The target organization is now configurable via the `GITHUB_ORG` environment variable. If not set, it defaults to "vercel".

---

## Error Handling

The application includes comprehensive error handling:
- SSL/network errors with automatic retry
- GraphQL rate limit detection and backoff
- Database constraint violations
- Logging to `log/import_errors.log`

---

## Dependencies

Core gems used:
- **activerecord** (~> 7.0) - Database ORM
- **pg** - PostgreSQL adapter
- **octokit** - GitHub REST API client
- **dotenv** - Environment variable management

See `Gemfile.lock` for complete dependency tree.

---

## Development

### Adding New Data Fields
1. Create a new migration in `db/migrate/`
2. Update the corresponding model in `models/`
3. Modify the importer services to capture the new data

### Debugging
- Set verbose logging in `GitHubGraphqlClient`
- Check `log/import_errors.log` for detailed error traces
- Use `pry` for interactive debugging (included in Gemfile)

---

## License

This project is part of a coding challenge and is for educational purposes.
