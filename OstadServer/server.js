require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { MongoClient } = require("mongodb");
const redis = require("redis");

const app = express();

// Environment variables
const PORT = process.env.PORT || 5050;
const MONGO_URL = process.env.MONGO_URL;
const DB_NAME = process.env.DB_NAME || "Ostad-DB";
const REDIS_URL = process.env.REDIS_URL;
const CACHE_TTL = parseInt(process.env.CACHE_TTL) || 600;

// MongoDB client
const mongoClient = new MongoClient(MONGO_URL);

// Redis client
const redisClient = redis.createClient({ url: REDIS_URL });
redisClient.on("error", (err) => console.error("Redis error:", err));

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static("public"));

// ===== DATABASE CONNECTION =====
async function connectDB() {
  try {
    await mongoClient.connect();
    await redisClient.connect();
    console.log("✅ Connected to MongoDB & Redis");
  } catch (error) {
    console.error("❌ Database connection failed:", error);
    process.exit(1);
  }
}

// ===== ROUTES =====

// GET all students
app.get("/getStudents", async (req, res) => {
  try {
    const db = mongoClient.db(DB_NAME);
    const students = await db.collection("students").find({}).toArray();
    res.json(students);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch students" });
  }
});

// POST new student
app.post("/addStudent", async (req, res) => {
  try {
    const studentData = req.body;
    if (!studentData.id || !studentData.name)
      return res.status(400).json({ error: "Invalid student data" });

    const db = mongoClient.db(DB_NAME);
    const result = await db.collection("students").insertOne(studentData);
    res.status(201).json({ message: "Student added", id: result.insertedId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to add student" });
  }
});

// GET result by student ID (with Redis caching)
app.get("/result/:id", async (req, res) => {
  const studentId = req.params.id;
  try {
    const cached = await redisClient.get(`result:${studentId}`);
    if (cached) return res.json(JSON.parse(cached));

    const db = mongoClient.db(DB_NAME);
    const result = await db.collection("results").findOne({ id: studentId });
    if (!result) return res.status(404).json({ error: "Result not found" });

    await redisClient.setEx(`result:${studentId}`, CACHE_TTL, JSON.stringify(result));
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch result" });
  }
});

// POST new result
app.post("/addResult", async (req, res) => {
  try {
    const resultData = req.body;
    if (!resultData.id || !resultData.subjects)
      return res.status(400).json({ error: "Invalid result data" });

    const db = mongoClient.db(DB_NAME);
    const inserted = await db.collection("results").insertOne(resultData);

    await redisClient.setEx(`result:${resultData.id}`, CACHE_TTL, JSON.stringify(resultData));
    res.status(201).json({ message: "Result added", id: inserted.insertedId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to add result" });
  }
});

// Base route
app.get("/", (req, res) => res.send("Ostad Result Checker API is running"));

// Start server
(async () => {
  await connectDB();
  app.listen(PORT, () => console.log(`🚀 Server running at http://localhost:${PORT}`));
})();
