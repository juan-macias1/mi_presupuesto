# Learning Path

A self-directed roadmap for the skills needed to take Mi Presupuesto from its current state (Stage 1) through the ML phase (Stage 2) and into the LLM phase (Stage 3).

## Context

I am starting this path with no formal background in machine learning or AI. I have working Flutter and Dart skills, acquired by building this project, and the practical engineering instincts that come from writing production code. Everything else, I will learn as the project demands it.

This document is the map I follow. It will change as I progress.

## Principles

**Project-driven, not curriculum-driven.** I learn what the next stage of the project demands, when it demands it. I do not "complete" topics before touching them. The project is the gym; the resources below are the training plan.

**Just enough math, not formal coursework.** I will not take a years-long detour through textbooks. I will pick up the math I need to use specific algorithms or models, with intuition first and depth later, only when depth is actually required.

**Build a small thing alongside each topic.** For every concept I study, I write something tiny that uses it. A toy notebook, a five-line script, a one-screen demo. Reading without making does not stick.

**One DEVLOG entry per study session.** What I read, what I built, what clicked, what did not.

## Stage 0 — Now to Month 3: software fundamentals I will use this week

| Topic | Why | Resource |
|---|---|---|
| Dart fluency: types, async, classes, generics | Every line of the app is in Dart | [dart.dev/language](https://dart.dev/language) |
| Flutter widget composition and state | The UI layer is the next milestone in this project | [docs.flutter.dev/ui](https://docs.flutter.dev/ui) |
| Git: branches, merges, rebase, PR workflow | Beyond commits, this is how real teams work | [learngitbranching.js.org](https://learngitbranching.js.org) |
| Software design patterns: Singleton, Repository, dependency injection | I recognize these by name in the code I already write | "Clean Code" by Robert C. Martin |
| Basic statistics intuition: mean, median, variance, distribution | Foundation for every ML concept later | [StatQuest YouTube channel](https://www.youtube.com/@statquest) — "Statistics Fundamentals" playlist |

## Stage 1 — Months 3 to 6: Python, data, and the bridge to ML

Python is needed from Stage 2 onward (the FastAPI microservice). Starting now means I am not learning a new language under pressure later.

| Topic | Why | Resource |
|---|---|---|
| Python basics: types, control flow, functions, classes | Same role Dart plays today | ["Automate the Boring Stuff with Python"](https://automatetheboringstuff.com), free online |
| Python data tools: NumPy and pandas | The standard way to manipulate tabular data | [Kaggle's Pandas micro-course](https://www.kaggle.com/learn/pandas), free, ~5 hours |
| Visualization with matplotlib | Read data, debug data, communicate data | [Matplotlib Pyplot tutorial](https://matplotlib.org/stable/tutorials/pyplot.html) |
| Probability intuition | Most ML rests on probabilistic reasoning | StatQuest "Statistics Fundamentals" playlist, continued |
| Bayes' theorem in practical terms | Inference, classification, language models depend on it | 3Blue1Brown — ["Bayes theorem"](https://www.youtube.com/watch?v=HZGCoVF3YvM) |

End-of-stage check: I can load a CSV in Python, clean it, plot the distribution of any column, and explain in plain language what mean, median, and standard deviation tell me about a dataset.

## Stage 2 — Months 6 to 12: classical machine learning applied to my own data

This is when the project starts producing real data and Mi Presupuesto enters its ML phase. The roadmap calls for six algorithms; I learn each one as it comes up, not all at once.

| Topic | Why | Resource |
|---|---|---|
| scikit-learn basics: fit, predict, the API | The standard library | [scikit-learn 5-minute intro](https://scikit-learn.org/stable/tutorial/basic/tutorial.html) |
| Z-Score for outlier detection | First algorithm in my roadmap | StatQuest "Z-Scores", then implement on my own movements |
| Exponential smoothing (ETS) | Better projections than averages | [Forecasting: Principles and Practice](https://otexts.com/fpp3/) chapters 7 and 8, free book |
| K-Means clustering | Group my spending into behavioral patterns | StatQuest "K-means clustering" |
| Pearson correlation | Find which categories move together | StatQuest "Pearson's correlation" |
| Logistic regression | Estimate probability of meeting financial goals | StatQuest "Logistic regression" series |
| ARIMA, simplified | Real time-series forecasting | "Forecasting: Principles and Practice" chapter 9 |
| FastAPI: build a REST microservice | The serving layer for these algorithms | [FastAPI tutorial](https://fastapi.tiangolo.com/tutorial/), worked linearly |
| PostgreSQL basics | The Stage 2 database | [PostgreSQL Tutorial](https://www.postgresqltutorial.com/) |
| Docker basics | Deploying the microservice | [Docker Get Started](https://docs.docker.com/get-started/), first three sections |

End-of-stage check: I can take a question about my own finances ("am I spending more on food than I should?"), pick the right statistical tool to answer it, implement it in Python, and serve the result through FastAPI to the Flutter app.

## Stage 3 — Months 12 to 18: deep learning fundamentals

The bridge between classical ML and language models. I do not have to master everything, but I have to understand how neural networks work end to end.

| Topic | Why | Resource |
|---|---|---|
| What a neural network actually is | Foundation for everything that follows | [3Blue1Brown — Neural Networks](https://www.3blue1brown.com/topics/neural-networks), 4-video series |
| Backpropagation and gradient descent | How models learn | Same 3Blue1Brown series, videos 3 and 4 |
| PyTorch basics | The framework for the rest of the journey | [PyTorch official tutorials](https://pytorch.org/tutorials/), "Learn the Basics" track |
| Build a tiny neural net from scratch, no library | Reading is not the same as making | Karpathy — ["The spelled-out intro to neural networks and backprop"](https://www.youtube.com/watch?v=VMj-3S1tku0), 2.5 hours |
| Embeddings: words as vectors | Foundation of how LLMs understand text | Karpathy — "Building makemore" parts 1 and 2 |
| Tokenization | How text becomes numbers a model can chew | Karpathy — "Let's build the GPT tokenizer" |

End-of-stage check: I can read a model's architecture diagram, explain how a single training step works, and have built a small neural network from scratch in PyTorch.

## Stage 4 — Month 18 and beyond: LLMs and fine-tuning

The endgame. Here I take everything that came before and use it to fine-tune my own financial language model on the data Mi Presupuesto has been collecting.

| Topic | Why | Resource |
|---|---|---|
| Transformer architecture | The shape of every modern LLM | Karpathy — ["Let's build GPT: from scratch, in code, spelled out"](https://www.youtube.com/watch?v=kCc8FmEb1nY) |
| Hugging Face Transformers library | Standard tool to load and run open models | [Hugging Face Course](https://huggingface.co/learn/nlp-course), free |
| Fine-tuning with LoRA | The technique I will use on Llama 3 | [PEFT library docs](https://huggingface.co/docs/peft/) plus [the LoRA paper](https://arxiv.org/abs/2106.09685), read with help to unpack |
| Datasets and tokenizers in Hugging Face | Preparing my own data for training | [Hugging Face Datasets docs](https://huggingface.co/docs/datasets/) |
| Evaluation: how do I know my model is actually good? | Without metrics, I am guessing | Hugging Face Course chapter on evaluation |
| Ollama: serve the trained model locally | Deployment for Stage 3 of the product | [Ollama documentation](https://ollama.com/) |

End-of-stage check: I have published a financial language model on Hugging Face, trained on 18 months of Colombian personal finance behavior, and it is the inference layer of Mi Presupuesto.

## Cadence and habits

- Six to eight hours per week on the project itself, the actual code.
- Two to three hours per week on the resources above, ideally split across two short sessions rather than one long one.
- One to two hours per week communicating what I learned: writing DEVLOG entries, drafting LinkedIn posts, replying to people who comment on the repo.

If something has to give in a given week, I cut from the resources first, not from the project.

## Notes to my future self

The hard part is not the math or the syntax. The hard part is showing up consistently, week after week, when nothing visible is happening yet. Most projects die in the gap between "started" and "interesting". Stage 1 to Stage 2 is the slow middle. Stage 3 is where the work being done now actually pays.

There will be moments where the resources feel like noise and the project feels stuck. That is normal. Step back, write a DEVLOG entry that names what is stuck, and pick the smallest possible next step.
