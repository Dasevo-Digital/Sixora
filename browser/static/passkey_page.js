// Runs in the web page, before the page's own scripts, and only if the user
// switched passkeys on in the Sixora extension. It takes over the passkey
// calls of navigator.credentials and hands them to the extension, which
// asks the user. It holds no keys and knows no accounts; what comes back is
// only the signed answer for this page.
(() => {
  "use strict";

  const credentials = navigator.credentials;
  const origin = window.location.origin;
  if (!credentials || !window.PublicKeyCredential || origin === "null") return;

  const browserOwn = {
    create: CredentialsContainer.prototype.create.bind(credentials),
    get: CredentialsContainer.prototype.get.bind(credentials),
  };
  // Where a request goes that Sixora does not answer: the browser, or another
  // password manager that hooked in (see stayOnTop).
  const below = { ...browserOwn };
  // Challenge → the mediation it went down with. A page may reuse one for a
  // real sign-in after the suggestion in the field.
  const handedDown = new WeakMap();

  function handDown(name, options) {
    const challenge = options?.publicKey?.challenge;
    if (Object(challenge) === challenge) handedDown.set(challenge, options.mediation);
    return below[name](options);
  }
  const nativeCreate = (options) => handDown("create", options);
  const nativeGet = (options) => handDown("get", options);
  // Taken now: pages may silence the console later.
  const note = console.info.bind(console, "Sixora:");
  const pending = new Map();
  let counter = 0;

  window.addEventListener("message", (event) => {
    if (event.source !== window || event.data?.sixoraPasskey !== "reply") return;
    const resolve = pending.get(event.data.id);
    if (!resolve) return;
    pending.delete(event.data.id);
    resolve(event.data.reply);
  });

  function ask(request, signal) {
    return new Promise((resolve, reject) => {
      const reason = () => signal.reason ?? new DOMException("Aborted", "AbortError");
      if (signal?.aborted) {
        reject(reason());
        return;
      }
      const id = `${Date.now()}-${++counter}`;
      pending.set(id, resolve);
      window.postMessage({ sixoraPasskey: "request", id, request }, origin);
      signal?.addEventListener(
        "abort",
        () => {
          if (!pending.delete(id)) return;
          window.postMessage({ sixoraPasskey: "abort", id }, origin);
          reject(reason());
        },
        { once: true },
      );
    });
  }

  const view = (v) =>
    ArrayBuffer.isView(v)
      ? new Uint8Array(v.buffer, v.byteOffset, v.byteLength)
      : new Uint8Array(v);

  const toBase64 = (v) =>
    btoa(String.fromCharCode(...view(v)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const fromBase64 = (s) =>
    Uint8Array.from(
      atob(s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "=")),
      (c) => c.charCodeAt(0),
    ).buffer;

  // Objects of the browser's classes for `instanceof`; own properties
  // stand in for the getters, which refuse objects they did not make.
  function make(prototype, values) {
    const object = Object.create(prototype);
    for (const [name, value] of Object.entries(values)) {
      Object.defineProperty(object, name, { value, enumerable: true });
    }
    return object;
  }

  function credential(result, response, responseJson) {
    return make(PublicKeyCredential.prototype, {
      id: result.id,
      rawId: fromBase64(result.id),
      type: "public-key",
      authenticatorAttachment: "platform",
      response,
      getClientExtensionResults: () => ({}),
      toJSON: () => ({
        id: result.id,
        rawId: result.id,
        type: "public-key",
        authenticatorAttachment: "platform",
        response: responseJson,
        clientExtensionResults: {},
      }),
    });
  }

  function created(result) {
    const transports = ["internal", "hybrid"];
    return credential(
      result,
      make(AuthenticatorAttestationResponse.prototype, {
        clientDataJSON: fromBase64(result.clientDataJSON),
        attestationObject: fromBase64(result.attestationObject),
        getTransports: () => [...transports],
        getAuthenticatorData: () => fromBase64(result.authenticatorData),
        getPublicKey: () => fromBase64(result.publicKey),
        getPublicKeyAlgorithm: () => result.publicKeyAlgorithm,
      }),
      {
        clientDataJSON: result.clientDataJSON,
        attestationObject: result.attestationObject,
        authenticatorData: result.authenticatorData,
        publicKey: result.publicKey,
        publicKeyAlgorithm: result.publicKeyAlgorithm,
        transports,
      },
    );
  }

  function signedIn(result) {
    return credential(
      result,
      make(AuthenticatorAssertionResponse.prototype, {
        clientDataJSON: fromBase64(result.clientDataJSON),
        authenticatorData: fromBase64(result.authenticatorData),
        signature: fromBase64(result.signature),
        userHandle: result.userHandle ? fromBase64(result.userHandle) : null,
      }),
      {
        clientDataJSON: result.clientDataJSON,
        authenticatorData: result.authenticatorData,
        signature: result.signature,
        userHandle: result.userHandle || undefined,
      },
    );
  }

  async function run(build, options, native, wrap) {
    let request;
    try {
      request = build();
    } catch (e) {
      // Malformed: the browser reports it properly.
      note("left to the browser, unreadable options:", String(e));
      return native(options);
    }
    const reply = await ask(request, options.signal);
    if (reply.fallback) {
      note("left to the browser:", reply.why ?? "chosen in the window");
      return native(options);
    }
    if (reply.error) throw new DOMException(reply.message ?? "", reply.error);
    return wrap(reply.result);
  }

  const mine = {};

  mine.create = function (options) {
    const key = options?.publicKey;
    // Conditional: a passkey made silently after a password sign-in. Sixora
    // never makes one without asking.
    if (!key || options.mediation === "conditional") return nativeCreate(options);
    // A manager underneath that captured this function hands it back.
    if (handedDown.has(key.challenge)) return browserOwn.create(options);
    return run(
      () => ({
        kind: "create",
        rpId: key.rp.id ?? "",
        rpName: key.rp.name ?? "",
        user: {
          id: toBase64(key.user.id),
          name: key.user.name ?? "",
          displayName: key.user.displayName ?? "",
        },
        challenge: toBase64(key.challenge),
        algorithms: (key.pubKeyCredParams ?? []).map((p) => p.alg),
        exclude: (key.excludeCredentials ?? []).map((c) => toBase64(c.id)),
        userVerification: key.authenticatorSelection?.userVerification ?? "preferred",
      }),
      options,
      nativeCreate,
      created,
    );
  };

  const signInRequest = (key) => ({
    kind: "get",
    rpId: key.rpId ?? "",
    challenge: toBase64(key.challenge),
    allow: (key.allowCredentials ?? []).map((c) => toBase64(c.id)),
    userVerification: key.userVerification ?? "preferred",
  });

  // A sign-in the page keeps open while the user types. The browser or
  // another manager may offer passkeys in the field, Sixora offers its own
  // next to it (passkey_relay.js). Whichever the user picks answers, and the
  // other is withdrawn.
  function suggest(key, options) {
    const outer = options.signal;
    if (outer?.aborted) return nativeGet(options);
    let request;
    try {
      request = { ...signInRequest(key), conditional: true };
    } catch (e) {
      return nativeGet(options);
    }
    const others = new AbortController();
    const here = new AbortController();
    outer?.addEventListener(
      "abort",
      () => {
        others.abort(outer.reason);
        here.abort(outer.reason);
      },
      { once: true },
    );
    return new Promise((resolve, reject) => {
      let failure = null;
      let alone = false;
      nativeGet({ ...options, signal: others.signal }).then(
        (found) => {
          here.abort();
          resolve(found);
        },
        // While Sixora's suggestion stands, the request is still open.
        (e) => {
          if (alone || outer?.aborted) reject(e);
          else failure = e;
        },
      );
      ask(request, here.signal).then(
        (reply) => {
          if (reply.result) {
            others.abort();
            resolve(signedIn(reply.result));
            return;
          }
          note("no suggestion in the field:", reply.why ?? "");
          alone = true;
          if (failure) reject(failure);
        },
        (e) => {
          if (outer?.aborted) reject(e);
        },
      );
    });
  }

  mine.get = function (options) {
    const key = options?.publicKey;
    if (key && handedDown.has(key.challenge) && handedDown.get(key.challenge) === options.mediation) {
      return browserOwn.get(options);
    }
    if (!key) return nativeGet(options);
    note("sign-in request:", options.mediation ?? "direct", key.rpId ?? "own domain");
    if (options.mediation === "conditional") return suggest(key, options);
    return run(() => signInRequest(key), options, nativeGet, signedIn);
  };

  // Password managers that hook in later (1Password does, once it has set
  // itself up) would cut Sixora out. So just before the user acts, and often
  // while the page starts up (it may ask for suggestions without any click),
  // it moves back on top. What it does not answer still reaches them.
  const known = {};
  let ownView = false;

  function stayOnTop() {
    for (const [name, ours] of Object.entries(mine)) {
      const current = credentials[name];
      if (current === ours || current === known[name]) continue;
      known[name] = current;
      below[name] = (options) => current.call(credentials, options);
      try {
        Object.defineProperty(credentials, name, {
          value: ours,
          writable: true,
          configurable: true,
          enumerable: true,
        });
      } catch (e) {
        showOwnView();
      }
    }
  }

  // A function pinned so that it cannot be replaced: the page then gets its
  // own navigator.credentials with Sixora's functions.
  function showOwnView() {
    if (ownView) return;
    const plain = (value) => ({ value, writable: true, configurable: true, enumerable: true });
    const view = Object.create(CredentialsContainer.prototype, {
      create: plain(mine.create),
      get: plain(mine.get),
      store: plain((credential) => credentials.store(credential)),
      preventSilentAccess: plain(() => credentials.preventSilentAccess()),
    });
    try {
      Object.defineProperty(navigator, "credentials", {
        get: () => view,
        configurable: true,
        enumerable: true,
      });
      ownView = true;
    } catch (e) {
      note("cannot get in front of another password manager");
    }
  }

  stayOnTop();
  for (const event of ["pointerdown", "keydown"]) {
    window.addEventListener(event, stayOnTop, true);
  }
  window.addEventListener("load", stayOnTop);
  const startup = setInterval(stayOnTop, 200);
  setTimeout(() => clearInterval(startup), 15000);

  // Sixora answers with user verification, like a built-in authenticator,
  // and offers suggestions in the field whatever the browser can do.
  PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = async () => true;
  PublicKeyCredential.isConditionalMediationAvailable = async () => true;
})();
