// Protocol adapter for the upstream campus mini-apps.
(function (origin, student, app) {
  if (window !== window.top || location.origin !== origin) return;
  const deliver = (response) => {
    Promise.resolve().then(() => {
      if (window.rpcClient && typeof window.rpcClient.onReceive === 'function') {
        window.rpcClient.onReceive(response);
      }
    });
  };
  const postMessage = (raw) => {
    let request;
    try {
      request = typeof raw === 'string' ? JSON.parse(raw) : raw;
    } catch (_) { return; }
    if (!request || typeof request.service !== 'string' || typeof request.method !== 'string') return;
    const result = {
      _meta: request._meta || {},
      method: request.method,
      service: request.service,
      code: 1000,
      data: null,
    };
    try {
      if (request.method === '_addEventListener' || request.method === '_removeEventListener') {
        // Events are registered by the mini-app. No native handles are exposed.
      } else if (request.service === 'app' && request.method === 'info') {
        result.data = Object.assign({}, app);
      } else if (request.service === 'student' && request.method === 'profile') {
        result.data = Object.assign({}, student);
      } else if (request.service === 'storage' && (request.method === 'get' || request.method === 'set')) {
        const params = request.params;
        if (!params || typeof params.key !== 'string' || !params.key.trim() || params.key.length > 256) {
          result.code = 1002;
          result.message = 'Invalid parameters';
        } else {
          const key = 'iwut.rpc.' + params.key;
          if (request.method === 'get') {
            result.data = { value: localStorage.getItem(key) };
          } else {
            const value = params.value == null ? null : String(params.value);
            if (value === null) localStorage.removeItem(key);
            else if (value.length <= 65536) localStorage.setItem(key, value);
            else throw new Error('Value too large');
            result.data = { state: true };
          }
        }
      } else if (['app', 'student', 'storage'].includes(request.service)) {
        result.code = 1004;
        result.message = 'Method Not Found';
      } else {
        result.code = 1003;
        result.message = 'Service Not Found';
      }
    } catch (_) {
      result.code = 1008;
      result.message = 'Data operation failed';
    }
    deliver(result);
  };
  const bridge = Object.freeze({ __iwutNativeInjected: true, postMessage });
  window.bridge = bridge;
  window.androidBridge = bridge;
})
