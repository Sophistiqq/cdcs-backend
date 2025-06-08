import { Elysia, t } from "elysia";
import cors from "@elysiajs/cors";

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
  .listen(port);

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
);
