

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

```bash
curl -o ~/.local/bin/cdcs https://raw.githubusercontent.com/your-username/cdcs/main/cdcs
chmod +x ~/.local/bin/cdcs
```

Make sure `~/.local/bin` is in your `$PATH`.

## 📱 Send from Your Phone

Use the web app to send clipboard text:
👉 [https://cdcs-clipboard.vercel.app](https://cdcs-clipboard.vercel.app)

The web app connects to the backend (deployed via Render) and pushes your text for retrieval.

## 🖥 Usage

Run it in your terminal:

```bash
cdcs
```

It will fetch recent entries from your web app and show a list.
Pick one, and it will be copied to your clipboard via `wl-copy`.

---

> This project is private and built for personal use.

