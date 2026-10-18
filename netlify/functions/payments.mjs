import endpoint from '../../api/payments/[action].js';
export default request => endpoint.fetch(request);
export const config = {path: '/api/payments/:action'};
