# .gitignore

```
# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.

# dependencies
/node_modules
/.pnp
.pnp.js

# testing
/coverage

# next.js
/.next/
/out/

# production
/build

# misc
.DS_Store
*.pem

# debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# local env files
.env.local
.env.development.local
.env.test.local
.env.production.local

# vercel
.vercel

**/*.trace
**/*.zip
**/*.tar.gz
**/*.tgz
**/*.log
package-lock.json
**/*.bun
```

# install.sh

```sh
#!/bin/bash

TARGET="$HOME/.local/bin/cdcs"

mkdir -p "$(dirname "$TARGET")"
cp src/cli/cdcs.sh "$TARGET"
chmod +x "$TARGET"

echo "✅ Installed 'cdcs' to $TARGET"
echo "ℹ️  Make sure ~/.local/bin is in your PATH"

```

# package.json

```json
{
  "name": "DCS",
  "version": "1.0.50",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1",
    "dev": "bun run --watch src/index.ts",
    "start": "bun run src/index.ts"
  },
  "dependencies": {
    "@elysiajs/cors": "^1.3.3",
    "elysia": "latest"
  },
  "devDependencies": {
    "bun-types": "latest"
  },
  "module": "src/index.js"
}

```

# README.md

```md

\`\`\``md
# cdcs – Cross-Device Clipboard Sync

`cdcs` is a personal tool that syncs clipboard text between a web app and a command-line interface for quick copy-paste access across devices.

## ✨ Features

- Sync clipboard text from a mobile device or web app to your desktop
- View and select past clipboard entries from the CLI
- Automatically copies selected text to your system clipboard

## ⚙️ Requirements

