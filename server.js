/**
 * Friday Voice Helper — tiny Express server.
 *
 * Two jobs:
 *   1. Serve the static page in /public
 *   2. Proxy the two APIs so keys stay on the server (never in the browser)
 *
 * Endpoints:
 *   GET  /            the web UI
 *   GET  /api/status  which keys are present (no secret values)
 *   POST /api/ask     { question } → { answer, demo }
 *   POST /api/speak   { text }     → audio/mpeg  (or 503 so the browser speaks)
 */

require("dotenv").config();

const path = require("path");
const express = require("express");
const { SYSTEM_PROMPT } = require("./config");

const app = express();
const PORT = process.env.PORT || 3000;

// Let the server read JSON bodies from fetch() in the browser.
app.use(express.json({ limit: "16kb" }));

// Serve index.html, styles.css, and app.js from the public folder.
app.use(express.static(path.join(__dirname, "public")));

/**
 * Tiny status check so the UI can show "Demo mode" when keys are missing.
 * We only report yes/no — never the key itself.
 */
app.get("/api/status", (_req, res) => {
  res.json({
    xai: Boolean(process.env.XAI_API_KEY),
    elevenlabs: Boolean(process.env.ELEVENLABS_API_KEY),
    model: process.env.XAI_MODEL || "grok-4.7",
  });
});

/**
 * Turn a spoken (or typed) question into an answer.
 * If XAI_API_KEY is missing, we still return a clearly labelled demo reply
 * so the whole demo works with zero setup.
 */
app.post("/api/ask", async (req, res) => {
  const question = String(req.body?.question || "").trim();

  if (!question) {
    return res.status(400).json({ error: "Please ask a question." });
  }

  const apiKey = process.env.XAI_API_KEY;

  if (!apiKey) {
    return res.json({
      demo: true,
      source: "demo",
      answer:
        `[DEMO MODE] I don't have an XAI_API_KEY yet, so this is a sample answer. ` +
        `You asked: "${question}". Copy .env.example to .env, add your xAI key, ` +
        `and restart the server for a real Grok reply.`,
    });
  }

  const model = process.env.XAI_MODEL || "grok-4.7";

  try {
    // OpenAI-compatible chat completions against the xAI (SpaceXAI) API.
    const response = await fetch("https://api.x.ai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: question },
        ],
        // Voice answers should stay short.
        max_tokens: 300,
      }),
    });

    if (!response.ok) {
      const detail = await safeText(response);
      console.error("xAI error", response.status, detail);
      return res.status(502).json({
        error: `xAI request failed (${response.status}). Check XAI_API_KEY and XAI_MODEL.`,
      });
    }

    const data = await response.json();
    const answer = data?.choices?.[0]?.message?.content?.trim();

    if (!answer) {
      return res.status(502).json({ error: "xAI returned an empty answer." });
    }

    return res.json({ demo: false, source: "xai", answer });
  } catch (err) {
    console.error("xAI request threw", err);
    return res.status(502).json({
      error: "Could not reach the xAI API. Check your network and try again.",
    });
  }
});

/**
 * Turn answer text into spoken audio via ElevenLabs.
 * If the key is missing or the call fails, we send 503 + { fallback: true }
 * so the browser can use speechSynthesis instead. Never crash the demo.
 */
app.post("/api/speak", async (req, res) => {
  const text = String(req.body?.text || "").trim();

  if (!text) {
    return res.status(400).json({ error: "Nothing to speak." });
  }

  const apiKey = process.env.ELEVENLABS_API_KEY;
  if (!apiKey) {
    return res.status(503).json({ fallback: true, reason: "missing_key" });
  }

  const voiceId = process.env.ELEVENLABS_VOICE_ID || "JBFqnCBsd6RMkjVDRZzb";

  try {
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: "POST",
        headers: {
          "xi-api-key": apiKey,
          "Content-Type": "application/json",
          Accept: "audio/mpeg",
        },
        body: JSON.stringify({
          text,
          model_id: "eleven_multilingual_v2",
        }),
      }
    );

    if (!response.ok) {
      const detail = await safeText(response);
      console.error("ElevenLabs error", response.status, detail);
      return res.status(503).json({ fallback: true, reason: "tts_failed" });
    }

    const audio = Buffer.from(await response.arrayBuffer());
    res.set("Content-Type", "audio/mpeg");
    res.set("Cache-Control", "no-store");
    return res.send(audio);
  } catch (err) {
    console.error("ElevenLabs request threw", err);
    return res.status(503).json({ fallback: true, reason: "tts_failed" });
  }
});

app.listen(PORT, () => {
  const hasXai = Boolean(process.env.XAI_API_KEY);
  const hasTts = Boolean(process.env.ELEVENLABS_API_KEY);
  console.log(`Friday Voice Helper is running at http://localhost:${PORT}`);
  console.log(`  xAI:        ${hasXai ? "key found" : "DEMO MODE (no XAI_API_KEY)"}`);
  console.log(
    `  ElevenLabs: ${hasTts ? "key found" : "browser speech fallback (no ELEVENLABS_API_KEY)"}`
  );
  console.log("  Edit the system prompt in config.js, then restart.");
});

/** Read a response body as text without throwing if it is empty. */
async function safeText(response) {
  try {
    return await response.text();
  } catch {
    return "";
  }
}
