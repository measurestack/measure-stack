import { Hono } from 'hono';
const healthRouter = new Hono();
healthRouter.get('/', (c) => {
    return c.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        service: 'measure-js'
    });
});
export default healthRouter;
