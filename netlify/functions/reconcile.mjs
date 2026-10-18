import endpoint from '../../api/reconcile.js';
export default request => endpoint.fetch(request);
export const config = {path: '/api/reconcile'};
