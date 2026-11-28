import catalog from "./Others/Synchrose/worker.js";

export default {
  fetch(request, env, context) {
    if (new URL(request.url).pathname.startsWith("/api/")) {
      return catalog.fetch(request, env, context);
    }
    return env.ASSETS.fetch(request);
  },
};
