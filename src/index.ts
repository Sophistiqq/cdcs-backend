import { Elysia, t } from "elysia";
import cors from "@elysiajs/cors"
const FILE = '/tmp/cdcs.json'
const port = process.env.PORT || 3000;
async function readClips() {
  try {
    const file = Bun.file(FILE)
    const text = await file.text();
    return JSON.parse(text)
  } catch {
    return []
  }
}

async function writeClips(clips: any[]) {
  await Bun.write(FILE, JSON.stringify(clips.slice(0, 20)))
}

const app = new Elysia()
  .use(cors())
  .get("/", () => "Hello, the app is running")
  .post('/clipboard', async ({ body }) => {
    const { text } = body;
    console.log(text)
    const clips = await readClips();
    clips.unshift({ text, time: Date.now() })
    await writeClips(clips)
    return 'OK';
  }, {
    body: t.Object({
      text: t.String()
    })
  })
  .get('/clipboard', async () => {
    return await readClips();
  })
  .listen(port);

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
);
