// Loads the Dart program (WebAssembly) of the popup.
import { compile } from "./popup.mjs";

const bytes = await (await fetch("popup.wasm")).arrayBuffer();
const app = await compile(bytes);
const instance = await app.instantiate({});
instance.invokeMain();
