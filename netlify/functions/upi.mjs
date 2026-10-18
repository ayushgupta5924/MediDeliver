import endpoint from '../../api/upi/[action].js';
export default request => endpoint.fetch(request);
export const config = {path: '/api/upi/:action'};