- [`wl-copy`](https://github.com/bugaevc/wl-clipboard) (Wayland clipboard tool)
- `curl`
- `jq`

## 📦 Installation

Just drop it in your `~/.local/bin`:

\`\`\`bash
curl -o ~/.local/bin/cdcs https://raw.githubusercontent.com/your-username/cdcs/main/cdcs
chmod +x ~/.local/bin/cdcs
\`\`\``

Make sure `~/.local/bin` is in your `$PATH`.

## 📱 Send from Your Phone

Use the web app to send clipboard text:
👉 [https://cdcs-clipboard.vercel.app](https://cdcs-clipboard.vercel.app)

The web app connects to the backend (deployed via Render) and pushes your text for retrieval.

## 🖥 Usage

Run it in your terminal:

\`\`\`bash
cdcs
\`\`\`

It will fetch recent entries from your web app and show a list.
Pick one, and it will be copied to your clipboard via `wl-copy`.

---

> This project is private and built for personal use.


```

# render.yaml

```yaml
services:  
  - type: web
    name: CDCS Clipboard
    runtime: node
    repo: https://github.com/Sophistiqq/cdcs-backend
    plan: free
    envVars:
    - key: BUN_VERSION
      value: 1.1.0
    region: oregon
    buildCommand: bun install
    startCommand: bun start
version: "1"

```

# src/cli/cdcs.sh

```sh
#!/bin/bash

CLIPBOARD_URL="http://localhost:3000/clipboard"
FILES_URL="http://localhost:3000/files"
DOWNLOAD_DIR="$HOME/Downloads/cdcs"

mkdir -p "$DOWNLOAD_DIR"

# Fetch clipboard and files
clipboard=$(curl -s "$CLIPBOARD_URL")
files=$(curl -s "$FILES_URL")

clipboard="${clipboard:-[]}"
files="${files:-[]}"

clipboard_count=$(echo "$clipboard" | jq 'length // 0')
files_count=$(echo "$files" | jq 'length // 0')

if [ "$clipboard_count" -eq 0 ] && [ "$files_count" -eq 0 ]; then
  echo "❌ No data found."
  exit 1
fi

# Format clipboard entries
formatted_clipboard=$(echo "$clipboard" | jq -r '
  .[] | select(.text) | "[Clipboard] \(.time | todateiso8601) | \(.text | gsub("\n"; " ") | .[0:80])"
')

# Format file entries
formatted_files=$(echo "$files" | jq -r '
  .[] | "[File] \(.name)"
')

# Combine
combined=$(printf "%s\n%s" "$formatted_clipboard" "$formatted_files")

# Select
selected=$(echo "$combined" | fzf --prompt="Select item: ")

[ -z "$selected" ] && echo "❌ Cancelled." && exit 1

# Handle clipboard
if [[ "$selected" == "[Clipboard]"* ]]; then
  timestamp=$(echo "$selected" | cut -d'|' -f1 | sed 's/\[Clipboard\] //g' | xargs)
  text=$(echo "$clipboard" | jq -r --arg ts "$timestamp" '.[] | select((.time | todateiso8601) == $ts) | .text')
  echo -n "$text" | wl-copy
  echo "📋 Copied clipboard text!"
fi

# Handle file
if [[ "$selected" == "[File]"* ]]; then
  filename=$(echo "$selected" | sed 's/\[File\] //')
  url="${FILES_URL%/}/$filename"
  curl -s "$url" -o "$DOWNLOAD_DIR/$filename"
  echo "📁 Downloaded to $DOWNLOAD_DIR/$filename"
fi

```

# src/index.ts

```ts
import { Elysia, t } from "elysia";
import cors from "@elysiajs/cors";
import { file } from "bun";

const port = process.env.PORT || 3000;

// 👇 In-memory clipboard array
const clips: { text: string; time: number }[] = [];

function getClips() {
  return clips.slice(0, 20);
}

function addClip(text: string) {
  clips.unshift({ text, time: Date.now() });
  if (clips.length > 20) clips.length = 20;
}

const app = new Elysia()
  .use(cors())
  .get("/", () => "Hello, the app is running")
  .post(
    "/clipboard",
    ({ body }) => {
      const { text } = body;
      addClip(text);
      return "OK";
    },
    {
      body: t.Object({
        text: t.String(),
      }),
    }
  )
  .get("/clipboard", () => {
    return getClips();
  })
  .post("/upload", async ({ body }) => {
    const buffer = await body.file.arrayBuffer()
    const filename = body.file.name;

    await Bun.write(`./uploads/${filename}`, Buffer.from(buffer))

    return {
      message: "File Uploaded Successfully", name: filename
    }
  }, {
    body: t.Object({
      file: t.File()
    })
  })
  // 1. File list
  .get("/files", () => {
    const dir = "./uploads";
    const files = Bun.spawnSync(["ls", "-1", dir]).stdout.toString().trim().split("\n");
    return files.map(name => ({
      name,
      url: `/files/${encodeURIComponent(name)}`,
    }));
  })
  // Step 2: Return actual file
  .get("/files/:name", ({ params }) => {
    const { name } = params;

    // Prevent path traversal
    if (name.includes("/") || name.includes("..")) {
      return new Response("❌ Invalid filename", { status: 400 });
    }

    const fullPath = `./uploads/${name}`;

    // Check if file exists
    if (!Bun.file(fullPath).exists()) {
      return new Response("❌ File not found", { status: 404 });
    }

    return { file: file(fullPath) };
  }, {
    params: t.Object({
      name: t.String()
    })
  })
  .listen(port);

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
);

```

# tsconfig.json

```json
{
  "compilerOptions": {
    /* Visit https://aka.ms/tsconfig to read more about this file */

    /* Projects */
    // "incremental": true,                              /* Save .tsbuildinfo files to allow for incremental compilation of projects. */
    // "composite": true,                                /* Enable constraints that allow a TypeScript project to be used with project references. */
    // "tsBuildInfoFile": "./.tsbuildinfo",              /* Specify the path to .tsbuildinfo incremental compilation file. */
    // "disableSourceOfProjectReferenceRedirect": true,  /* Disable preferring source files instead of declaration files when referencing composite projects. */
    // "disableSolutionSearching": true,                 /* Opt a project out of multi-project reference checking when editing. */
    // "disableReferencedProjectLoad": true,             /* Reduce the number of projects loaded automatically by TypeScript. */

    /* Language and Environment */
    "target": "ES2021",                                  /* Set the JavaScript language version for emitted JavaScript and include compatible library declarations. */
    // "lib": [],                                        /* Specify a set of bundled library declaration files that describe the target runtime environment. */
    // "jsx": "preserve",                                /* Specify what JSX code is generated. */
    // "experimentalDecorators": true,                   /* Enable experimental support for TC39 stage 2 draft decorators. */
    // "emitDecoratorMetadata": true,                    /* Emit design-type metadata for decorated declarations in source files. */
    // "jsxFactory": "",                                 /* Specify the JSX factory function used when targeting React JSX emit, e.g. 'React.createElement' or 'h'. */
    // "jsxFragmentFactory": "",                         /* Specify the JSX Fragment reference used for fragments when targeting React JSX emit e.g. 'React.Fragment' or 'Fragment'. */
    // "jsxImportSource": "",                            /* Specify module specifier used to import the JSX factory functions when using 'jsx: react-jsx*'. */
    // "reactNamespace": "",                             /* Specify the object invoked for 'createElement'. This only applies when targeting 'react' JSX emit. */
    // "noLib": true,                                    /* Disable including any library files, including the default lib.d.ts. */
    // "useDefineForClassFields": true,                  /* Emit ECMAScript-standard-compliant class fields. */
    // "moduleDetection": "auto",                        /* Control what method is used to detect module-format JS files. */

    /* Modules */
    "module": "ES2022",                                /* Specify what module code is generated. */
    // "rootDir": "./",                                  /* Specify the root folder within your source files. */
    "moduleResolution": "node",                       /* Specify how TypeScript looks up a file from a given module specifier. */
    // "baseUrl": "./",                                  /* Specify the base directory to resolve non-relative module names. */
    // "paths": {},                                      /* Specify a set of entries that re-map imports to additional lookup locations. */
    // "rootDirs": [],                                   /* Allow multiple folders to be treated as one when resolving modules. */
    // "typeRoots": [],                                  /* Specify multiple folders that act like './node_modules/@types'. */
    "types": ["bun-types"],                                      /* Specify type package names to be included without being referenced in a source file. */
    // "allowUmdGlobalAccess": true,                     /* Allow accessing UMD globals from modules. */
    // "moduleSuffixes": [],                             /* List of file name suffixes to search when resolving a module. */
    // "resolveJsonModule": true,                        /* Enable importing .json files. */
    // "noResolve": true,                                /* Disallow 'import's, 'require's or '<reference>'s from expanding the number of files TypeScript should add to a project. */

    /* JavaScript Support */
    // "allowJs": true,                                  /* Allow JavaScript files to be a part of your program. Use the 'checkJS' option to get errors from these files. */
    // "checkJs": true,                                  /* Enable error reporting in type-checked JavaScript files. */
    // "maxNodeModuleJsDepth": 1,                        /* Specify the maximum folder depth used for checking JavaScript files from 'node_modules'. Only applicable with 'allowJs'. */

    /* Emit */
    // "declaration": true,                              /* Generate .d.ts files from TypeScript and JavaScript files in your project. */
    // "declarationMap": true,                           /* Create sourcemaps for d.ts files. */
    // "emitDeclarationOnly": true,                      /* Only output d.ts files and not JavaScript files. */
    // "sourceMap": true,                                /* Create source map files for emitted JavaScript files. */
    // "outFile": "./",                                  /* Specify a file that bundles all outputs into one JavaScript file. If 'declaration' is true, also designates a file that bundles all .d.ts output. */
    // "outDir": "./",                                   /* Specify an output folder for all emitted files. */
    // "removeComments": true,                           /* Disable emitting comments. */
    // "noEmit": true,                                   /* Disable emitting files from a compilation. */
    // "importHelpers": true,                            /* Allow importing helper functions from tslib once per project, instead of including them per-file. */
    // "importsNotUsedAsValues": "remove",               /* Specify emit/checking behavior for imports that are only used for types. */
    // "downlevelIteration": true,                       /* Emit more compliant, but verbose and less performant JavaScript for iteration. */
    // "sourceRoot": "",                                 /* Specify the root path for debuggers to find the reference source code. */
    // "mapRoot": "",                                    /* Specify the location where debugger should locate map files instead of generated locations. */
    // "inlineSourceMap": true,                          /* Include sourcemap files inside the emitted JavaScript. */
    // "inlineSources": true,                            /* Include source code in the sourcemaps inside the emitted JavaScript. */
    // "emitBOM": true,                                  /* Emit a UTF-8 Byte Order Mark (BOM) in the beginning of output files. */
    // "newLine": "crlf",                                /* Set the newline character for emitting files. */
    // "stripInternal": true,                            /* Disable emitting declarations that have '@internal' in their JSDoc comments. */
    // "noEmitHelpers": true,                            /* Disable generating custom helper functions like '__extends' in compiled output. */
    // "noEmitOnError": true,                            /* Disable emitting files if any type checking errors are reported. */
    // "preserveConstEnums": true,                       /* Disable erasing 'const enum' declarations in generated code. */
    // "declarationDir": "./",                           /* Specify the output directory for generated declaration files. */
    // "preserveValueImports": true,                     /* Preserve unused imported values in the JavaScript output that would otherwise be removed. */

    /* Interop Constraints */
    // "isolatedModules": true,                          /* Ensure that each file can be safely transpiled without relying on other imports. */
    // "allowSyntheticDefaultImports": true,             /* Allow 'import x from y' when a module doesn't have a default export. */
    "esModuleInterop": true,                             /* Emit additional JavaScript to ease support for importing CommonJS modules. This enables 'allowSyntheticDefaultImports' for type compatibility. */
    // "preserveSymlinks": true,                         /* Disable resolving symlinks to their realpath. This correlates to the same flag in node. */
    "forceConsistentCasingInFileNames": true,            /* Ensure that casing is correct in imports. */

    /* Type Checking */
    "strict": true,                                      /* Enable all strict type-checking options. */
    // "noImplicitAny": true,                            /* Enable error reporting for expressions and declarations with an implied 'any' type. */
    // "strictNullChecks": true,                         /* When type checking, take into account 'null' and 'undefined'. */
    // "strictFunctionTypes": true,                      /* When assigning functions, check to ensure parameters and the return values are subtype-compatible. */
    // "strictBindCallApply": true,                      /* Check that the arguments for 'bind', 'call', and 'apply' methods match the original function. */
    // "strictPropertyInitialization": true,             /* Check for class properties that are declared but not set in the constructor. */
    // "noImplicitThis": true,                           /* Enable error reporting when 'this' is given the type 'any'. */
    // "useUnknownInCatchVariables": true,               /* Default catch clause variables as 'unknown' instead of 'any'. */
    // "alwaysStrict": true,                             /* Ensure 'use strict' is always emitted. */
    // "noUnusedLocals": true,                           /* Enable error reporting when local variables aren't read. */
    // "noUnusedParameters": true,                       /* Raise an error when a function parameter isn't read. */
    // "exactOptionalPropertyTypes": true,               /* Interpret optional property types as written, rather than adding 'undefined'. */
    // "noImplicitReturns": true,                        /* Enable error reporting for codepaths that do not explicitly return in a function. */
    // "noFallthroughCasesInSwitch": true,               /* Enable error reporting for fallthrough cases in switch statements. */
    // "noUncheckedIndexedAccess": true,                 /* Add 'undefined' to a type when accessed using an index. */
    // "noImplicitOverride": true,                       /* Ensure overriding members in derived classes are marked with an override modifier. */
    // "noPropertyAccessFromIndexSignature": true,       /* Enforces using indexed accessors for keys declared using an indexed type. */
    // "allowUnusedLabels": true,                        /* Disable error reporting for unused labels. */
    // "allowUnreachableCode": true,                     /* Disable error reporting for unreachable code. */

    /* Completeness */
    // "skipDefaultLibCheck": true,                      /* Skip type checking .d.ts files that are included with TypeScript. */
    "skipLibCheck": true                                 /* Skip type checking all .d.ts files. */
  }
}

```

# uploads/Multo.mp3

This is a binary file of the type: Binary

