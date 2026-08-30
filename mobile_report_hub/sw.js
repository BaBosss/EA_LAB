const CACHE_NAME = "ea-lab-report-hub-v1";
const SHELL = ["./", "./index.html", "./styles.css", "./app.js", "./manifest.webmanifest", "./icon.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

async function cachedResponse(request) {
  const cached = await caches.match(request, { ignoreSearch: true });
  if (!cached) return null;
  const body = await cached.blob();
  const headers = new Headers(cached.headers);
  headers.set("X-EA-LAB-Cache", "true");
  return new Response(body, { status: cached.status, statusText: cached.statusText, headers });
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return;

  event.respondWith((async () => {
    const url = new URL(request.url);
    if (url.pathname.endsWith("report_index.json") && !url.pathname.includes("/fixture/")) {
      try {
        const response = await fetch(request);
        if (response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(request, response.clone());
        }
        return response;
      } catch {
        return (await cachedResponse(request)) || new Response("Report index unavailable", { status: 503 });
      }
    }

    return (await cachedResponse(request)) || fetch(request);
  })());
});
