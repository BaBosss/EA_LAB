"use strict";

const CACHE_NAME = "ea-lab-report-hub-v3";
const CACHE_PREFIX = "ea-lab-report-hub-v";
const SHELL = ["./index.html", "./styles.css", "./app.js", "./manifest.webmanifest", "./icon.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME).map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
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
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    if (url.pathname.includes("/fixture/")) return fetch(request, { cache: "no-store" });

    if (url.pathname.endsWith("/report_index.json")) {
      try {
        const response = await fetch(request, { cache: "no-store" });
        if (response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(request, response.clone());
        }
        return response;
      } catch {
        return (await cachedResponse(request)) || new Response("Report index unavailable", { status: 503, headers: { "Content-Type": "text/plain" } });
      }
    }

    if (request.mode === "navigate") {
      try {
        return await fetch(request);
      } catch {
        return (await caches.match("./index.html")) || new Response("Monitor shell unavailable", { status: 503 });
      }
    }

    return (await cachedResponse(request)) || fetch(request);
  })());
});
