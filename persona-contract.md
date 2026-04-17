# Agent Persona Builder Contract

This folder turns the persona-builder schema intent into a runnable local survey.

The survey should:

- ask one question at a time
- allow multi-select answers where useful
- show short examples for each question
- show short sentence examples for style choices where sentence selection helps
- infer a normalized persona from practical answers
- confirm the inferred profile before writing the final file
- write the persona as a Markdown file inside the `personas` folder
- name the file from the answer to the first question, plus creation date and time
- use `Anonymous Persona` when the first question is left blank

The generated Markdown file contains a human-readable persona plus a normalized JSON block with these top-level sections:

- `schema_version`
- `builder_mode`
- `metadata`
- `survey_profile`
- `persona_profile`
- `behavior_profile`
- `generation_profile`
- `system_prompt_template`

The normalized config follows the structure of the Agent Persona Builder schema provided in the chat.
