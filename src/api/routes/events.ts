import { Hono } from 'hono';
import { EventProcessor } from '../../services/tracking/eventProcessor';

const eventsRouter = new Hono();
const eventProcessor = new EventProcessor();

eventsRouter.get('/', async (c) => {
  return await eventProcessor.handleEvent(c);
});

eventsRouter.post('/', async (c) => {
  return await eventProcessor.handleEvent(c);
});

export default eventsRouter;
