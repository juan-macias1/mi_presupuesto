# Mi Presupuesto

A personal budgeting application designed to replace impulsive financial decisions with data-driven analysis, built as the foundation for a long-term machine learning project focused on Colombian personal finance behavior.

**Status:** In active development. Solo project. Started June 2026.

## Purpose

Existing personal finance tools do not account for the Colombian context: local terminology, informal debt structures, and cultural patterns around money. This project addresses that gap, while also serving as the data source for a multi-stage research effort that will conclude with a domain-specific language model.

The project is structured as a three-stage build. The application itself is Stage 1. Real usage over time produces the dataset that enables Stages 2 and 3.

## The three-stage journey

### Stage 1 — Application with Claude API (Months 0 to 6)

The foundation. Flutter with local SQLite storage, using the Claude API as the conversational layer. Every interaction is logged with a quality rating.

Key features:

- Two operating modes that switch automatically based on debt status: Attack mode while debt exists, Freedom mode once total debt reaches zero.
- Fully offline. No Firebase, no cloud dependency.
- Behavioral analysis including spending leak detection, weekend pattern recognition, income-driven spending inflation, and a 0 to 100 financial health score.
- Single source of truth: the `MasterFinancialBrain` singleton produces one `MasterFinancialResult` consumed by both the UI and the AI layer.
- Dataset goal: populate the `conversaciones_ia` table with rated real interactions for use in Stage 2.

### Stage 2 — Application with internal ML (Months 6 to 18)

The transition to autonomy. Classical machine learning algorithms running in a Python FastAPI microservice, progressively taking over tasks where statistical analysis is sufficient.

Algorithms scheduled in implementation order:

| Months | Algorithm | Purpose |
|---|---|---|
| 6 to 8 | Z-Score | Spending anomaly detection |
| 6 to 8 | ETS | Improved monthly projections |
| 8 to 10 | K-Means | Behavioral clustering |
| 10 to 12 | Pearson correlation | Hidden relationships between categories |
| 12 to 15 | Logistic Regression | Probability of meeting financial goals |
| 15 to 18 | ARIMA (simplified) | Time-series forecasting |

Dataset goal by Month 18: 10,000 movement records and 500 rated conversations.

### Stage 3 — Domain-specific LLM (Months 18 to 36)

The differentiator. LoRA fine-tuning on Llama 3 3B using the 18 months of accumulated Colombian financial behavior data. Deployed locally via Ollama and served through the same FastAPI layer.

- Hardware investment: RTX 3060 12GB and 32GB RAM, approximately 380 to 500 USD, one-time.
- Training time: 4 to 5 hours per fine-tuning iteration.
- Evaluation against Claude on Colombian-specific financial questions.
- Replaces the Claude API call within the application.
- Published on Hugging Face as a financial language model trained specifically on Colombian personal finance patterns.

## Technology stack

| Layer | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|
| User interface | Flutter | Flutter | Flutter |
| Local storage | SQLite | SQLite | SQLite |
| Backend | None | Python, FastAPI, PostgreSQL | Python, FastAPI, PostgreSQL |
| ML and AI | Claude API (Sonnet 4) | scikit-learn with Claude API | Llama 3 3B with LoRA, Ollama |
| Infrastructure | None | Hetzner VPS CX32 | Hetzner CAX41 plus local GPU |

## Architecture overview

`MasterFinancialBrain` is a singleton that orchestrates analysis through ten deterministic steps and produces a single `MasterFinancialResult` consumed by the entire user interface. This eliminates inconsistencies between components and provides the AI layer with a complete contextual snapshot in a single call.

Cache invalidation is centralized at the database layer through a static version counter. Any write operation increments it, and the brain compares its cached version against the live counter before returning data.

Detailed architecture documentation is in `ARCHITECTURE.md` (forthcoming).

## Roadmap

The full month-by-month plan is documented in `ROADMAP.md` (forthcoming).

## Development log

Session-by-session technical journal: `DEVLOG.md`.

---

Built in Funza, Cundinamarca, Colombia.