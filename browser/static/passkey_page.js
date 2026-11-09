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

  const nativeCreate = credentials.create.bind(credentials);
  const nativeGet = credentials.get.bind(credentials);
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
    v instanceof ArrayBuffer
      ? new Uint8Array(v)
      : new Uint8Array(v.buffer, v.byteOffset, v.byteLength);

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
      return native(options);
    }
    const reply = await ask(request, options.signal);
    if (reply.fallback) return native(options);
    if (reply.error) throw new DOMException(reply.message ?? "", reply.error);
    return wrap(reply.result);
  }

  credentials.create = function (options) {
    const key = options?.publicKey;
    if (!key) return nativeCreate(options);
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

  credentials.get = function (options) {
    const key = options?.publicKey;
    // Autofill suggestions stay with the browser: Sixora has no way to add
    // entries to its list.
    if (!key || options.mediation === "conditional") return nativeGet(options);
    return run(
      () => ({
        kind: "get",
        rpId: key.rpId ?? "",
        challenge: toBase64(key.challenge),
        allow: (key.allowCredentials ?? []).map((c) => toBase64(c.id)),
        userVerification: key.userVerification ?? "preferred",
      }),
      options,
      nativeGet,
      signedIn,
    );
  };

  // Sixora answers with user verification, like a built-in authenticator.
  PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = async () => true;
})();
