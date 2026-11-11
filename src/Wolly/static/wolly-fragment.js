// Part of Wolly, a web framework in Hilde.
//
// SPDX-FileCopyrightText: 2026 Heiko Zimmermann
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Swaps a fragment of the page for the one the server sends.  An element
// with data-wolly-get and data-wolly-target asks, on a click, for the URL of
// data-wolly-get with the headers HX-Request: true and HX-Target: the id; a
// form with data-wolly-target sends itself the same way; an element with
// data-wolly-poll asks for its fragment again every so many seconds.  The
// answer replaces the element of that id.  Only URLs of the page's own
// origin are asked for, a script in the answer is never run, and an answer
// that is no 2xx text/html leaves the page as it was.
//
// Every ask carries a generation, one more than the ask before it for the
// same target: an answer whose ask a newer one has superseded is dropped
// and never swapped in, so an older answer that travels longer than a
// newer one cannot overwrite it.  Every ask has a deadline in milliseconds
// after which it is aborted (data-wolly-deadline, 10000 by default), and a
// cap in bytes over which the answer is rejected before it is read whole
// (data-wolly-limit, 1048576 by default).
(function () {
  "use strict";
  var idPattern = /^[A-Za-z][A-Za-z0-9_-]{0,63}$/;
  var defaultDeadline = 10000;
  var defaultLimit = 1048576;

  // The generation of the last ask, per target id.  A target asked again
  // while an ask of it is under way makes that ask stale.
  var generations = {};

  // The number of the asks for id so far, counting from the first.
  function nextGeneration(id) {
    generations[id] = (generations[id] || 0) + 1;
    return generations[id];
  }

  // The generation of the last ask for id, 0 before the first.
  function generationOf(id) {
    return generations[id] || 0;
  }

  function sameOrigin(raw) {
    var url;
    try {
      url = new URL(raw, document.baseURI);
    } catch (e) {
      return null;
    }
    return url.origin === window.location.origin ? url : null;
  }

  function failed(element, reason) {
    element.dispatchEvent(new CustomEvent("wolly:fragment-error", { bubbles: true, detail: reason }));
  }

  function stale(element, id, generation) {
    element.dispatchEvent(new CustomEvent("wolly:fragment-stale", { bubbles: true, detail: { id: id, generation: generation } }));
  }

  // The number an attribute names, above zero, else the fallback.
  function positiveAttribute(element, name, fallback) {
    var given = parseInt(element.getAttribute(name), 10);
    return given > 0 ? given : fallback;
  }

  // The element the answer goes to: HX-Retarget when it names an id, else
  // the one that was asked for.
  function destination(response, id) {
    var retarget = response.headers.get("HX-Retarget");
    if (retarget && retarget.charAt(0) === "#" && idPattern.test(retarget.slice(1))) {
      return document.getElementById(retarget.slice(1));
    }
    return document.getElementById(id);
  }

  function swap(element, html, how) {
    // Nodes parsed into a template are inert: a script among them is
    // marked as started and never runs when it is put into the page.
    var template = document.createElement("template");
    template.innerHTML = html;
    if (how === "innerHTML") {
      element.replaceChildren(template.content);
    } else {
      element.replaceWith(template.content);
    }
  }

  // The text of the answer, read at most limit bytes: once the cap is
  // passed the reading stops and the answer is rejected, so a response
  // larger than the cap is never held whole.  Without a body stream the
  // browser reads the text itself, and only its own bounds hold.
  function readCapped(response, limit) {
    var stream = response.body;
    if (!stream || typeof stream.getReader !== "function") {
      return response.text();
    }
    return new Promise(function (resolve, reject) {
      var reader = stream.getReader();
      var decoder = new TextDecoder("utf-8");
      var parts = [];
      var total = 0;
      function step() {
        reader.read().then(function (chunk) {
          var all, placed, i;
          if (chunk.done) {
            all = new Uint8Array(total);
            placed = 0;
            for (i = 0; i < parts.length; i += 1) {
              all.set(parts[i], placed);
              placed += parts[i].byteLength;
            }
            resolve(decoder.decode(all));
            return;
          }
          total += chunk.value.byteLength;
          if (total > limit) {
            reader.cancel();
            reject(new Error("answer larger than " + limit + " bytes"));
            return;
          }
          parts.push(chunk.value);
          step();
        }, reject);
      }
      step();
    });
  }

  function ask(origin, url, id, init) {
    var target = document.getElementById(id);
    if (!target) {
      failed(origin, "no element " + id);
      return;
    }
    // One more than every ask for this target before: an answer of an
    // earlier ask arrives late and is dropped.
    var generation = nextGeneration(id);
    var deadline = positiveAttribute(origin, "data-wolly-deadline", defaultDeadline);
    var limit = positiveAttribute(origin, "data-wolly-limit", defaultLimit);
    var controller = new AbortController();
    var timer = setTimeout(function () {
      controller.abort();
    }, deadline);
    init.credentials = "same-origin";
    init.redirect = "error";
    init.signal = controller.signal;
    init.headers = init.headers || {};
    init.headers["HX-Request"] = "true";
    init.headers["HX-Target"] = id;
    init.headers["HX-Current-URL"] = window.location.href;
    target.setAttribute("aria-busy", "true");
    fetch(url.href, init).then(function (response) {
      clearTimeout(timer);
      var type = response.headers.get("Content-Type") || "";
      var redirect = response.headers.get("HX-Redirect");
      if (redirect) {
        var away = sameOrigin(redirect);
        if (away) {
          window.location.assign(away.href);
        }
        return null;
      }
      if (!response.ok || type.indexOf("text/html") !== 0) {
        throw new Error("status " + response.status);
      }
      return readCapped(response, limit).then(function (html) {
        if (generationOf(id) !== generation) {
          stale(origin, id, generation);
          return;
        }
        var place = destination(response, id);
        var how = response.headers.get("HX-Reswap") === "innerHTML" ? "innerHTML" : "outerHTML";
        if (place) {
          swap(place, html, how);
        }
      });
    }).catch(function (error) {
      clearTimeout(timer);
      if (generationOf(id) !== generation) {
        stale(origin, id, generation);
        return;
      }
      failed(origin, String(error));
    }).then(function () {
      // Only the ask of the current generation clears the mark of the
      // target; an earlier one that finished late leaves it to the newer.
      if (generationOf(id) === generation) {
        var still = document.getElementById(id);
        if (still) {
          still.removeAttribute("aria-busy");
        }
      }
    });
  }

  // The loop of one polled element: it asks for its fragment again every
  // so many seconds, until it is no longer on the page.  Each tick is an
  // ask of its own, so the answer of a tick that a newer one superseded
  // is dropped.
  function startPoll(element) {
    var seconds = parseInt(element.getAttribute("data-wolly-poll"), 10);
    var id = element.getAttribute("data-wolly-target");
    if (!(seconds >= 1) || !id || !idPattern.test(id)) {
      return;
    }
    var timer = setInterval(function () {
      if (!document.body || !document.body.contains(element)) {
        clearInterval(timer);
        return;
      }
      var url = sameOrigin(element.getAttribute("data-wolly-get") || window.location.href);
      if (url) {
        ask(element, url, id, { method: "GET" });
      }
    }, seconds * 1000);
  }

  function startPolls() {
    var polled = document.querySelectorAll("[data-wolly-poll]");
    var i;
    for (i = 0; i < polled.length; i += 1) {
      startPoll(polled[i]);
    }
  }

  document.addEventListener("click", function (event) {
    var trigger = event.target.closest ? event.target.closest("[data-wolly-get][data-wolly-target]") : null;
    if (!trigger || trigger.tagName === "FORM") {
      return;
    }
    var id = trigger.getAttribute("data-wolly-target");
    var url = sameOrigin(trigger.getAttribute("data-wolly-get"));
    if (!url || !idPattern.test(id)) {
      return;
    }
    event.preventDefault();
    ask(trigger, url, id, { method: "GET" });
  });

  document.addEventListener("submit", function (event) {
    var form = event.target;
    if (!form.hasAttribute || !form.hasAttribute("data-wolly-target")) {
      return;
    }
    var id = form.getAttribute("data-wolly-target");
    var url = sameOrigin(form.getAttribute("action") || window.location.href);
    if (!url || !idPattern.test(id)) {
      return;
    }
    event.preventDefault();
    var fields = new URLSearchParams(new FormData(form));
    if ((form.getAttribute("method") || "get").toLowerCase() === "post") {
      ask(form, url, id, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: fields.toString()
      });
    } else {
      url.search = fields.toString();
      ask(form, url, id, { method: "GET" });
    }
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", startPolls);
  } else {
    startPolls();
  }
})();
