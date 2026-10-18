import endpoint from '../../api/health.js';
export default request => endpoint.fetch(request);
export const config = {path: '/api/health'};
