# Persona Builder

Run the PERSONALITIX interactive command-line survey and generate a persona Markdown file.

The survey takes about 5 minutes. It shows question progress, remaining questions, and short examples as you go. Some style questions ask you to choose the closest sentence.

From `C:\Users\Gosia\Desktop\Codex`, run:

```powershell
.\persona-builder\persona-survey.cmd
```

By default, each output is written to the `personas` folder with this naming format:

```text
C:\Users\Gosia\Desktop\Codex\persona-builder\personas\<Persona Name> - <yyyy-MM-dd HH-mm-ss>.md
```

If you leave the first question blank, the persona is named `Anonymous Persona`.

To write the persona somewhere else:

```powershell
.\persona-builder\persona-survey.cmd -OutputPath .\Persona.md
```

The generated Markdown includes:

- a ready-to-use system prompt
- writing and communication rules
- audience and context handling
- language constraints
- a normalized JSON configuration block
