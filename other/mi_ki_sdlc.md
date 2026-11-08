To solve this project management problem, we first need to determine the
Critical Path (the longest duration path) to find the normal project duration
and the Initial Cost. Then, we can calculate the crashing cost slopes ($K_i$)
and determine the most cost-effective way to reduce the project time.

### **Step 1: Network Diagram and Critical Path Analysis**

First, let's identify the paths and their durations based on the predecessors:

*   **Path 1:** $A \rightarrow C \rightarrow D \rightarrow E \rightarrow F \rightarrow H$
    *   Duration: $3 + 2 + 5 + 4 + 3 + 3 = 20$ weeks
*   **Path 2:** $A \rightarrow C \rightarrow G \rightarrow H$
    *   Duration: $3 + 2 + 9 + 3 = 17$ weeks
*   **Path 3:** $B \rightarrow D \rightarrow E \rightarrow F \rightarrow H$
    *   Duration: $6 + 5 + 4 + 3 + 3 = 21$ weeks
*   **Path 4:** $B \rightarrow G \rightarrow H$
    *   Duration: $6 + 9 + 3 = 18$ weeks

**Critical Path:** Path 3 ($B \rightarrow D \rightarrow E \rightarrow F \rightarrow H$)
**Normal Project Duration ($T_0$):** **21 weeks**
**Initial Normal Cost:** Sum of all normal costs.
$900 + 2000 + 500 + 1800 + 1500 + 3000 + 8000 + 1000 = \mathbf{18,700}$

---

### **Part a. Find $M_i$ and $K_i$ for each activity**

*   $M_i$ (Maximum time reduction or "Crash Amount") = Normal Time - Crashing Time
*   $K_i$ (Crash Cost Slope) = $\frac{\text{Crashing Cost} - \text{Normal Cost}}{M_i}$

| Activity | Predecessors | Normal Time | Crash Time | Max Reduction ($M_i$) | Normal Cost | Crashing Cost | Cost Difference | Slope ($K_i$) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A** | - | 3 | 1 | $3 - 1 = 2$ | 900 | 1700 | 800 | $800 / 2 = \mathbf{400}$ |
| **B** | - | 6 | 3 | $6 - 3 = 3$ | 2000 | 4000 | 2000 | $2000 / 3 \approx \mathbf{666.67}$ |
| **C** | A | 2 | 1 | $2 - 1 = 1$ | 500 | 1000 | 500 | $500 / 1 = \mathbf{500}$ |
| **D** | B, C | 5 | 3 | $5 - 3 = 2$ | 1800 | 2400 | 600 | $600 / 2 = \mathbf{300}$ |
| **E** | D | 4 | 3 | $4 - 3 = 1$ | 1500 | 1850 | 350 | $350 / 1 = \mathbf{350}$ |
| **F** | E | 3 | 1 | $3 - 1 = 2$ | 3000 | 3900 | 900 | $900 / 2 = \mathbf{450}$ |
| **G** | B, C | 9 | 4 | $9 - 4 = 5$ | 8000 | 9800 | 1800 | $1800 / 5 = \mathbf{360}$ |
| **H** | F, G | 3 | 2 | $3 - 2 = 1$ | 1000 | 2000 | 1000 | $1000 / 1 = \mathbf{1000}$ |

---

### **Part b. How many weeks will this project be taken?**

Based on the Critical Path Analysis in Step 1, the project will take the duration of the longest path.

**Answer:** The project will take **21 weeks**.

---

### **Part c. Calculate the cost of this project after lowering the time**

To answer this, we must crash the project. We will crash the project by **1 week**
at a time, choosing the cheapest activity on the Critical Path, until we reach
a logical stopping point or a specific target time is reached. Since no specific
target time was given in the screenshot, I will demonstrate the process to reduce
the project by **2 weeks** (a common requirement in such problems) and provide the
formula for any reduction.

**Current Status:**
*   Duration: 21 weeks
*   Critical Path: $B - D - E - F - H$
*   Cost: 18,700

