// Connects to every docker-files service that is running and does one real
// operation on each. Services that aren't running are skipped.
//
//   npm install && npm start      (settings come from env vars - see `make urls`)
import pg from "pg";
import { createClient } from "redis";
import { S3Client, CreateBucketCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import nodemailer from "nodemailer";
import amqp from "amqplib";
import { Kafka, logLevel } from "kafkajs";

const env = (key, def) => process.env[key] || def;
let failed = false;

async function run(name, fn) {
  try {
    const msg = await Promise.race([
      fn(),
      new Promise((_, rej) => setTimeout(() => rej(new Error("timed out")), 15000)),
    ]);
    console.log(`  ✓ ${name.padEnd(9)} ${msg}`);
  } catch (err) {
    const text = String(err?.code ?? "") + " " + String(err?.message ?? err) + " " + String(err?.cause?.code ?? "") +
      (err?.errors ? err.errors.map((e) => e.code).join(" ") : "");
    if (/ECONNREFUSED|connection refused/i.test(text)) {
      console.log(`  - ${name.padEnd(9)} not running, skipped`);
    } else {
      failed = true;
      console.log(`  ✗ ${name.padEnd(9)} ${err?.message ?? err}`);
    }
  }
}

console.log("docker-files Node.js example");

await run("postgres", async () => {
  const client = new pg.Client(env("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/app"));
  await client.connect();
  try {
    await client.query(`CREATE TEMP TABLE items (name text, embedding vector(3));
      INSERT INTO items VALUES ('cat','[1,0,0]'), ('dog','[0.9,0.1,0]'), ('car','[0,0,1]')`);
    const { rows } = await client.query(`SELECT name FROM items ORDER BY embedding <-> '[1,0.05,0]' LIMIT 1`);
    return `pgvector nearest neighbour: ${rows[0].name}`;
  } finally {
    await client.end();
  }
});

await run("redis", async () => {
  const client = createClient({
    url: env("REDIS_URL", "redis://:redis@localhost:6379/0"),
    socket: { connectTimeout: 5000, reconnectStrategy: false }, // fail fast instead of retrying forever
  });
  client.on("error", () => {}); // errors surface through the awaited calls
  await client.connect();
  try {
    return `counter = ${await client.incr("examples:node:counter")}`;
  } finally {
    await client.quit();
  }
});

await run("s3", async () => {
  const s3 = new S3Client({
    endpoint: env("S3_ENDPOINT", "http://localhost:9000"),
    region: env("S3_REGION", "us-east-1"),
    forcePathStyle: true,
    credentials: { accessKeyId: env("S3_ACCESS_KEY", "rustfsadmin"), secretAccessKey: env("S3_SECRET_KEY", "rustfsadmin") },
    maxAttempts: 1,
  });
  try {
    await s3.send(new CreateBucketCommand({ Bucket: "examples" }));
  } catch (err) {
    if (!["BucketAlreadyOwnedByYou", "BucketAlreadyExists"].includes(err.name)) throw err;
  }
  await s3.send(new PutObjectCommand({ Bucket: "examples", Key: "node.txt", Body: "hello from Node.js", ContentType: "text/plain" }));
  return "uploaded s3://examples/node.txt";
});

await run("smtp", async () => {
  const mailer = nodemailer.createTransport({ host: env("SMTP_HOST", "localhost"), port: Number(env("SMTP_PORT", "1025")), secure: false });
  await mailer.sendMail({ from: "app@example.com", to: "you@example.com", subject: "Hello from the Node.js example", text: "It works!" });
  return "sent - check the Mailpit inbox";
});

await run("rabbitmq", async () => {
  const conn = await amqp.connect(env("AMQP_URL", "amqp://rabbit:rabbit@localhost:5672/"));
  conn.on("error", () => {}); // errors surface through the awaited calls
  try {
    const ch = await conn.createChannel();
    // RabbitMQ 4 requires shared queues to be durable
    const { queue } = await ch.assertQueue("examples-node", { durable: true });
    ch.sendToQueue(queue, Buffer.from("hello from Node.js"));
    for (let i = 0; i < 50; i++) {
      const msg = await ch.get(queue, { noAck: true });
      if (msg) return `round-trip: ${msg.content.toString()}`;
      await new Promise((r) => setTimeout(r, 100));
    }
    throw new Error("message not received");
  } finally {
    await conn.close();
  }
});

await run("kafka", async () => {
  const kafka = new Kafka({
    clientId: "docker-files-example",
    brokers: env("KAFKA_BROKERS", "localhost:9092").split(","),
    logLevel: logLevel.NOTHING,
    retry: { retries: 0 },
  });
  const topic = "examples-node";
  const admin = kafka.admin();
  await admin.connect();
  await admin.createTopics({ topics: [{ topic, numPartitions: 1 }], waitForLeaders: true }); // no-op if it exists
  await admin.disconnect();

  const producer = kafka.producer();
  await producer.connect();
  await producer.send({ topic, messages: [{ value: "hello from Node.js" }] });
  await producer.disconnect();

  const consumer = kafka.consumer({ groupId: `examples-node-${Date.now()}` });
  await consumer.connect();
  try {
    await consumer.subscribe({ topic, fromBeginning: true });
    const value = await new Promise((resolve) => consumer.run({ eachMessage: async ({ message }) => resolve(message.value.toString()) }));
    return `round-trip: ${value}`;
  } finally {
    await consumer.disconnect();
  }
});

process.exit(failed ? 1 : 0);
