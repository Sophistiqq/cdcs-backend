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
    const fileObj = file(fullPath);

    // Check if file exists
    if (!fileObj.exists()) {
      return new Response("❌ File not found", { status: 404 });
    }

    // Return the file directly, not wrapped in JSON
    return fileObj;
  }, {
    params: t.Object({
      name: t.String()
    })
  })
  .listen(port);

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
);
