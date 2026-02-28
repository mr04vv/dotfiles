# Code Review Diff Command

Perform a comprehensive code review specifically for changes between main branch and current branch, analyzing only the modified code for quality, best practices, and potential improvements.

## Instructions

Follow these steps to conduct a thorough review of the code changes:

### 1. Change Analysis
- Execute `git diff main...HEAD` to identify all modified files
- Analyze the scope and nature of changes (new features, bug fixes, refactoring)
- Identify which files have been added, modified, or deleted
- Assess the overall impact and complexity of the changes

### 2. Changed Code Quality Assessment
- Scan modified code for code smells, anti-patterns, and potential bugs
- Check for consistent coding style and naming conventions in changed sections
- Identify any unused imports, variables, or dead code introduced
- Review error handling and logging practices in modified areas

### 3. Security Impact
- Look for common security vulnerabilities in the changed code (SQL injection, XSS, etc.)
- Check for any new hardcoded secrets, API keys, or passwords
- Review authentication and authorization logic changes
- Examine input validation and sanitization in modified code

### 4. Performance Impact
- Identify potential performance bottlenecks in the changes
- Check for inefficient algorithms or database queries introduced
- Review memory usage patterns and potential leaks in new code
- Analyze any impact on bundle size and optimization

### 5. Architecture & Design
- Evaluate how changes fit into the existing code organization
- Check for proper abstraction and modularity in modified code
- Review dependency changes and coupling implications
- Assess impact on scalability and maintainability

### 6. Test Requirements
- Identify areas of changed code that need testing
- Check if existing tests need to be updated due to changes
- Review test structure and organization for modified components
- Suggest additional test scenarios for new functionality

### 7. Documentation Updates
- Evaluate if code changes require documentation updates
- Check if API documentation needs to be updated
- Review if README or setup instructions need changes
- Identify areas where inline comments should be added or updated

### 8. Change-Specific Recommendations
- Prioritize issues by severity (critical, high, medium, low)
- Provide specific, actionable recommendations for the changes
- Suggest improvements that align with the existing codebase
- Create a focused summary report with next steps for this changeset

### 9. Output to Markdown File
- After completing the review, save the results to a markdown file
- Use the current date and time in the filename (e.g., `code-review-diff-YYYY-MM-DD-HHMMSS.md`)
- Structure the output with clear sections and proper markdown formatting
- Include a table of contents for easy navigation
- Focus on the specific changes reviewed rather than the entire codebase
- **Write all content in Japanese** - provide the review results in Japanese language

## Usage
```bash
/code-review-diff
```

Remember to focus specifically on the changed code and provide constructive feedback with specific examples, file paths, and line numbers where applicable. Consider how the changes integrate with the existing codebase and maintain consistency with established patterns.