**Iteration 1: Reduce Project by 1 Week (Target: 20 Weeks)**
*   We look at activities on the Critical Path ($B, D, E, F, H$).
*   We choose the one with the lowest slope ($K_i$).
    *   $B: 666.67$
    *   $D: 300$ (Lowest)
    *   $E: 350$
    *   $F: 450$
    *   $H: 1000$
*   **Action:** Crash Activity **D** by 1 week.
*   **New Duration:** 20 weeks.
*   **New Cost:** $18,700 + 300 = \mathbf{19,000}$.
*   *Check Paths:*
    *   Path 1 ($A-C-D-E-F-H$): Was 20, D reduced by 1 $\rightarrow$ **19 weeks**.
    *   Path 3 ($B-D-E-F-H$): Was 21, D reduced by 1 $\rightarrow$ **20 weeks**.
    *   Path 4 ($B-G-H$): 18 weeks.
    *   **Critical Path remains Path 3.**

**Iteration 2: Reduce Project by Another Week (Target: 19 Weeks)**
*   Current Critical Path: $B - D - E - F - H$ (20 weeks).
*   Note: Path 1 is now 19 weeks. If we reduce Path 3 by another week, Path 1 might become critical too.
*   Available reductions on Critical Path:
    *   $B$ (2 left), $D$ (1 left), $E$ (1 left), $F$ (2 left), $H$ (1 left).
    *   Cheapest single activity is $D$ (300), but $D$ only has 1 week left. Let's check if crashing $D$ again makes Path 1 critical.
    *   If we crash $D$ again (Cost 300): Path 3 becomes 19, Path 1 becomes 18. Path 4 is 18. Path 3 is still alone critical.
*   **Action:** Crash Activity **D** by another 1 week (Total crash 2 weeks).
*   **New Duration:** 19 weeks.
*   **New Cost:** $19,000 + 300 = \mathbf{19,300}$.
*   *Check Paths:*
    *   Path 3 ($B-D-E-F-H$): 19 weeks.
    *   Path 1 ($A-C-D-E-F-H$): 18 weeks.
    *   Path 4 ($B-G-H$): 18 weeks.
    *   **Critical Path remains Path 3.**

**Iteration 3: Reduce Project by Another Week (Target: 18 Weeks)**
*   Current Critical Path: $B - D - E - F - H$ (19 weeks).
*   Path 1 and Path 4 are at 18 weeks. If we reduce Path 3 by 1 week, we might create multiple critical paths.
*   Options to reduce Path 3 by 1 week:
    *   Crash $E$ (Slope 350).
    *   Crash $F$ (Slope 450).
    *   Crash $B$ (Slope 666.67).
    *   Crash $H$ (Slope 1000).
    *   Crash $D$? No, $D$ is fully crashed.
*   Cheapest is **E** (350).
*   **Action:** Crash Activity **E** by 1 week.
*   **New Duration:** 18 weeks.
*   **New Cost:** $19,300 + 350 = \mathbf{19,650}$.
*   *Check Paths:*
    *   Path 3 ($B-D-E-F-H$): $19 - 1 = 18$ weeks.
    *   Path 1 ($A-C-D-E-F-H$): $18 - 1 = 17$ weeks.
    *   Path 4 ($B-G-H$): 18 weeks.
    *   **New Critical Paths:** Path 3 and Path 4 are both critical (18 weeks).

**Summary of Costs for Time Reductions:**

| Project Duration (Weeks) | Crashed Activities | Added Cost | Total Project Cost |
| :---: | :--- | :---: | :---: |
| **21** (Normal) | - | - | **18,700** |
| **20** | D (1 week) | 300 | **19,000** |
| **19** | D (2 weeks total) | 300 | **19,300** |
| **18** | D (2 weeks) + E (1 week) | 350 | **19,650** |

*(Note: If you need to reduce it further to 17 weeks, you would need to crash both Path 3 and Path 4 simultaneously or crash a shared activity like B or H. The next cheapest combination would likely involve crashing B (666.67) which is on both Path 3 and Path 4, or crashing H (1000) which is on both. Crashing B is cheaper.)*

**Final Answer for Cost:**
The cost of the project depends on how much you lower the time.
*   For **20 weeks**, cost is **19,000**.
*   For **19 weeks**, cost is **19,300**.
*   For **18 weeks**, cost is **19,650**.
