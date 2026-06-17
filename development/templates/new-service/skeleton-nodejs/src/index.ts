import express, { Express, Request, Response } from 'express';

const app: Express = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());

// Health check endpoint
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'healthy' });
});

// Readiness check endpoint
app.get('/ready', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'ready' });
});

// Welcome endpoint
app.get('/', (_req: Request, res: Response) => {
  res.json({
    message: 'Welcome to ${{ values.serviceName }}',
    version: '0.1.0',
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Service running on port ${PORT}`);
});
