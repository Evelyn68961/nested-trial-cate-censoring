# Lesson 8: what dropout does

Goes with Phase 2: dropout settings in `config/phase2.yaml`; estimators CC and NE in `R/phase2_estimators.R`.

## The problem

Some trial patients leave before 5 years: they move, withdraw consent, or stop attending. For a patient who left at year 2 without an event, we know they were event-free at year 2. We do not know whether they had the event by year 3.

The paper assumes nobody leaves. CASS happened to have complete follow-up to 10 years. Most trials do not.

## Three kinds of dropout in the simulation

- **C1, random:** everyone has the same chance of leaving: a hazard of 0.08 a year (about 7.7% leave each year). About a quarter of trial patients leave before 5 years.
- **C2, dependent:** frail patients leave sooner, and so do treated patients (think side effects). Frail patients also have more events and benefit less from the drug. So the patients who leave are not like those who stay.
- **C3:** the same patients as C2, but the analysis uses a dropout model that leaves out frailty. It tests what happens when you model dropout wrongly.

## The two obvious fixes, and why both fail

**Drop them (CC, complete case).** Analyse only patients whose status at year 3 is known.
But the dropped patients were event-free for a while: they survived part of the time. Removing them removes event-free time, so the risk comes out too high. Under dependent dropout it gets worse in less predictable ways: the frail patients who left had more events ahead of them, which pulls the other way. The two can even cancel by chance, as one of our tests found.

**Count them as event-free (NE, treated as non-event).** Pretend nothing happened after they left.
Some of them would have had the event. So the risk comes out too low, more so the longer the follow-up.

Both distort the effect, not only the risk, whenever dropout differs between the arms. In C2 treated patients leave more often, so the two arms are distorted by different amounts.

## Check yourself

1. A patient left at year 2 with no event. What do we know about them at year 1? At year 3?
2. Why does counting dropouts as event-free make the risk look too low?
3. Why does it matter that treated patients drop out more often in C2?
