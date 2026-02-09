const express = require("express");
const https = require("https");

const app = express();
app.use(express.json());

const {
  HOOK_SECRET,
  GITHUB_TOKEN,
  GITHUB_REPO, // "owner/site"
  PORT = 9000,
} = process.env;

if (!HOOK_SECRET || !GITHUB_TOKEN || !GITHUB_REPO) {
  console.error("Missing required env vars: HOOK_SECRET, GITHUB_TOKEN, GITHUB_REPO");
  process.exit(1);
}

// Health check
app.get("/hooks/health", (_req, res) => {
  res.json({ status: "ok" });
});

// Strapi webhook endpoint
app.post("/hooks/rebuild-site", (req, res) => {
  // Verify secret header
  const secret = req.headers["x-hook-secret"];
  if (secret !== HOOK_SECRET) {
    console.warn("Unauthorized webhook attempt");
    return res.status(401).json({ error: "Unauthorized" });
  }

  console.log("Webhook received, triggering GitHub Actions...");

  const [owner, repo] = GITHUB_REPO.split("/");

  const payload = JSON.stringify({
    event_type: "strapi-publish",
    client_payload: {
      model: req.body?.model || "unknown",
      event: req.body?.event || "unknown",
      timestamp: new Date().toISOString(),
    },
  });

  const options = {
    hostname: "api.github.com",
    path: `/repos/${owner}/${repo}/dispatches`,
    method: "POST",
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "User-Agent": "webhook-relay",
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Length": Buffer.byteLength(payload),
    },
  };

  const ghReq = https.request(options, (ghRes) => {
    let body = "";
    ghRes.on("data", (chunk) => (body += chunk));
    ghRes.on("end", () => {
      if (ghRes.statusCode === 204) {
        console.log("GitHub Actions triggered successfully");
        res.json({ success: true, message: "Build triggered" });
      } else {
        console.error(`GitHub API error: ${ghRes.statusCode} ${body}`);
        res.status(502).json({ error: "GitHub API error", status: ghRes.statusCode });
      }
    });
  });

  ghReq.on("error", (err) => {
    console.error("GitHub request failed:", err.message);
    res.status(500).json({ error: "Failed to trigger build" });
  });

  ghReq.write(payload);
  ghReq.end();
});

app.listen(PORT, () => {
  console.log(`Webhook relay listening on port ${PORT}`);
});
