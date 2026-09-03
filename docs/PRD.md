# Breathwork App: Product Requirements Document & Technical Handoff

## 1. Product Overview & Vision

This application is designed to train and improve the user's VO2 max and
absolute breath-holding capacity strictly through guided breathing
protocols. By bridging physiological training with accessible, interactive
timers, this tool serves a dual target audience:

- **Athletes:** Seeking higher VO2 max, delayed respiratory muscle fatigue,
  and endurance optimization.
- **Vocalists & Performers:** Seeking subglottic pressure control, CO2
  tolerance, and extended single-breath vocalization.

## 2. Scientific Foundation & Core Mechanisms

The app's workout logic is built upon three proven physiological
mechanisms. This information should be utilized in the app's educational
onboarding and daily tooltip copy.

- **Delaying the Respiratory Metaboreflex:** Strengthening respiratory
  muscles (like the diaphragm) delays the threshold where the brain shunts
  blood away from the limbs and back to the lungs, allowing athletes to
  maintain peripheral power output longer.
- **Building CO2 Tolerance:** The urge to breathe is driven by carbon
  dioxide buildup, not oxygen depletion. Desensitizing the brain's
  chemoreceptors to CO2 prevents panic responses, aiding both vocalists
  holding notes and athletes during high-intensity exertion.
- **Intermittent Hypoxic Training (IHT):** Pushing through air hunger safely
  drops SpO2. This acute hypoxia stimulates the spleen to release stored red
  blood cells and encourages natural Erythropoietin (EPO) production,
  physically increasing the blood's oxygen-carrying capacity (VO2 max).

## 3. Baseline Assessments (Onboarding Logic)

Users must complete an initial assessment to define their starting state.
These metrics will drive the personalized difficulty of their training
tables.

| Test Name | Physiological Target | App Execution / Instructions |
| --- | --- | --- |
| The BOLT Score (Body Oxygen Level Test) | CO2 Tolerance | Rest quietly. Normal inhale, normal exhale. Pinch nose and start timer. Stop at the first physical urge to swallow or breathe. (Normal ~25s; Elite 40s+). |
| Max Breath Hold (Apnea) | Hypoxic Tolerance | Take 3 deep breaths. On the final inhale, fill lungs to 100% capacity and hold. Timer stops when the user is forced to exhale and gasp. |
| Single Breath Count | Vocal Breath Control | Inhale fully. Start timer. User counts out loud at a steady pace ("1, 2, 3...") on a single continuous exhale until lungs are completely empty. |

## 4. Core Training Protocols (Workout Library)

The workout engine will generate sequences based on these four core pillars.

### A. The CO2 Tolerance Builder (Cadence Breathing)

- **Goal:** Desensitize chemoreceptors to CO2 buildup.
- **App Flow:** Visual pacer (expanding/contracting circle). Base ratio is
  4s inhale, 6s hold, 4s exhale, 6s hold.
- **Progression:** The hold durations scale upward dynamically as the user's
  bi-weekly BOLT score improves.

### B. Hypoxic Sprints (Active Breath Holds)

- **Goal:** Trigger spleen contraction and EPO release for VO2 max expansion.
- **App Flow:** Audio-guided walking workout. Prompt: "Exhale fully, pinch
  your nose, and walk for X paces." (X = calculated by app). Followed by a
  1-minute normal breathing recovery. Repeat 5-10 times.

### C. Apnea Tables (O2 and CO2 Engine)

- **Goal:** Push absolute breath-holding limits for singers and aquatic
  athletes.
- **CO2 Tables logic:** Breath-hold time remains constant (e.g., 50% of
  max). Recovery breathing time between holds shrinks linearly (e.g., 2:00,
  1:45, 1:30, 1:15).
- **O2 Tables logic:** Recovery breathing time remains constant (e.g.,
  2:00). Breath-hold time increases linearly.

### D. Inspiratory Muscle Training (IMT)

- **Goal:** Diaphragmatic hypertrophy.
- **App Flow:** Guide user to create physical manual resistance (e.g.,
  pursed lips or breathing through a straw) for 3 sets of 15 forceful
  inhalations. Track sets and reps.

## 5. Functional Specifications: The Dynamic Timer Engine

The core interactive feature requires a dynamic calculation engine. Below is
the pseudo-code and logic structure for the Apnea Table generator to hand
off to the development environment.

```js
// Input Parameters
let userMaxHold = getBaselineApneaScore(); // e.g., 90 seconds
let targetCycles = 6;

// CO2 Table Generation Logic
function generateCO2Table(maxHold, cycles) {
   let targetHold = maxHold * 0.50; // Constant hold at 50% max
   let initialRest = 120; // Starts at 2 minutes
   let restDecrement = 15; // Drops 15s each round

   let tableData = [];
   for (let i = 1; i <= cycles; i++) {
       let cycleRest = initialRest - ((i - 1) * restDecrement);
       tableData.push({
           cycle: i,
           breatheTime: Math.max(cycleRest, 15), // Floor of 15s
           holdTime: targetHold
       });
   }
   return tableData;
}
```

The UI should bind this generated array to an animated timer view,
utilizing visual cues (expanding/contracting elements) and audio cues to
guide the user seamlessly through the generated phases without requiring
them to look at the screen.
