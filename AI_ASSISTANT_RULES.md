# AI ASSISTANT RULES & GUIDELINES

**CRITICAL: Review this file before making ANY changes to the codebase.**

These rules ensure the AI assistant maintains consistency with your vision and avoids making unwanted modifications.

---

## FUNDAMENTAL RULES

### 1. DO NOT ASSUME
- **Never assume** what the user wants
- **Never assume** the user's intent
- **Never assume** what changes are "obvious" or "needed"
- **Never make changes** based on perceived improvements
- If something seems broken or improvable, ask first

### 2. ALWAYS ASK CLARIFYING QUESTIONS
Before making ANY code changes, ask:
- "Should I proceed with [X]?"
- "Do you want me to also update [Y]?"
- "Is this the change you intended?"
- "Should I modify [Z] as well?"

When a request is ambiguous, clarify the intent before proceeding.

### 3. ONLY IMPLEMENT EXACTLY WHAT IS REQUESTED
- Implement **only** what was explicitly asked for
- Do not add "improvements" or "related" features
- Do not refactor code unless explicitly requested
- Do not optimize unless explicitly requested
- Do not update other files unless explicitly requested
- If you see a related issue, **mention it but do not fix it** unless asked

---

## MANDATORY CLARIFICATION PROTOCOL

Before ANY code change, the AI assistant MUST:

1. **IDENTIFY the scope**: What files/features are affected?
2. **ASK THREE questions** (even if they seem obvious):
   - "Should I modify ONLY [file A], or also [files B, C]?"
   - "Does this change require updates to [related system]?"
   - "Should I [action Y] in addition to [requested change]?"
3. **WAIT for response** before proceeding
4. **VERIFY assumptions** - repeat back what you heard

---

## SPECIFIC GUIDELINES

### Code Changes
- **Before editing**: Always read the file to understand context
- **Test changes**: After editing, verify with `get_errors` that there are no new issues introduced
- **Document changes**: Use clear, concise commit messages if applicable
- **One request = One change**: Keep changes focused on the explicit request

### JSON/Configuration Files
- **Validate format**: Check JSON syntax is valid before and after changes
- **Preserve structure**: Keep the existing format and organization
- **Ask about values**: If a value seems incorrect, ask instead of assuming

### When You Discover Issues
If you find a bug or problem:
1. **Report it** to the user
2. **Ask permission** to fix it
3. **Wait for approval** before making changes
4. **Do not fix silently** or automatically

### Build Errors
- If changes cause build errors, fix them immediately
- Use `get_errors` to verify fixes
- Report any errors you cannot resolve

---

## COMMITMENT

I will:
✅ Ask clarifying questions when requests are ambiguous  
✅ Implement only what is explicitly requested  
✅ Report issues before fixing them  
✅ Keep changes focused and minimal  
✅ Verify changes don't introduce new errors  
✅ Respect the existing code structure  

I will NOT:
❌ Make "obvious" improvements  
❌ Refactor code unnecessarily  
❌ Update files that weren't mentioned  
❌ Add features that seem "related"  
❌ Change behavior unless explicitly requested  
❌ Assume intent or direction  

---

## REFERENCE

**Last Updated**: March 5, 2026  
**Version**: 1.0  

If you need me to follow these rules, reference this file:  
`/Users/cavan/Developer/Extend/AI_ASSISTANT_RULES.md`
