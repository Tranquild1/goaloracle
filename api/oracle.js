// api/oracle.js — Vercel Serverless Function
// This file goes in your GitHub repo inside a folder called "api"
// It keeps your Groq API key hidden on the server — users never see it.

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { question } = req.body || {};
  if (!question) {
    return res.status(400).json({ error: "Missing question" });
  }

  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: "Oracle not configured. Add GROQ_API_KEY to Vercel environment variables." });
  }

  try {
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        max_tokens: 600,
        messages: [
          {
            role: "system",
            content: `You are GoalOracle, an AI analyst for the 2026 FIFA World Cup prediction market deployed on X Layer blockchain (OKX's ZK-EVM L2). Contract: 0x6f2fad74009Ed11A764d6fd3871E52C585861E92. Give sharp, confident 2-3 sentence match predictions and betting insights. Mention on-chain data, X Layer, or OKB where relevant. Be specific about teams, stats, and value opportunities. Keep responses concise and punchy.`
          },
          {
            role: "user",
            content: question
          }
        ]
      })
    });

    const data = await response.json();

    if (data.error) {
      return res.status(400).json({ error: data.error.message });
    }

    const answer = data.choices?.[0]?.message?.content || "No response.";
    return res.status(200).json({ answer });

  } catch (err) {
    return res.status(500).json({ error: "Oracle unavailable. Try again shortly." });
  }
}
