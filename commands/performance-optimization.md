---
description: Review code for performance bottlenecks and report each issue with its location, impact, and a fix.
argument-hint: <code or path>
---

# Performance Optimization

Analyze the code below for performance bottlenecks and optimization opportunities. Cover the areas that apply to this code (data access, algorithmic complexity, memory, async and concurrency, network and I/O, frontend rendering, caching) and skip the ones that don't.

## Output Format

For each issue identified:
1. **Issue**: Describe the performance problem
2. **Location**: Specify file/function/line numbers
3. **Impact**: Rate severity (Critical/High/Medium/Low) and explain expected performance degradation
4. **Current Complexity**: Include time/space complexity where applicable
5. **Recommendation**: Provide specific optimization strategy
6. **Code Example**: Show optimized version when possible
7. **Expected Improvement**: Quantify performance gains if measurable

If code is well-optimized:
- Confirm optimization status
- List performance best practices properly implemented
- Note any minor improvements possible

**Code to review:**
```
$ARGUMENTS
```