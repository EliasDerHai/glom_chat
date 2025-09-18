// build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label2) => label2 in fields ? fields[label2] : this[label2]
    );
    return new this.constructor(...properties);
  }
};
var List = class {
  static fromArray(array3, tail) {
    let t = tail || new Empty();
    for (let i = array3.length - 1; i >= 0; --i) {
      t = new NonEmpty(array3[i], t);
    }
    return t;
  }
  [Symbol.iterator]() {
    return new ListIterator(this);
  }
  toArray() {
    return [...this];
  }
  // @internal
  atLeastLength(desired) {
    let current = this;
    while (desired-- > 0 && current) current = current.tail;
    return current !== void 0;
  }
  // @internal
  hasLength(desired) {
    let current = this;
    while (desired-- > 0 && current) current = current.tail;
    return desired === -1 && current instanceof Empty;
  }
  // @internal
  countLength() {
    let current = this;
    let length4 = 0;
    while (current) {
      current = current.tail;
      length4++;
    }
    return length4 - 1;
  }
};
function prepend(element5, tail) {
  return new NonEmpty(element5, tail);
}
function toList(elements, tail) {
  return List.fromArray(elements, tail);
}
var ListIterator = class {
  #current;
  constructor(current) {
    this.#current = current;
  }
  next() {
    if (this.#current instanceof Empty) {
      return { done: true };
    } else {
      let { head, tail } = this.#current;
      this.#current = tail;
      return { value: head, done: false };
    }
  }
};
var Empty = class extends List {
};
var NonEmpty = class extends List {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
};
var BitArray = class {
  /**
   * The size in bits of this bit array's data.
   *
   * @type {number}
   */
  bitSize;
  /**
   * The size in bytes of this bit array's data. If this bit array doesn't store
   * a whole number of bytes then this value is rounded up.
   *
   * @type {number}
   */
  byteSize;
  /**
   * The number of unused high bits in the first byte of this bit array's
   * buffer prior to the start of its data. The value of any unused high bits is
   * undefined.
   *
   * The bit offset will be in the range 0-7.
   *
   * @type {number}
   */
  bitOffset;
  /**
   * The raw bytes that hold this bit array's data.
   *
   * If `bitOffset` is not zero then there are unused high bits in the first
   * byte of this buffer.
   *
   * If `bitOffset + bitSize` is not a multiple of 8 then there are unused low
   * bits in the last byte of this buffer.
   *
   * @type {Uint8Array}
   */
  rawBuffer;
  /**
   * Constructs a new bit array from a `Uint8Array`, an optional size in
   * bits, and an optional bit offset.
   *
   * If no bit size is specified it is taken as `buffer.length * 8`, i.e. all
   * bytes in the buffer make up the new bit array's data.
   *
   * If no bit offset is specified it defaults to zero, i.e. there are no unused
   * high bits in the first byte of the buffer.
   *
   * @param {Uint8Array} buffer
   * @param {number} [bitSize]
   * @param {number} [bitOffset]
   */
  constructor(buffer, bitSize, bitOffset) {
    if (!(buffer instanceof Uint8Array)) {
      throw globalThis.Error(
        "BitArray can only be constructed from a Uint8Array"
      );
    }
    this.bitSize = bitSize ?? buffer.length * 8;
    this.byteSize = Math.trunc((this.bitSize + 7) / 8);
    this.bitOffset = bitOffset ?? 0;
    if (this.bitSize < 0) {
      throw globalThis.Error(`BitArray bit size is invalid: ${this.bitSize}`);
    }
    if (this.bitOffset < 0 || this.bitOffset > 7) {
      throw globalThis.Error(
        `BitArray bit offset is invalid: ${this.bitOffset}`
      );
    }
    if (buffer.length !== Math.trunc((this.bitOffset + this.bitSize + 7) / 8)) {
      throw globalThis.Error("BitArray buffer length is invalid");
    }
    this.rawBuffer = buffer;
  }
  /**
   * Returns a specific byte in this bit array. If the byte index is out of
   * range then `undefined` is returned.
   *
   * When returning the final byte of a bit array with a bit size that's not a
   * multiple of 8, the content of the unused low bits are undefined.
   *
   * @param {number} index
   * @returns {number | undefined}
   */
  byteAt(index5) {
    if (index5 < 0 || index5 >= this.byteSize) {
      return void 0;
    }
    return bitArrayByteAt(this.rawBuffer, this.bitOffset, index5);
  }
  /** @internal */
  equals(other) {
    if (this.bitSize !== other.bitSize) {
      return false;
    }
    const wholeByteCount = Math.trunc(this.bitSize / 8);
    if (this.bitOffset === 0 && other.bitOffset === 0) {
      for (let i = 0; i < wholeByteCount; i++) {
        if (this.rawBuffer[i] !== other.rawBuffer[i]) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (this.rawBuffer[wholeByteCount] >> unusedLowBitCount !== other.rawBuffer[wholeByteCount] >> unusedLowBitCount) {
          return false;
        }
      }
    } else {
      for (let i = 0; i < wholeByteCount; i++) {
        const a = bitArrayByteAt(this.rawBuffer, this.bitOffset, i);
        const b = bitArrayByteAt(other.rawBuffer, other.bitOffset, i);
        if (a !== b) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const a = bitArrayByteAt(
          this.rawBuffer,
          this.bitOffset,
          wholeByteCount
        );
        const b = bitArrayByteAt(
          other.rawBuffer,
          other.bitOffset,
          wholeByteCount
        );
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (a >> unusedLowBitCount !== b >> unusedLowBitCount) {
          return false;
        }
      }
    }
    return true;
  }
  /**
   * Returns this bit array's internal buffer.
   *
   * @deprecated Use `BitArray.byteAt()` or `BitArray.rawBuffer` instead.
   *
   * @returns {Uint8Array}
   */
  get buffer() {
    bitArrayPrintDeprecationWarning(
      "buffer",
      "Use BitArray.byteAt() or BitArray.rawBuffer instead"
    );
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.buffer does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer;
  }
  /**
   * Returns the length in bytes of this bit array's internal buffer.
   *
   * @deprecated Use `BitArray.bitSize` or `BitArray.byteSize` instead.
   *
   * @returns {number}
   */
  get length() {
    bitArrayPrintDeprecationWarning(
      "length",
      "Use BitArray.bitSize or BitArray.byteSize instead"
    );
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.length does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer.length;
  }
};
function bitArrayByteAt(buffer, bitOffset, index5) {
  if (bitOffset === 0) {
    return buffer[index5] ?? 0;
  } else {
    const a = buffer[index5] << bitOffset & 255;
    const b = buffer[index5 + 1] >> 8 - bitOffset;
    return a | b;
  }
}
var UtfCodepoint = class {
  constructor(value2) {
    this.value = value2;
  }
};
var isBitArrayDeprecationMessagePrinted = {};
function bitArrayPrintDeprecationWarning(name2, message2) {
  if (isBitArrayDeprecationMessagePrinted[name2]) {
    return;
  }
  console.warn(
    `Deprecated BitArray.${name2} property used in JavaScript FFI code. ${message2}.`
  );
  isBitArrayDeprecationMessagePrinted[name2] = true;
}
var Result = class _Result extends CustomType {
  // @internal
  static isResult(data) {
    return data instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value2) {
    super();
    this[0] = value2;
  }
  // @internal
  isOk() {
    return true;
  }
};
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  // @internal
  isOk() {
    return false;
  }
};
function isEqual(x, y) {
  let values3 = [x, y];
  while (values3.length) {
    let a = values3.pop();
    let b = values3.pop();
    if (a === b) continue;
    if (!isObject(a) || !isObject(b)) return false;
    let unequal = !structurallyCompatibleObjects(a, b) || unequalDates(a, b) || unequalBuffers(a, b) || unequalArrays(a, b) || unequalMaps(a, b) || unequalSets(a, b) || unequalRegExps(a, b);
    if (unequal) return false;
    const proto = Object.getPrototypeOf(a);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a.equals(b)) continue;
        else return false;
      } catch {
      }
    }
    let [keys2, get2] = getters(a);
    const ka = keys2(a);
    const kb = keys2(b);
    if (ka.length !== kb.length) return false;
    for (let k of ka) {
      values3.push(get2(a, k), get2(b, k));
    }
  }
  return true;
}
function getters(object4) {
  if (object4 instanceof Map) {
    return [(x) => x.keys(), (x, y) => x.get(y)];
  } else {
    let extra = object4 instanceof globalThis.Error ? ["message"] : [];
    return [(x) => [...extra, ...Object.keys(x)], (x, y) => x[y]];
  }
}
function unequalDates(a, b) {
  return a instanceof Date && (a > b || a < b);
}
function unequalBuffers(a, b) {
  return !(a instanceof BitArray) && a.buffer instanceof ArrayBuffer && a.BYTES_PER_ELEMENT && !(a.byteLength === b.byteLength && a.every((n, i) => n === b[i]));
}
function unequalArrays(a, b) {
  return Array.isArray(a) && a.length !== b.length;
}
function unequalMaps(a, b) {
  return a instanceof Map && a.size !== b.size;
}
function unequalSets(a, b) {
  return a instanceof Set && (a.size != b.size || [...a].some((e) => !b.has(e)));
}
function unequalRegExps(a, b) {
  return a instanceof RegExp && (a.source !== b.source || a.flags !== b.flags);
}
function isObject(a) {
  return typeof a === "object" && a !== null;
}
function structurallyCompatibleObjects(a, b) {
  if (typeof a !== "object" && typeof b !== "object" && (!a || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a instanceof c)) return false;
  return a.constructor === b.constructor;
}
function remainderInt(a, b) {
  if (b === 0) {
    return 0;
  } else {
    return a % b;
  }
}
function divideInt(a, b) {
  return Math.trunc(divideFloat(a, b));
}
function divideFloat(a, b) {
  if (b === 0) {
    return 0;
  } else {
    return a / b;
  }
}
function makeError(variant, file, module, line, fn, message2, extra) {
  let error = new globalThis.Error(message2);
  error.gleam_error = variant;
  error.file = file;
  error.module = module;
  error.line = line;
  error.function = fn;
  error.fn = fn;
  for (let k in extra) error[k] = extra[k];
  return error;
}

// build/dev/javascript/gleam_stdlib/gleam/option.mjs
var Some = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var None = class extends CustomType {
};
function is_none(option) {
  return isEqual(option, new None());
}
function to_result(option, e) {
  if (option instanceof Some) {
    let a = option[0];
    return new Ok(a);
  } else {
    return new Error(e);
  }
}
function from_result(result) {
  if (result instanceof Ok) {
    let a = result[0];
    return new Some(a);
  } else {
    return new None();
  }
}
function unwrap(option, default$) {
  if (option instanceof Some) {
    let x = option[0];
    return x;
  } else {
    return default$;
  }
}
function map(option, fun) {
  if (option instanceof Some) {
    let x = option[0];
    return new Some(fun(x));
  } else {
    return option;
  }
}
function or(first2, second2) {
  if (first2 instanceof Some) {
    return first2;
  } else {
    return second2;
  }
}

// build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = /* @__PURE__ */ new DataView(
  /* @__PURE__ */ new ArrayBuffer(8)
);
var referenceUID = 0;
function hashByReference(o) {
  const known = referenceMap.get(o);
  if (known !== void 0) {
    return known;
  }
  const hash = referenceUID++;
  if (referenceUID === 2147483647) {
    referenceUID = 0;
  }
  referenceMap.set(o, hash);
  return hash;
}
function hashMerge(a, b) {
  return a ^ b + 2654435769 + (a << 6) + (a >> 2) | 0;
}
function hashString(s) {
  let hash = 0;
  const len = s.length;
  for (let i = 0; i < len; i++) {
    hash = Math.imul(31, hash) + s.charCodeAt(i) | 0;
  }
  return hash;
}
function hashNumber(n) {
  tempDataView.setFloat64(0, n);
  const i = tempDataView.getInt32(0);
  const j = tempDataView.getInt32(4);
  return Math.imul(73244475, i >> 16 ^ i) ^ j;
}
function hashBigInt(n) {
  return hashString(n.toString());
}
function hashObject(o) {
  const proto = Object.getPrototypeOf(o);
  if (proto !== null && typeof proto.hashCode === "function") {
    try {
      const code = o.hashCode(o);
      if (typeof code === "number") {
        return code;
      }
    } catch {
    }
  }
  if (o instanceof Promise || o instanceof WeakSet || o instanceof WeakMap) {
    return hashByReference(o);
  }
  if (o instanceof Date) {
    return hashNumber(o.getTime());
  }
  let h = 0;
  if (o instanceof ArrayBuffer) {
    o = new Uint8Array(o);
  }
  if (Array.isArray(o) || o instanceof Uint8Array) {
    for (let i = 0; i < o.length; i++) {
      h = Math.imul(31, h) + getHash(o[i]) | 0;
    }
  } else if (o instanceof Set) {
    o.forEach((v) => {
      h = h + getHash(v) | 0;
    });
  } else if (o instanceof Map) {
    o.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
  } else {
    const keys2 = Object.keys(o);
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      const v = o[k];
      h = h + hashMerge(getHash(v), hashString(k)) | 0;
    }
  }
  return h;
}
function getHash(u) {
  if (u === null) return 1108378658;
  if (u === void 0) return 1108378659;
  if (u === true) return 1108378657;
  if (u === false) return 1108378656;
  switch (typeof u) {
    case "number":
      return hashNumber(u);
    case "string":
      return hashString(u);
    case "bigint":
      return hashBigInt(u);
    case "object":
      return hashObject(u);
    case "symbol":
      return hashByReference(u);
    case "function":
      return hashByReference(u);
    default:
      return 0;
  }
}
var SHIFT = 5;
var BUCKET_SIZE = Math.pow(2, SHIFT);
var MASK = BUCKET_SIZE - 1;
var MAX_INDEX_NODE = BUCKET_SIZE / 2;
var MIN_ARRAY_NODE = BUCKET_SIZE / 4;
var ENTRY = 0;
var ARRAY_NODE = 1;
var INDEX_NODE = 2;
var COLLISION_NODE = 3;
var EMPTY = {
  type: INDEX_NODE,
  bitmap: 0,
  array: []
};
function mask(hash, shift) {
  return hash >>> shift & MASK;
}
function bitpos(hash, shift) {
  return 1 << mask(hash, shift);
}
function bitcount(x) {
  x -= x >> 1 & 1431655765;
  x = (x & 858993459) + (x >> 2 & 858993459);
  x = x + (x >> 4) & 252645135;
  x += x >> 8;
  x += x >> 16;
  return x & 127;
}
function index(bitmap, bit) {
  return bitcount(bitmap & bit - 1);
}
function cloneAndSet(arr, at2, val) {
  const len = arr.length;
  const out = new Array(len);
  for (let i = 0; i < len; ++i) {
    out[i] = arr[i];
  }
  out[at2] = val;
  return out;
}
function spliceIn(arr, at2, val) {
  const len = arr.length;
  const out = new Array(len + 1);
  let i = 0;
  let g = 0;
  while (i < at2) {
    out[g++] = arr[i++];
  }
  out[g++] = val;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function spliceOut(arr, at2) {
  const len = arr.length;
  const out = new Array(len - 1);
  let i = 0;
  let g = 0;
  while (i < at2) {
    out[g++] = arr[i++];
  }
  ++i;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function createNode(shift, key1, val1, key2hash, key2, val2) {
  const key1hash = getHash(key1);
  if (key1hash === key2hash) {
    return {
      type: COLLISION_NODE,
      hash: key1hash,
      array: [
        { type: ENTRY, k: key1, v: val1 },
        { type: ENTRY, k: key2, v: val2 }
      ]
    };
  }
  const addedLeaf = { val: false };
  return assoc(
    assocIndex(EMPTY, shift, key1hash, key1, val1, addedLeaf),
    shift,
    key2hash,
    key2,
    val2,
    addedLeaf
  );
}
function assoc(root3, shift, hash, key, val, addedLeaf) {
  switch (root3.type) {
    case ARRAY_NODE:
      return assocArray(root3, shift, hash, key, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root3, shift, hash, key, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root3, shift, hash, key, val, addedLeaf);
  }
}
function assocArray(root3, shift, hash, key, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node = root3.array[idx];
  if (node === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root3.size + 1,
      array: cloneAndSet(root3.array, idx, { type: ENTRY, k: key, v: val })
    };
  }
  if (node.type === ENTRY) {
    if (isEqual(key, node.k)) {
      if (val === node.v) {
        return root3;
      }
      return {
        type: ARRAY_NODE,
        size: root3.size,
        array: cloneAndSet(root3.array, idx, {
          type: ENTRY,
          k: key,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root3.size,
      array: cloneAndSet(
        root3.array,
        idx,
        createNode(shift + SHIFT, node.k, node.v, hash, key, val)
      )
    };
  }
  const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
  if (n === node) {
    return root3;
  }
  return {
    type: ARRAY_NODE,
    size: root3.size,
    array: cloneAndSet(root3.array, idx, n)
  };
}
function assocIndex(root3, shift, hash, key, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root3.bitmap, bit);
  if ((root3.bitmap & bit) !== 0) {
    const node = root3.array[idx];
    if (node.type !== ENTRY) {
      const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
      if (n === node) {
        return root3;
      }
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap,
        array: cloneAndSet(root3.array, idx, n)
      };
    }
    const nodeKey = node.k;
    if (isEqual(key, nodeKey)) {
      if (val === node.v) {
        return root3;
      }
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap,
        array: cloneAndSet(root3.array, idx, {
          type: ENTRY,
          k: key,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: INDEX_NODE,
      bitmap: root3.bitmap,
      array: cloneAndSet(
        root3.array,
        idx,
        createNode(shift + SHIFT, nodeKey, node.v, hash, key, val)
      )
    };
  } else {
    const n = root3.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key, val, addedLeaf);
      let j = 0;
      let bitmap = root3.bitmap;
      for (let i = 0; i < 32; i++) {
        if ((bitmap & 1) !== 0) {
          const node = root3.array[j++];
          nodes[i] = node;
        }
        bitmap = bitmap >>> 1;
      }
      return {
        type: ARRAY_NODE,
        size: n + 1,
        array: nodes
      };
    } else {
      const newArray = spliceIn(root3.array, idx, {
        type: ENTRY,
        k: key,
        v: val
      });
      addedLeaf.val = true;
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap | bit,
        array: newArray
      };
    }
  }
}
function assocCollision(root3, shift, hash, key, val, addedLeaf) {
  if (hash === root3.hash) {
    const idx = collisionIndexOf(root3, key);
    if (idx !== -1) {
      const entry = root3.array[idx];
      if (entry.v === val) {
        return root3;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root3.array, idx, { type: ENTRY, k: key, v: val })
      };
    }
    const size2 = root3.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root3.array, size2, { type: ENTRY, k: key, v: val })
    };
  }
  return assoc(
    {
      type: INDEX_NODE,
      bitmap: bitpos(root3.hash, shift),
      array: [root3]
    },
    shift,
    hash,
    key,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root3, key) {
  const size2 = root3.array.length;
  for (let i = 0; i < size2; i++) {
    if (isEqual(key, root3.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find(root3, shift, hash, key) {
  switch (root3.type) {
    case ARRAY_NODE:
      return findArray(root3, shift, hash, key);
    case INDEX_NODE:
      return findIndex(root3, shift, hash, key);
    case COLLISION_NODE:
      return findCollision(root3, key);
  }
}
function findArray(root3, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root3.array[idx];
  if (node === void 0) {
    return void 0;
  }
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findIndex(root3, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root3.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root3.bitmap, bit);
  const node = root3.array[idx];
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findCollision(root3, key) {
  const idx = collisionIndexOf(root3, key);
  if (idx < 0) {
    return void 0;
  }
  return root3.array[idx];
}
function without(root3, shift, hash, key) {
  switch (root3.type) {
    case ARRAY_NODE:
      return withoutArray(root3, shift, hash, key);
    case INDEX_NODE:
      return withoutIndex(root3, shift, hash, key);
    case COLLISION_NODE:
      return withoutCollision(root3, key);
  }
}
function withoutArray(root3, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root3.array[idx];
  if (node === void 0) {
    return root3;
  }
  let n = void 0;
  if (node.type === ENTRY) {
    if (!isEqual(node.k, key)) {
      return root3;
    }
  } else {
    n = without(node, shift + SHIFT, hash, key);
    if (n === node) {
      return root3;
    }
  }
  if (n === void 0) {
    if (root3.size <= MIN_ARRAY_NODE) {
      const arr = root3.array;
      const out = new Array(root3.size - 1);
      let i = 0;
      let j = 0;
      let bitmap = 0;
      while (i < idx) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      ++i;
      while (i < arr.length) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      return {
        type: INDEX_NODE,
        bitmap,
        array: out
      };
    }
    return {
      type: ARRAY_NODE,
      size: root3.size - 1,
      array: cloneAndSet(root3.array, idx, n)
    };
  }
  return {
    type: ARRAY_NODE,
    size: root3.size,
    array: cloneAndSet(root3.array, idx, n)
  };
}
function withoutIndex(root3, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root3.bitmap & bit) === 0) {
    return root3;
  }
  const idx = index(root3.bitmap, bit);
  const node = root3.array[idx];
  if (node.type !== ENTRY) {
    const n = without(node, shift + SHIFT, hash, key);
    if (n === node) {
      return root3;
    }
    if (n !== void 0) {
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap,
        array: cloneAndSet(root3.array, idx, n)
      };
    }
    if (root3.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root3.bitmap ^ bit,
      array: spliceOut(root3.array, idx)
    };
  }
  if (isEqual(key, node.k)) {
    if (root3.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root3.bitmap ^ bit,
      array: spliceOut(root3.array, idx)
    };
  }
  return root3;
}
function withoutCollision(root3, key) {
  const idx = collisionIndexOf(root3, key);
  if (idx < 0) {
    return root3;
  }
  if (root3.array.length === 1) {
    return void 0;
  }
  return {
    type: COLLISION_NODE,
    hash: root3.hash,
    array: spliceOut(root3.array, idx)
  };
}
function forEach(root3, fn) {
  if (root3 === void 0) {
    return;
  }
  const items = root3.array;
  const size2 = items.length;
  for (let i = 0; i < size2; i++) {
    const item = items[i];
    if (item === void 0) {
      continue;
    }
    if (item.type === ENTRY) {
      fn(item.v, item.k);
      continue;
    }
    forEach(item, fn);
  }
}
var Dict = class _Dict {
  /**
   * @template V
   * @param {Record<string,V>} o
   * @returns {Dict<string,V>}
   */
  static fromObject(o) {
    const keys2 = Object.keys(o);
    let m = _Dict.new();
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      m = m.set(k, o[k]);
    }
    return m;
  }
  /**
   * @template K,V
   * @param {Map<K,V>} o
   * @returns {Dict<K,V>}
   */
  static fromMap(o) {
    let m = _Dict.new();
    o.forEach((v, k) => {
      m = m.set(k, v);
    });
    return m;
  }
  static new() {
    return new _Dict(void 0, 0);
  }
  /**
   * @param {undefined | Node<K,V>} root
   * @param {number} size
   */
  constructor(root3, size2) {
    this.root = root3;
    this.size = size2;
  }
  /**
   * @template NotFound
   * @param {K} key
   * @param {NotFound} notFound
   * @returns {NotFound | V}
   */
  get(key, notFound) {
    if (this.root === void 0) {
      return notFound;
    }
    const found = find(this.root, 0, getHash(key), key);
    if (found === void 0) {
      return notFound;
    }
    return found.v;
  }
  /**
   * @param {K} key
   * @param {V} val
   * @returns {Dict<K,V>}
   */
  set(key, val) {
    const addedLeaf = { val: false };
    const root3 = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root3, 0, getHash(key), key, val, addedLeaf);
    if (newRoot === this.root) {
      return this;
    }
    return new _Dict(newRoot, addedLeaf.val ? this.size + 1 : this.size);
  }
  /**
   * @param {K} key
   * @returns {Dict<K,V>}
   */
  delete(key) {
    if (this.root === void 0) {
      return this;
    }
    const newRoot = without(this.root, 0, getHash(key), key);
    if (newRoot === this.root) {
      return this;
    }
    if (newRoot === void 0) {
      return _Dict.new();
    }
    return new _Dict(newRoot, this.size - 1);
  }
  /**
   * @param {K} key
   * @returns {boolean}
   */
  has(key) {
    if (this.root === void 0) {
      return false;
    }
    return find(this.root, 0, getHash(key), key) !== void 0;
  }
  /**
   * @returns {[K,V][]}
   */
  entries() {
    if (this.root === void 0) {
      return [];
    }
    const result = [];
    this.forEach((v, k) => result.push([k, v]));
    return result;
  }
  /**
   *
   * @param {(val:V,key:K)=>void} fn
   */
  forEach(fn) {
    forEach(this.root, fn);
  }
  hashCode() {
    let h = 0;
    this.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
    return h;
  }
  /**
   * @param {unknown} o
   * @returns {boolean}
   */
  equals(o) {
    if (!(o instanceof _Dict) || this.size !== o.size) {
      return false;
    }
    try {
      this.forEach((v, k) => {
        if (!isEqual(o.get(k, !v), v)) {
          throw unequalDictSymbol;
        }
      });
      return true;
    } catch (e) {
      if (e === unequalDictSymbol) {
        return false;
      }
      throw e;
    }
  }
};
var unequalDictSymbol = /* @__PURE__ */ Symbol();

// build/dev/javascript/gleam_stdlib/gleam/order.mjs
var Lt = class extends CustomType {
};
var Eq = class extends CustomType {
};
var Gt = class extends CustomType {
};
function break_tie(order, other) {
  if (order instanceof Lt) {
    return order;
  } else if (order instanceof Eq) {
    return other;
  } else {
    return order;
  }
}

// build/dev/javascript/gleam_stdlib/gleam/float.mjs
function negate(x) {
  return -1 * x;
}
function round2(x) {
  let $ = x >= 0;
  if ($) {
    return round(x);
  } else {
    return 0 - round(negate(x));
  }
}

// build/dev/javascript/gleam_stdlib/gleam/int.mjs
function compare(a, b) {
  let $ = a === b;
  if ($) {
    return new Eq();
  } else {
    let $1 = a < b;
    if ($1) {
      return new Lt();
    } else {
      return new Gt();
    }
  }
}

// build/dev/javascript/gleam_stdlib/gleam/list.mjs
var Ascending = class extends CustomType {
};
var Descending = class extends CustomType {
};
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix instanceof Empty) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = prepend(first$1, suffix);
    }
  }
}
function reverse(list4) {
  return reverse_and_prepend(list4, toList([]));
}
function first(list4) {
  if (list4 instanceof Empty) {
    return new Error(void 0);
  } else {
    let first$1 = list4.head;
    return new Ok(first$1);
  }
}
function filter_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4 instanceof Empty) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let _block;
      let $ = fun(first$1);
      if ($) {
        _block = prepend(first$1, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter(list4, predicate) {
  return filter_loop(list4, predicate, toList([]));
}
function filter_map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4 instanceof Empty) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let _block;
      let $ = fun(first$1);
      if ($ instanceof Ok) {
        let first$2 = $[0];
        _block = prepend(first$2, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter_map(list4, fun) {
  return filter_map_loop(list4, fun, toList([]));
}
function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4 instanceof Empty) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = prepend(fun(first$1), acc);
    }
  }
}
function map2(list4, fun) {
  return map_loop(list4, fun, toList([]));
}
function append_loop(loop$first, loop$second) {
  while (true) {
    let first2 = loop$first;
    let second2 = loop$second;
    if (first2 instanceof Empty) {
      return second2;
    } else {
      let first$1 = first2.head;
      let rest$1 = first2.tail;
      loop$first = rest$1;
      loop$second = prepend(first$1, second2);
    }
  }
}
function append(first2, second2) {
  return append_loop(reverse(first2), second2);
}
function prepend2(list4, item) {
  return prepend(item, list4);
}
function flatten_loop(loop$lists, loop$acc) {
  while (true) {
    let lists = loop$lists;
    let acc = loop$acc;
    if (lists instanceof Empty) {
      return reverse(acc);
    } else {
      let list4 = lists.head;
      let further_lists = lists.tail;
      loop$lists = further_lists;
      loop$acc = reverse_and_prepend(list4, acc);
    }
  }
}
function flatten(lists) {
  return flatten_loop(lists, toList([]));
}
function fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list4 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list4 instanceof Empty) {
      return initial;
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, first$1);
      loop$fun = fun;
    }
  }
}
function find2(loop$list, loop$is_desired) {
  while (true) {
    let list4 = loop$list;
    let is_desired = loop$is_desired;
    if (list4 instanceof Empty) {
      return new Error(void 0);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = is_desired(first$1);
      if ($) {
        return new Ok(first$1);
      } else {
        loop$list = rest$1;
        loop$is_desired = is_desired;
      }
    }
  }
}
function find_map(loop$list, loop$fun) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    if (list4 instanceof Empty) {
      return new Error(void 0);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = fun(first$1);
      if ($ instanceof Ok) {
        return $;
      } else {
        loop$list = rest$1;
        loop$fun = fun;
      }
    }
  }
}
function sequences(loop$list, loop$compare, loop$growing, loop$direction, loop$prev, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let compare6 = loop$compare;
    let growing = loop$growing;
    let direction = loop$direction;
    let prev = loop$prev;
    let acc = loop$acc;
    let growing$1 = prepend(prev, growing);
    if (list4 instanceof Empty) {
      if (direction instanceof Ascending) {
        return prepend(reverse(growing$1), acc);
      } else {
        return prepend(growing$1, acc);
      }
    } else {
      let new$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = compare6(prev, new$1);
      if (direction instanceof Ascending) {
        if ($ instanceof Lt) {
          loop$list = rest$1;
          loop$compare = compare6;
          loop$growing = growing$1;
          loop$direction = direction;
          loop$prev = new$1;
          loop$acc = acc;
        } else if ($ instanceof Eq) {
          loop$list = rest$1;
          loop$compare = compare6;
          loop$growing = growing$1;
          loop$direction = direction;
          loop$prev = new$1;
          loop$acc = acc;
        } else {
          let _block;
          if (direction instanceof Ascending) {
            _block = prepend(reverse(growing$1), acc);
          } else {
            _block = prepend(growing$1, acc);
          }
          let acc$1 = _block;
          if (rest$1 instanceof Empty) {
            return prepend(toList([new$1]), acc$1);
          } else {
            let next = rest$1.head;
            let rest$2 = rest$1.tail;
            let _block$1;
            let $1 = compare6(new$1, next);
            if ($1 instanceof Lt) {
              _block$1 = new Ascending();
            } else if ($1 instanceof Eq) {
              _block$1 = new Ascending();
            } else {
              _block$1 = new Descending();
            }
            let direction$1 = _block$1;
            loop$list = rest$2;
            loop$compare = compare6;
            loop$growing = toList([new$1]);
            loop$direction = direction$1;
            loop$prev = next;
            loop$acc = acc$1;
          }
        }
      } else if ($ instanceof Lt) {
        let _block;
        if (direction instanceof Ascending) {
          _block = prepend(reverse(growing$1), acc);
        } else {
          _block = prepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1 instanceof Empty) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare6(new$1, next);
          if ($1 instanceof Lt) {
            _block$1 = new Ascending();
          } else if ($1 instanceof Eq) {
            _block$1 = new Ascending();
          } else {
            _block$1 = new Descending();
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare6;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else if ($ instanceof Eq) {
        let _block;
        if (direction instanceof Ascending) {
          _block = prepend(reverse(growing$1), acc);
        } else {
          _block = prepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1 instanceof Empty) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare6(new$1, next);
          if ($1 instanceof Lt) {
            _block$1 = new Ascending();
          } else if ($1 instanceof Eq) {
            _block$1 = new Ascending();
          } else {
            _block$1 = new Descending();
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare6;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else {
        loop$list = rest$1;
        loop$compare = compare6;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      }
    }
  }
}
function merge_ascendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list22 = loop$list2;
    let compare6 = loop$compare;
    let acc = loop$acc;
    if (list1 instanceof Empty) {
      let list4 = list22;
      return reverse_and_prepend(list4, acc);
    } else if (list22 instanceof Empty) {
      let list4 = list1;
      return reverse_and_prepend(list4, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list22.head;
      let rest2 = list22.tail;
      let $ = compare6(first1, first2);
      if ($ instanceof Lt) {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare6;
        loop$acc = prepend(first1, acc);
      } else if ($ instanceof Eq) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare6;
        loop$acc = prepend(first2, acc);
      } else {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare6;
        loop$acc = prepend(first2, acc);
      }
    }
  }
}
function merge_ascending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare6 = loop$compare;
    let acc = loop$acc;
    if (sequences2 instanceof Empty) {
      return reverse(acc);
    } else {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return reverse(prepend(reverse(sequence), acc));
      } else {
        let ascending1 = sequences2.head;
        let ascending2 = $.head;
        let rest$1 = $.tail;
        let descending = merge_ascendings(
          ascending1,
          ascending2,
          compare6,
          toList([])
        );
        loop$sequences = rest$1;
        loop$compare = compare6;
        loop$acc = prepend(descending, acc);
      }
    }
  }
}
function merge_descendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list22 = loop$list2;
    let compare6 = loop$compare;
    let acc = loop$acc;
    if (list1 instanceof Empty) {
      let list4 = list22;
      return reverse_and_prepend(list4, acc);
    } else if (list22 instanceof Empty) {
      let list4 = list1;
      return reverse_and_prepend(list4, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list22.head;
      let rest2 = list22.tail;
      let $ = compare6(first1, first2);
      if ($ instanceof Lt) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare6;
        loop$acc = prepend(first2, acc);
      } else if ($ instanceof Eq) {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare6;
        loop$acc = prepend(first1, acc);
      } else {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare6;
        loop$acc = prepend(first1, acc);
      }
    }
  }
}
function merge_descending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare6 = loop$compare;
    let acc = loop$acc;
    if (sequences2 instanceof Empty) {
      return reverse(acc);
    } else {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return reverse(prepend(reverse(sequence), acc));
      } else {
        let descending1 = sequences2.head;
        let descending2 = $.head;
        let rest$1 = $.tail;
        let ascending = merge_descendings(
          descending1,
          descending2,
          compare6,
          toList([])
        );
        loop$sequences = rest$1;
        loop$compare = compare6;
        loop$acc = prepend(ascending, acc);
      }
    }
  }
}
function merge_all(loop$sequences, loop$direction, loop$compare) {
  while (true) {
    let sequences2 = loop$sequences;
    let direction = loop$direction;
    let compare6 = loop$compare;
    if (sequences2 instanceof Empty) {
      return sequences2;
    } else if (direction instanceof Ascending) {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return sequence;
      } else {
        let sequences$1 = merge_ascending_pairs(sequences2, compare6, toList([]));
        loop$sequences = sequences$1;
        loop$direction = new Descending();
        loop$compare = compare6;
      }
    } else {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return reverse(sequence);
      } else {
        let sequences$1 = merge_descending_pairs(sequences2, compare6, toList([]));
        loop$sequences = sequences$1;
        loop$direction = new Ascending();
        loop$compare = compare6;
      }
    }
  }
}
function sort(list4, compare6) {
  if (list4 instanceof Empty) {
    return list4;
  } else {
    let $ = list4.tail;
    if ($ instanceof Empty) {
      return list4;
    } else {
      let x = list4.head;
      let y = $.head;
      let rest$1 = $.tail;
      let _block;
      let $1 = compare6(x, y);
      if ($1 instanceof Lt) {
        _block = new Ascending();
      } else if ($1 instanceof Eq) {
        _block = new Ascending();
      } else {
        _block = new Descending();
      }
      let direction = _block;
      let sequences$1 = sequences(
        rest$1,
        compare6,
        toList([x]),
        direction,
        y,
        toList([])
      );
      return merge_all(sequences$1, new Ascending(), compare6);
    }
  }
}
function key_find(keyword_list, desired_key) {
  return find_map(
    keyword_list,
    (keyword) => {
      let key;
      let value2;
      key = keyword[0];
      value2 = keyword[1];
      let $ = isEqual(key, desired_key);
      if ($) {
        return new Ok(value2);
      } else {
        return new Error(void 0);
      }
    }
  );
}
function key_set_loop(loop$list, loop$key, loop$value, loop$inspected) {
  while (true) {
    let list4 = loop$list;
    let key = loop$key;
    let value2 = loop$value;
    let inspected = loop$inspected;
    if (list4 instanceof Empty) {
      return reverse(prepend([key, value2], inspected));
    } else {
      let k = list4.head[0];
      if (isEqual(k, key)) {
        let rest$1 = list4.tail;
        return reverse_and_prepend(inspected, prepend([k, value2], rest$1));
      } else {
        let first$1 = list4.head;
        let rest$1 = list4.tail;
        loop$list = rest$1;
        loop$key = key;
        loop$value = value2;
        loop$inspected = prepend(first$1, inspected);
      }
    }
  }
}
function key_set(list4, key, value2) {
  return key_set_loop(list4, key, value2, toList([]));
}

// build/dev/javascript/gleam_stdlib/gleam/string.mjs
function compare3(a, b) {
  let $ = a === b;
  if ($) {
    return new Eq();
  } else {
    let $1 = less_than(a, b);
    if ($1) {
      return new Lt();
    } else {
      return new Gt();
    }
  }
}
function concat_loop(loop$strings, loop$accumulator) {
  while (true) {
    let strings = loop$strings;
    let accumulator = loop$accumulator;
    if (strings instanceof Empty) {
      return accumulator;
    } else {
      let string5 = strings.head;
      let strings$1 = strings.tail;
      loop$strings = strings$1;
      loop$accumulator = accumulator + string5;
    }
  }
}
function concat2(strings) {
  return concat_loop(strings, "");
}
function trim(string5) {
  let _pipe = string5;
  let _pipe$1 = trim_start(_pipe);
  return trim_end(_pipe$1);
}
function split2(x, substring) {
  if (substring === "") {
    return graphemes(x);
  } else {
    let _pipe = x;
    let _pipe$1 = identity(_pipe);
    let _pipe$2 = split(_pipe$1, substring);
    return map2(_pipe$2, identity);
  }
}
function inspect2(term) {
  let _pipe = inspect(term);
  return identity(_pipe);
}

// build/dev/javascript/gleam_stdlib/gleam/dynamic/decode.mjs
var DecodeError = class extends CustomType {
  constructor(expected, found, path2) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path2;
  }
};
var Decoder = class extends CustomType {
  constructor(function$) {
    super();
    this.function = function$;
  }
};
function run(data, decoder) {
  let $ = decoder.function(data);
  let maybe_invalid_data;
  let errors;
  maybe_invalid_data = $[0];
  errors = $[1];
  if (errors instanceof Empty) {
    return new Ok(maybe_invalid_data);
  } else {
    return new Error(errors);
  }
}
function success(data) {
  return new Decoder((_) => {
    return [data, toList([])];
  });
}
function map3(decoder, transformer) {
  return new Decoder(
    (d) => {
      let $ = decoder.function(d);
      let data;
      let errors;
      data = $[0];
      errors = $[1];
      return [transformer(data), errors];
    }
  );
}
function then$(decoder, next) {
  return new Decoder(
    (dynamic_data) => {
      let $ = decoder.function(dynamic_data);
      let data;
      let errors;
      data = $[0];
      errors = $[1];
      let decoder$1 = next(data);
      let $1 = decoder$1.function(dynamic_data);
      let layer;
      let data$1;
      layer = $1;
      data$1 = $1[0];
      if (errors instanceof Empty) {
        return layer;
      } else {
        return [data$1, errors];
      }
    }
  );
}
function run_decoders(loop$data, loop$failure, loop$decoders) {
  while (true) {
    let data = loop$data;
    let failure2 = loop$failure;
    let decoders = loop$decoders;
    if (decoders instanceof Empty) {
      return failure2;
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder.function(data);
      let layer;
      let errors;
      layer = $;
      errors = $[1];
      if (errors instanceof Empty) {
        return layer;
      } else {
        loop$data = data;
        loop$failure = failure2;
        loop$decoders = decoders$1;
      }
    }
  }
}
function one_of(first2, alternatives) {
  return new Decoder(
    (dynamic_data) => {
      let $ = first2.function(dynamic_data);
      let layer;
      let errors;
      layer = $;
      errors = $[1];
      if (errors instanceof Empty) {
        return layer;
      } else {
        return run_decoders(dynamic_data, layer, alternatives);
      }
    }
  );
}
function optional(inner) {
  return new Decoder(
    (data) => {
      let $ = is_null(data);
      if ($) {
        return [new None(), toList([])];
      } else {
        let $1 = inner.function(data);
        let data$1;
        let errors;
        data$1 = $1[0];
        errors = $1[1];
        return [new Some(data$1), errors];
      }
    }
  );
}
function decode_error(expected, found) {
  return toList([
    new DecodeError(expected, classify_dynamic(found), toList([]))
  ]);
}
function run_dynamic_function(data, name2, f) {
  let $ = f(data);
  if ($ instanceof Ok) {
    let data$1 = $[0];
    return [data$1, toList([])];
  } else {
    let zero = $[0];
    return [
      zero,
      toList([new DecodeError(name2, classify_dynamic(data), toList([]))])
    ];
  }
}
function decode_bool(data) {
  let $ = isEqual(identity(true), data);
  if ($) {
    return [true, toList([])];
  } else {
    let $1 = isEqual(identity(false), data);
    if ($1) {
      return [false, toList([])];
    } else {
      return [false, decode_error("Bool", data)];
    }
  }
}
function decode_int(data) {
  return run_dynamic_function(data, "Int", int);
}
function failure(zero, expected) {
  return new Decoder((d) => {
    return [zero, decode_error(expected, d)];
  });
}
var bool = /* @__PURE__ */ new Decoder(decode_bool);
var int2 = /* @__PURE__ */ new Decoder(decode_int);
function decode_string(data) {
  return run_dynamic_function(data, "String", string);
}
var string2 = /* @__PURE__ */ new Decoder(decode_string);
function list2(inner) {
  return new Decoder(
    (data) => {
      return list(
        data,
        inner.function,
        (p2, k) => {
          return push_path(p2, toList([k]));
        },
        0,
        toList([])
      );
    }
  );
}
function push_path(layer, path2) {
  let decoder = one_of(
    string2,
    toList([
      (() => {
        let _pipe = int2;
        return map3(_pipe, to_string);
      })()
    ])
  );
  let path$1 = map2(
    path2,
    (key) => {
      let key$1 = identity(key);
      let $ = run(key$1, decoder);
      if ($ instanceof Ok) {
        let key$2 = $[0];
        return key$2;
      } else {
        return "<" + classify_dynamic(key$1) + ">";
      }
    }
  );
  let errors = map2(
    layer[1],
    (error) => {
      return new DecodeError(
        error.expected,
        error.found,
        append(path$1, error.path)
      );
    }
  );
  return [layer[0], errors];
}
function index3(loop$path, loop$position, loop$inner, loop$data, loop$handle_miss) {
  while (true) {
    let path2 = loop$path;
    let position = loop$position;
    let inner = loop$inner;
    let data = loop$data;
    let handle_miss = loop$handle_miss;
    if (path2 instanceof Empty) {
      let _pipe = inner(data);
      return push_path(_pipe, reverse(position));
    } else {
      let key = path2.head;
      let path$1 = path2.tail;
      let $ = index2(data, key);
      if ($ instanceof Ok) {
        let $1 = $[0];
        if ($1 instanceof Some) {
          let data$1 = $1[0];
          loop$path = path$1;
          loop$position = prepend(key, position);
          loop$inner = inner;
          loop$data = data$1;
          loop$handle_miss = handle_miss;
        } else {
          return handle_miss(data, prepend(key, position));
        }
      } else {
        let kind = $[0];
        let $1 = inner(data);
        let default$;
        default$ = $1[0];
        let _pipe = [
          default$,
          toList([new DecodeError(kind, classify_dynamic(data), toList([]))])
        ];
        return push_path(_pipe, reverse(position));
      }
    }
  }
}
function subfield(field_path, field_decoder, next) {
  return new Decoder(
    (data) => {
      let $ = index3(
        field_path,
        toList([]),
        field_decoder.function,
        data,
        (data2, position) => {
          let $12 = field_decoder.function(data2);
          let default$;
          default$ = $12[0];
          let _pipe = [
            default$,
            toList([new DecodeError("Field", "Nothing", toList([]))])
          ];
          return push_path(_pipe, reverse(position));
        }
      );
      let out;
      let errors1;
      out = $[0];
      errors1 = $[1];
      let $1 = next(out).function(data);
      let out$1;
      let errors2;
      out$1 = $1[0];
      errors2 = $1[1];
      return [out$1, append(errors1, errors2)];
    }
  );
}
function at(path2, inner) {
  return new Decoder(
    (data) => {
      return index3(
        path2,
        toList([]),
        inner.function,
        data,
        (data2, position) => {
          let $ = inner.function(data2);
          let default$;
          default$ = $[0];
          let _pipe = [
            default$,
            toList([new DecodeError("Field", "Nothing", toList([]))])
          ];
          return push_path(_pipe, reverse(position));
        }
      );
    }
  );
}
function field(field_name, field_decoder, next) {
  return subfield(toList([field_name]), field_decoder, next);
}

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var Nil = void 0;
var NOT_FOUND = {};
function identity(x) {
  return x;
}
function to_string(term) {
  return term.toString();
}
function string_length(string5) {
  if (string5 === "") {
    return 0;
  }
  const iterator = graphemes_iterator(string5);
  if (iterator) {
    let i = 0;
    for (const _ of iterator) {
      i++;
    }
    return i;
  } else {
    return string5.match(/./gsu).length;
  }
}
function graphemes(string5) {
  const iterator = graphemes_iterator(string5);
  if (iterator) {
    return List.fromArray(Array.from(iterator).map((item) => item.segment));
  } else {
    return List.fromArray(string5.match(/./gsu));
  }
}
var segmenter = void 0;
function graphemes_iterator(string5) {
  if (globalThis.Intl && Intl.Segmenter) {
    segmenter ||= new Intl.Segmenter();
    return segmenter.segment(string5)[Symbol.iterator]();
  }
}
function pop_codeunit(str) {
  return [str.charCodeAt(0) | 0, str.slice(1)];
}
function lowercase(string5) {
  return string5.toLowerCase();
}
function less_than(a, b) {
  return a < b;
}
function split(xs, pattern) {
  return List.fromArray(xs.split(pattern));
}
function string_codeunit_slice(str, from2, length4) {
  return str.slice(from2, from2 + length4);
}
function starts_with(haystack, needle) {
  return haystack.startsWith(needle);
}
function split_once(haystack, needle) {
  const index5 = haystack.indexOf(needle);
  if (index5 >= 0) {
    const before = haystack.slice(0, index5);
    const after = haystack.slice(index5 + needle.length);
    return new Ok([before, after]);
  } else {
    return new Error(Nil);
  }
}
var unicode_whitespaces = [
  " ",
  // Space
  "	",
  // Horizontal tab
  "\n",
  // Line feed
  "\v",
  // Vertical tab
  "\f",
  // Form feed
  "\r",
  // Carriage return
  "\x85",
  // Next line
  "\u2028",
  // Line separator
  "\u2029"
  // Paragraph separator
].join("");
var trim_start_regex = /* @__PURE__ */ new RegExp(
  `^[${unicode_whitespaces}]*`
);
var trim_end_regex = /* @__PURE__ */ new RegExp(`[${unicode_whitespaces}]*$`);
function trim_start(string5) {
  return string5.replace(trim_start_regex, "");
}
function trim_end(string5) {
  return string5.replace(trim_end_regex, "");
}
function console_log(term) {
  console.log(term);
}
function round(float2) {
  return Math.round(float2);
}
function new_map() {
  return Dict.new();
}
function map_to_list(map6) {
  return List.fromArray(map6.entries());
}
function map_get(map6, key) {
  const value2 = map6.get(key, NOT_FOUND);
  if (value2 === NOT_FOUND) {
    return new Error(Nil);
  }
  return new Ok(value2);
}
function map_insert(key, value2, map6) {
  return map6.set(key, value2);
}
function classify_dynamic(data) {
  if (typeof data === "string") {
    return "String";
  } else if (typeof data === "boolean") {
    return "Bool";
  } else if (data instanceof Result) {
    return "Result";
  } else if (data instanceof List) {
    return "List";
  } else if (data instanceof BitArray) {
    return "BitArray";
  } else if (data instanceof Dict) {
    return "Dict";
  } else if (Number.isInteger(data)) {
    return "Int";
  } else if (Array.isArray(data)) {
    return `Array`;
  } else if (typeof data === "number") {
    return "Float";
  } else if (data === null) {
    return "Nil";
  } else if (data === void 0) {
    return "Nil";
  } else {
    const type = typeof data;
    return type.charAt(0).toUpperCase() + type.slice(1);
  }
}
function inspect(v) {
  return new Inspector().inspect(v);
}
function float_to_string(float2) {
  const string5 = float2.toString().replace("+", "");
  if (string5.indexOf(".") >= 0) {
    return string5;
  } else {
    const index5 = string5.indexOf("e");
    if (index5 >= 0) {
      return string5.slice(0, index5) + ".0" + string5.slice(index5);
    } else {
      return string5 + ".0";
    }
  }
}
var Inspector = class {
  #references = /* @__PURE__ */ new Set();
  inspect(v) {
    const t = typeof v;
    if (v === true) return "True";
    if (v === false) return "False";
    if (v === null) return "//js(null)";
    if (v === void 0) return "Nil";
    if (t === "string") return this.#string(v);
    if (t === "bigint" || Number.isInteger(v)) return v.toString();
    if (t === "number") return float_to_string(v);
    if (v instanceof UtfCodepoint) return this.#utfCodepoint(v);
    if (v instanceof BitArray) return this.#bit_array(v);
    if (v instanceof RegExp) return `//js(${v})`;
    if (v instanceof Date) return `//js(Date("${v.toISOString()}"))`;
    if (v instanceof globalThis.Error) return `//js(${v.toString()})`;
    if (v instanceof Function) {
      const args = [];
      for (const i of Array(v.length).keys())
        args.push(String.fromCharCode(i + 97));
      return `//fn(${args.join(", ")}) { ... }`;
    }
    if (this.#references.size === this.#references.add(v).size) {
      return "//js(circular reference)";
    }
    let printed;
    if (Array.isArray(v)) {
      printed = `#(${v.map((v2) => this.inspect(v2)).join(", ")})`;
    } else if (v instanceof List) {
      printed = this.#list(v);
    } else if (v instanceof CustomType) {
      printed = this.#customType(v);
    } else if (v instanceof Dict) {
      printed = this.#dict(v);
    } else if (v instanceof Set) {
      return `//js(Set(${[...v].map((v2) => this.inspect(v2)).join(", ")}))`;
    } else {
      printed = this.#object(v);
    }
    this.#references.delete(v);
    return printed;
  }
  #object(v) {
    const name2 = Object.getPrototypeOf(v)?.constructor?.name || "Object";
    const props = [];
    for (const k of Object.keys(v)) {
      props.push(`${this.inspect(k)}: ${this.inspect(v[k])}`);
    }
    const body = props.length ? " " + props.join(", ") + " " : "";
    const head = name2 === "Object" ? "" : name2 + " ";
    return `//js(${head}{${body}})`;
  }
  #dict(map6) {
    let body = "dict.from_list([";
    let first2 = true;
    map6.forEach((value2, key) => {
      if (!first2) body = body + ", ";
      body = body + "#(" + this.inspect(key) + ", " + this.inspect(value2) + ")";
      first2 = false;
    });
    return body + "])";
  }
  #customType(record) {
    const props = Object.keys(record).map((label2) => {
      const value2 = this.inspect(record[label2]);
      return isNaN(parseInt(label2)) ? `${label2}: ${value2}` : value2;
    }).join(", ");
    return props ? `${record.constructor.name}(${props})` : record.constructor.name;
  }
  #list(list4) {
    if (list4 instanceof Empty) {
      return "[]";
    }
    let char_out = 'charlist.from_string("';
    let list_out = "[";
    let current = list4;
    while (current instanceof NonEmpty) {
      let element5 = current.head;
      current = current.tail;
      if (list_out !== "[") {
        list_out += ", ";
      }
      list_out += this.inspect(element5);
      if (char_out) {
        if (Number.isInteger(element5) && element5 >= 32 && element5 <= 126) {
          char_out += String.fromCharCode(element5);
        } else {
          char_out = null;
        }
      }
    }
    if (char_out) {
      return char_out + '")';
    } else {
      return list_out + "]";
    }
  }
  #string(str) {
    let new_str = '"';
    for (let i = 0; i < str.length; i++) {
      const char = str[i];
      switch (char) {
        case "\n":
          new_str += "\\n";
          break;
        case "\r":
          new_str += "\\r";
          break;
        case "	":
          new_str += "\\t";
          break;
        case "\f":
          new_str += "\\f";
          break;
        case "\\":
          new_str += "\\\\";
          break;
        case '"':
          new_str += '\\"';
          break;
        default:
          if (char < " " || char > "~" && char < "\xA0") {
            new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
          } else {
            new_str += char;
          }
      }
    }
    new_str += '"';
    return new_str;
  }
  #utfCodepoint(codepoint2) {
    return `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`;
  }
  #bit_array(bits) {
    if (bits.bitSize === 0) {
      return "<<>>";
    }
    let acc = "<<";
    for (let i = 0; i < bits.byteSize - 1; i++) {
      acc += bits.byteAt(i).toString();
      acc += ", ";
    }
    if (bits.byteSize * 8 === bits.bitSize) {
      acc += bits.byteAt(bits.byteSize - 1).toString();
    } else {
      const trailingBitsCount = bits.bitSize % 8;
      acc += bits.byteAt(bits.byteSize - 1) >> 8 - trailingBitsCount;
      acc += `:size(${trailingBitsCount})`;
    }
    acc += ">>";
    return acc;
  }
};
function index2(data, key) {
  if (data instanceof Dict || data instanceof WeakMap || data instanceof Map) {
    const token = {};
    const entry = data.get(key, token);
    if (entry === token) return new Ok(new None());
    return new Ok(new Some(entry));
  }
  const key_is_int = Number.isInteger(key);
  if (key_is_int && key >= 0 && key < 8 && data instanceof List) {
    let i = 0;
    for (const value2 of data) {
      if (i === key) return new Ok(new Some(value2));
      i++;
    }
    return new Error("Indexable");
  }
  if (key_is_int && Array.isArray(data) || data && typeof data === "object" || data && Object.getPrototypeOf(data) === Object.prototype) {
    if (key in data) return new Ok(new Some(data[key]));
    return new Ok(new None());
  }
  return new Error(key_is_int ? "Indexable" : "Dict");
}
function list(data, decode2, pushPath, index5, emptyList) {
  if (!(data instanceof List || Array.isArray(data))) {
    const error = new DecodeError("List", classify_dynamic(data), emptyList);
    return [emptyList, List.fromArray([error])];
  }
  const decoded = [];
  for (const element5 of data) {
    const layer = decode2(element5);
    const [out, errors] = layer;
    if (errors instanceof NonEmpty) {
      const [_, errors2] = pushPath(layer, index5.toString());
      return [emptyList, errors2];
    }
    decoded.push(out);
    index5++;
  }
  return [List.fromArray(decoded), emptyList];
}
function int(data) {
  if (Number.isInteger(data)) return new Ok(data);
  return new Error(0);
}
function string(data) {
  if (typeof data === "string") return new Ok(data);
  return new Error("");
}
function is_null(data) {
  return data === null || data === void 0;
}

// build/dev/javascript/gleam_stdlib/gleam/dict.mjs
function insert(dict3, key, value2) {
  return map_insert(key, value2, dict3);
}
function upsert(dict3, key, fun) {
  let $ = map_get(dict3, key);
  if ($ instanceof Ok) {
    let value2 = $[0];
    return insert(dict3, key, fun(new Some(value2)));
  } else {
    return insert(dict3, key, fun(new None()));
  }
}

// build/dev/javascript/gleam_stdlib/gleam/result.mjs
function map4(result, fun) {
  if (result instanceof Ok) {
    let x = result[0];
    return new Ok(fun(x));
  } else {
    return result;
  }
}
function map_error(result, fun) {
  if (result instanceof Ok) {
    return result;
  } else {
    let error = result[0];
    return new Error(fun(error));
  }
}
function try$(result, fun) {
  if (result instanceof Ok) {
    let x = result[0];
    return fun(x);
  } else {
    return result;
  }
}
function unwrap2(result, default$) {
  if (result instanceof Ok) {
    let v = result[0];
    return v;
  } else {
    return default$;
  }
}
function values2(results) {
  return filter_map(results, (result) => {
    return result;
  });
}

// build/dev/javascript/gleam_time/gleam/time/duration.mjs
var Duration = class extends CustomType {
  constructor(seconds2, nanoseconds2) {
    super();
    this.seconds = seconds2;
    this.nanoseconds = nanoseconds2;
  }
};
function normalise(duration) {
  let multiplier = 1e9;
  let nanoseconds$1 = remainderInt(duration.nanoseconds, multiplier);
  let overflow = duration.nanoseconds - nanoseconds$1;
  let seconds$1 = duration.seconds + divideInt(overflow, multiplier);
  let $ = nanoseconds$1 >= 0;
  if ($) {
    return new Duration(seconds$1, nanoseconds$1);
  } else {
    return new Duration(seconds$1 - 1, multiplier + nanoseconds$1);
  }
}
function seconds(amount) {
  return new Duration(amount, 0);
}
function milliseconds(amount) {
  let remainder = amount % 1e3;
  let overflow = amount - remainder;
  let nanoseconds$1 = remainder * 1e6;
  let seconds$1 = globalThis.Math.trunc(overflow / 1e3);
  let _pipe = new Duration(seconds$1, nanoseconds$1);
  return normalise(_pipe);
}
function to_seconds(duration) {
  let seconds$1 = identity(duration.seconds);
  let nanoseconds$1 = identity(duration.nanoseconds);
  return seconds$1 + nanoseconds$1 / 1e9;
}
function to_seconds_and_nanoseconds(duration) {
  return [duration.seconds, duration.nanoseconds];
}

// build/dev/javascript/gleam_time/gleam_time_ffi.mjs
function system_time() {
  const now = Date.now();
  const milliseconds2 = now % 1e3;
  const nanoseconds2 = milliseconds2 * 1e6;
  const seconds2 = (now - milliseconds2) / 1e3;
  return [seconds2, nanoseconds2];
}

// build/dev/javascript/gleam_time/gleam/time/timestamp.mjs
var Timestamp = class extends CustomType {
  constructor(seconds2, nanoseconds2) {
    super();
    this.seconds = seconds2;
    this.nanoseconds = nanoseconds2;
  }
};
function normalise2(timestamp) {
  let multiplier = 1e9;
  let nanoseconds2 = remainderInt(timestamp.nanoseconds, multiplier);
  let overflow = timestamp.nanoseconds - nanoseconds2;
  let seconds2 = timestamp.seconds + divideInt(overflow, multiplier);
  let $ = nanoseconds2 >= 0;
  if ($) {
    return new Timestamp(seconds2, nanoseconds2);
  } else {
    return new Timestamp(seconds2 - 1, multiplier + nanoseconds2);
  }
}
function compare4(left, right) {
  return break_tie(
    compare(left.seconds, right.seconds),
    compare(left.nanoseconds, right.nanoseconds)
  );
}
function system_time2() {
  let $ = system_time();
  let seconds2;
  let nanoseconds2;
  seconds2 = $[0];
  nanoseconds2 = $[1];
  return normalise2(new Timestamp(seconds2, nanoseconds2));
}
function add3(timestamp, duration) {
  let $ = to_seconds_and_nanoseconds(duration);
  let seconds2;
  let nanoseconds2;
  seconds2 = $[0];
  nanoseconds2 = $[1];
  let _pipe = new Timestamp(
    timestamp.seconds + seconds2,
    timestamp.nanoseconds + nanoseconds2
  );
  return normalise2(_pipe);
}
function from_unix_seconds(seconds2) {
  return new Timestamp(seconds2, 0);
}
function to_unix_seconds(timestamp) {
  let seconds2 = identity(timestamp.seconds);
  let nanoseconds2 = identity(timestamp.nanoseconds);
  return seconds2 + nanoseconds2 / 1e9;
}
function to_unix_seconds_and_nanoseconds(timestamp) {
  return [timestamp.seconds, timestamp.nanoseconds];
}

// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function negate2(bool4) {
  return !bool4;
}
function guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence;
  } else {
    return alternative();
  }
}

// build/dev/javascript/gleam_stdlib/gleam/function.mjs
function identity2(x) {
  return x;
}

// build/dev/javascript/gleam_json/gleam_json_ffi.mjs
function json_to_string(json2) {
  return JSON.stringify(json2);
}
function object(entries) {
  return Object.fromEntries(entries);
}
function identity3(x) {
  return x;
}
function array(list4) {
  return list4.toArray();
}
function do_null() {
  return null;
}
function decode(string5) {
  try {
    const result = JSON.parse(string5);
    return new Ok(result);
  } catch (err) {
    return new Error(getJsonDecodeError(err, string5));
  }
}
function getJsonDecodeError(stdErr, json2) {
  if (isUnexpectedEndOfInput(stdErr)) return new UnexpectedEndOfInput();
  return toUnexpectedByteError(stdErr, json2);
}
function isUnexpectedEndOfInput(err) {
  const unexpectedEndOfInputRegex = /((unexpected (end|eof))|(end of data)|(unterminated string)|(json( parse error|\.parse)\: expected '(\:|\}|\])'))/i;
  return unexpectedEndOfInputRegex.test(err.message);
}
function toUnexpectedByteError(err, json2) {
  let converters = [
    v8UnexpectedByteError,
    oldV8UnexpectedByteError,
    jsCoreUnexpectedByteError,
    spidermonkeyUnexpectedByteError
  ];
  for (let converter of converters) {
    let result = converter(err, json2);
    if (result) return result;
  }
  return new UnexpectedByte("", 0);
}
function v8UnexpectedByteError(err) {
  const regex = /unexpected token '(.)', ".+" is not valid JSON/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const byte = toHex(match[1]);
  return new UnexpectedByte(byte, -1);
}
function oldV8UnexpectedByteError(err) {
  const regex = /unexpected token (.) in JSON at position (\d+)/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const byte = toHex(match[1]);
  const position = Number(match[2]);
  return new UnexpectedByte(byte, position);
}
function spidermonkeyUnexpectedByteError(err, json2) {
  const regex = /(unexpected character|expected .*) at line (\d+) column (\d+)/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const line = Number(match[2]);
  const column = Number(match[3]);
  const position = getPositionFromMultiline(line, column, json2);
  const byte = toHex(json2[position]);
  return new UnexpectedByte(byte, position);
}
function jsCoreUnexpectedByteError(err) {
  const regex = /unexpected (identifier|token) "(.)"/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const byte = toHex(match[2]);
  return new UnexpectedByte(byte, 0);
}
function toHex(char) {
  return "0x" + char.charCodeAt(0).toString(16).toUpperCase();
}
function getPositionFromMultiline(line, column, string5) {
  if (line === 1) return column - 1;
  let currentLn = 1;
  let position = 0;
  string5.split("").find((char, idx) => {
    if (char === "\n") currentLn += 1;
    if (currentLn === line) {
      position = idx + column;
      return true;
    }
    return false;
  });
  return position;
}

// build/dev/javascript/gleam_json/gleam/json.mjs
var UnexpectedEndOfInput = class extends CustomType {
};
var UnexpectedByte = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var UnableToDecode = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
function do_parse(json2, decoder) {
  return try$(
    decode(json2),
    (dynamic_value) => {
      let _pipe = run(dynamic_value, decoder);
      return map_error(
        _pipe,
        (var0) => {
          return new UnableToDecode(var0);
        }
      );
    }
  );
}
function parse(json2, decoder) {
  return do_parse(json2, decoder);
}
function to_string2(json2) {
  return json_to_string(json2);
}
function string3(input2) {
  return identity3(input2);
}
function bool2(input2) {
  return identity3(input2);
}
function int3(input2) {
  return identity3(input2);
}
function null$() {
  return do_null();
}
function object2(entries) {
  return object(entries);
}
function preprocessed_array(from2) {
  return array(from2);
}
function array2(entries, inner_type) {
  let _pipe = entries;
  let _pipe$1 = map2(_pipe, inner_type);
  return preprocessed_array(_pipe$1);
}

// build/dev/javascript/lustre/lustre/internals/constants.ffi.mjs
var document2 = () => globalThis?.document;
var NAMESPACE_HTML = "http://www.w3.org/1999/xhtml";
var ELEMENT_NODE = 1;
var TEXT_NODE = 3;
var SUPPORTS_MOVE_BEFORE = !!globalThis.HTMLElement?.prototype?.moveBefore;

// build/dev/javascript/lustre/lustre/internals/constants.mjs
var empty_list = /* @__PURE__ */ toList([]);
var option_none = /* @__PURE__ */ new None();

// build/dev/javascript/lustre/lustre/vdom/vattr.ffi.mjs
var GT = /* @__PURE__ */ new Gt();
var LT = /* @__PURE__ */ new Lt();
var EQ = /* @__PURE__ */ new Eq();
function compare5(a, b) {
  if (a.name === b.name) {
    return EQ;
  } else if (a.name < b.name) {
    return LT;
  } else {
    return GT;
  }
}

// build/dev/javascript/lustre/lustre/vdom/vattr.mjs
var Attribute = class extends CustomType {
  constructor(kind, name2, value2) {
    super();
    this.kind = kind;
    this.name = name2;
    this.value = value2;
  }
};
var Property = class extends CustomType {
  constructor(kind, name2, value2) {
    super();
    this.kind = kind;
    this.name = name2;
    this.value = value2;
  }
};
var Event2 = class extends CustomType {
  constructor(kind, name2, handler, include, prevent_default2, stop_propagation, immediate, debounce, throttle) {
    super();
    this.kind = kind;
    this.name = name2;
    this.handler = handler;
    this.include = include;
    this.prevent_default = prevent_default2;
    this.stop_propagation = stop_propagation;
    this.immediate = immediate;
    this.debounce = debounce;
    this.throttle = throttle;
  }
};
var Handler = class extends CustomType {
  constructor(prevent_default2, stop_propagation, message2) {
    super();
    this.prevent_default = prevent_default2;
    this.stop_propagation = stop_propagation;
    this.message = message2;
  }
};
var Never = class extends CustomType {
  constructor(kind) {
    super();
    this.kind = kind;
  }
};
var Always = class extends CustomType {
  constructor(kind) {
    super();
    this.kind = kind;
  }
};
function merge(loop$attributes, loop$merged) {
  while (true) {
    let attributes = loop$attributes;
    let merged = loop$merged;
    if (attributes instanceof Empty) {
      return merged;
    } else {
      let $ = attributes.head;
      if ($ instanceof Attribute) {
        let $1 = $.name;
        if ($1 === "") {
          let rest = attributes.tail;
          loop$attributes = rest;
          loop$merged = merged;
        } else if ($1 === "class") {
          let $2 = $.value;
          if ($2 === "") {
            let rest = attributes.tail;
            loop$attributes = rest;
            loop$merged = merged;
          } else {
            let $3 = attributes.tail;
            if ($3 instanceof Empty) {
              let attribute$1 = $;
              let rest = $3;
              loop$attributes = rest;
              loop$merged = prepend(attribute$1, merged);
            } else {
              let $4 = $3.head;
              if ($4 instanceof Attribute) {
                let $5 = $4.name;
                if ($5 === "class") {
                  let kind = $.kind;
                  let class1 = $2;
                  let rest = $3.tail;
                  let class2 = $4.value;
                  let value2 = class1 + " " + class2;
                  let attribute$1 = new Attribute(kind, "class", value2);
                  loop$attributes = prepend(attribute$1, rest);
                  loop$merged = merged;
                } else {
                  let attribute$1 = $;
                  let rest = $3;
                  loop$attributes = rest;
                  loop$merged = prepend(attribute$1, merged);
                }
              } else {
                let attribute$1 = $;
                let rest = $3;
                loop$attributes = rest;
                loop$merged = prepend(attribute$1, merged);
              }
            }
          }
        } else if ($1 === "style") {
          let $2 = $.value;
          if ($2 === "") {
            let rest = attributes.tail;
            loop$attributes = rest;
            loop$merged = merged;
          } else {
            let $3 = attributes.tail;
            if ($3 instanceof Empty) {
              let attribute$1 = $;
              let rest = $3;
              loop$attributes = rest;
              loop$merged = prepend(attribute$1, merged);
            } else {
              let $4 = $3.head;
              if ($4 instanceof Attribute) {
                let $5 = $4.name;
                if ($5 === "style") {
                  let kind = $.kind;
                  let style1 = $2;
                  let rest = $3.tail;
                  let style2 = $4.value;
                  let value2 = style1 + ";" + style2;
                  let attribute$1 = new Attribute(kind, "style", value2);
                  loop$attributes = prepend(attribute$1, rest);
                  loop$merged = merged;
                } else {
                  let attribute$1 = $;
                  let rest = $3;
                  loop$attributes = rest;
                  loop$merged = prepend(attribute$1, merged);
                }
              } else {
                let attribute$1 = $;
                let rest = $3;
                loop$attributes = rest;
                loop$merged = prepend(attribute$1, merged);
              }
            }
          }
        } else {
          let attribute$1 = $;
          let rest = attributes.tail;
          loop$attributes = rest;
          loop$merged = prepend(attribute$1, merged);
        }
      } else {
        let attribute$1 = $;
        let rest = attributes.tail;
        loop$attributes = rest;
        loop$merged = prepend(attribute$1, merged);
      }
    }
  }
}
function prepare(attributes) {
  if (attributes instanceof Empty) {
    return attributes;
  } else {
    let $ = attributes.tail;
    if ($ instanceof Empty) {
      return attributes;
    } else {
      let _pipe = attributes;
      let _pipe$1 = sort(_pipe, (a, b) => {
        return compare5(b, a);
      });
      return merge(_pipe$1, empty_list);
    }
  }
}
var attribute_kind = 0;
function attribute(name2, value2) {
  return new Attribute(attribute_kind, name2, value2);
}
var property_kind = 1;
function property(name2, value2) {
  return new Property(property_kind, name2, value2);
}
var event_kind = 2;
function event(name2, handler, include, prevent_default2, stop_propagation, immediate, debounce, throttle) {
  return new Event2(
    event_kind,
    name2,
    handler,
    include,
    prevent_default2,
    stop_propagation,
    immediate,
    debounce,
    throttle
  );
}
var never_kind = 0;
var never = /* @__PURE__ */ new Never(never_kind);
var always_kind = 2;
var always = /* @__PURE__ */ new Always(always_kind);

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute2(name2, value2) {
  return attribute(name2, value2);
}
function property2(name2, value2) {
  return property(name2, value2);
}
function boolean_attribute(name2, value2) {
  if (value2) {
    return attribute2(name2, "");
  } else {
    return property2(name2, bool2(false));
  }
}
function class$(name2) {
  return attribute2("class", name2);
}
function disabled(is_disabled) {
  return boolean_attribute("disabled", is_disabled);
}
function name(element_name) {
  return attribute2("name", element_name);
}
function placeholder(text4) {
  return attribute2("placeholder", text4);
}
function type_(control_type) {
  return attribute2("type", control_type);
}
function value(control_value) {
  return attribute2("value", control_value);
}

// build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(synchronous, before_paint2, after_paint) {
    super();
    this.synchronous = synchronous;
    this.before_paint = before_paint2;
    this.after_paint = after_paint;
  }
};
var empty2 = /* @__PURE__ */ new Effect(
  /* @__PURE__ */ toList([]),
  /* @__PURE__ */ toList([]),
  /* @__PURE__ */ toList([])
);
function none() {
  return empty2;
}
function from(effect) {
  let task = (actions) => {
    let dispatch = actions.dispatch;
    return effect(dispatch);
  };
  return new Effect(toList([task]), empty2.before_paint, empty2.after_paint);
}
function event2(name2, data) {
  let task = (actions) => {
    return actions.emit(name2, data);
  };
  return new Effect(toList([task]), empty2.before_paint, empty2.after_paint);
}
function batch(effects) {
  return fold(
    effects,
    empty2,
    (acc, eff) => {
      return new Effect(
        fold(eff.synchronous, acc.synchronous, prepend2),
        fold(eff.before_paint, acc.before_paint, prepend2),
        fold(eff.after_paint, acc.after_paint, prepend2)
      );
    }
  );
}

// build/dev/javascript/lustre/lustre/internals/mutable_map.ffi.mjs
function empty3() {
  return null;
}
function get(map6, key) {
  const value2 = map6?.get(key);
  if (value2 != null) {
    return new Ok(value2);
  } else {
    return new Error(void 0);
  }
}
function has_key2(map6, key) {
  return map6 && map6.has(key);
}
function insert2(map6, key, value2) {
  map6 ??= /* @__PURE__ */ new Map();
  map6.set(key, value2);
  return map6;
}
function remove(map6, key) {
  map6?.delete(key);
  return map6;
}

// build/dev/javascript/lustre/lustre/vdom/path.mjs
var Root = class extends CustomType {
};
var Key = class extends CustomType {
  constructor(key, parent) {
    super();
    this.key = key;
    this.parent = parent;
  }
};
var Index = class extends CustomType {
  constructor(index5, parent) {
    super();
    this.index = index5;
    this.parent = parent;
  }
};
function do_matches(loop$path, loop$candidates) {
  while (true) {
    let path2 = loop$path;
    let candidates = loop$candidates;
    if (candidates instanceof Empty) {
      return false;
    } else {
      let candidate = candidates.head;
      let rest = candidates.tail;
      let $ = starts_with(path2, candidate);
      if ($) {
        return $;
      } else {
        loop$path = path2;
        loop$candidates = rest;
      }
    }
  }
}
function add4(parent, index5, key) {
  if (key === "") {
    return new Index(index5, parent);
  } else {
    return new Key(key, parent);
  }
}
var root2 = /* @__PURE__ */ new Root();
var separator_element = "	";
function do_to_string(loop$path, loop$acc) {
  while (true) {
    let path2 = loop$path;
    let acc = loop$acc;
    if (path2 instanceof Root) {
      if (acc instanceof Empty) {
        return "";
      } else {
        let segments = acc.tail;
        return concat2(segments);
      }
    } else if (path2 instanceof Key) {
      let key = path2.key;
      let parent = path2.parent;
      loop$path = parent;
      loop$acc = prepend(separator_element, prepend(key, acc));
    } else {
      let index5 = path2.index;
      let parent = path2.parent;
      loop$path = parent;
      loop$acc = prepend(
        separator_element,
        prepend(to_string(index5), acc)
      );
    }
  }
}
function to_string3(path2) {
  return do_to_string(path2, toList([]));
}
function matches(path2, candidates) {
  if (candidates instanceof Empty) {
    return false;
  } else {
    return do_matches(to_string3(path2), candidates);
  }
}
var separator_event = "\n";
function event3(path2, event4) {
  return do_to_string(path2, toList([separator_event, event4]));
}

// build/dev/javascript/lustre/lustre/vdom/vnode.mjs
var Fragment = class extends CustomType {
  constructor(kind, key, mapper, children, keyed_children) {
    super();
    this.kind = kind;
    this.key = key;
    this.mapper = mapper;
    this.children = children;
    this.keyed_children = keyed_children;
  }
};
var Element = class extends CustomType {
  constructor(kind, key, mapper, namespace2, tag, attributes, children, keyed_children, self_closing, void$) {
    super();
    this.kind = kind;
    this.key = key;
    this.mapper = mapper;
    this.namespace = namespace2;
    this.tag = tag;
    this.attributes = attributes;
    this.children = children;
    this.keyed_children = keyed_children;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Text = class extends CustomType {
  constructor(kind, key, mapper, content) {
    super();
    this.kind = kind;
    this.key = key;
    this.mapper = mapper;
    this.content = content;
  }
};
var UnsafeInnerHtml = class extends CustomType {
  constructor(kind, key, mapper, namespace2, tag, attributes, inner_html) {
    super();
    this.kind = kind;
    this.key = key;
    this.mapper = mapper;
    this.namespace = namespace2;
    this.tag = tag;
    this.attributes = attributes;
    this.inner_html = inner_html;
  }
};
function is_void_element(tag, namespace2) {
  if (namespace2 === "") {
    if (tag === "area") {
      return true;
    } else if (tag === "base") {
      return true;
    } else if (tag === "br") {
      return true;
    } else if (tag === "col") {
      return true;
    } else if (tag === "embed") {
      return true;
    } else if (tag === "hr") {
      return true;
    } else if (tag === "img") {
      return true;
    } else if (tag === "input") {
      return true;
    } else if (tag === "link") {
      return true;
    } else if (tag === "meta") {
      return true;
    } else if (tag === "param") {
      return true;
    } else if (tag === "source") {
      return true;
    } else if (tag === "track") {
      return true;
    } else if (tag === "wbr") {
      return true;
    } else {
      return false;
    }
  } else {
    return false;
  }
}
function to_keyed(key, node) {
  if (node instanceof Fragment) {
    return new Fragment(
      node.kind,
      key,
      node.mapper,
      node.children,
      node.keyed_children
    );
  } else if (node instanceof Element) {
    return new Element(
      node.kind,
      key,
      node.mapper,
      node.namespace,
      node.tag,
      node.attributes,
      node.children,
      node.keyed_children,
      node.self_closing,
      node.void
    );
  } else if (node instanceof Text) {
    return new Text(node.kind, key, node.mapper, node.content);
  } else {
    return new UnsafeInnerHtml(
      node.kind,
      key,
      node.mapper,
      node.namespace,
      node.tag,
      node.attributes,
      node.inner_html
    );
  }
}
var fragment_kind = 0;
function fragment(key, mapper, children, keyed_children) {
  return new Fragment(fragment_kind, key, mapper, children, keyed_children);
}
var element_kind = 1;
function element(key, mapper, namespace2, tag, attributes, children, keyed_children, self_closing, void$) {
  return new Element(
    element_kind,
    key,
    mapper,
    namespace2,
    tag,
    prepare(attributes),
    children,
    keyed_children,
    self_closing,
    void$ || is_void_element(tag, namespace2)
  );
}
var text_kind = 2;
function text(key, mapper, content) {
  return new Text(text_kind, key, mapper, content);
}
var unsafe_inner_html_kind = 3;

// build/dev/javascript/lustre/lustre/internals/equals.ffi.mjs
var isReferenceEqual = (a, b) => a === b;
var isEqual2 = (a, b) => {
  if (a === b) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  const type = typeof a;
  if (type !== typeof b) {
    return false;
  }
  if (type !== "object") {
    return false;
  }
  const ctor = a.constructor;
  if (ctor !== b.constructor) {
    return false;
  }
  if (Array.isArray(a)) {
    return areArraysEqual(a, b);
  }
  return areObjectsEqual(a, b);
};
var areArraysEqual = (a, b) => {
  let index5 = a.length;
  if (index5 !== b.length) {
    return false;
  }
  while (index5--) {
    if (!isEqual2(a[index5], b[index5])) {
      return false;
    }
  }
  return true;
};
var areObjectsEqual = (a, b) => {
  const properties = Object.keys(a);
  let index5 = properties.length;
  if (Object.keys(b).length !== index5) {
    return false;
  }
  while (index5--) {
    const property3 = properties[index5];
    if (!Object.hasOwn(b, property3)) {
      return false;
    }
    if (!isEqual2(a[property3], b[property3])) {
      return false;
    }
  }
  return true;
};

// build/dev/javascript/lustre/lustre/vdom/events.mjs
var Events = class extends CustomType {
  constructor(handlers, dispatched_paths, next_dispatched_paths) {
    super();
    this.handlers = handlers;
    this.dispatched_paths = dispatched_paths;
    this.next_dispatched_paths = next_dispatched_paths;
  }
};
function new$3() {
  return new Events(
    empty3(),
    empty_list,
    empty_list
  );
}
function tick(events) {
  return new Events(
    events.handlers,
    events.next_dispatched_paths,
    empty_list
  );
}
function do_remove_event(handlers, path2, name2) {
  return remove(handlers, event3(path2, name2));
}
function remove_event(events, path2, name2) {
  let handlers = do_remove_event(events.handlers, path2, name2);
  return new Events(
    handlers,
    events.dispatched_paths,
    events.next_dispatched_paths
  );
}
function remove_attributes(handlers, path2, attributes) {
  return fold(
    attributes,
    handlers,
    (events, attribute3) => {
      if (attribute3 instanceof Event2) {
        let name2 = attribute3.name;
        return do_remove_event(events, path2, name2);
      } else {
        return events;
      }
    }
  );
}
function handle(events, path2, name2, event4) {
  let next_dispatched_paths = prepend(path2, events.next_dispatched_paths);
  let events$1 = new Events(
    events.handlers,
    events.dispatched_paths,
    next_dispatched_paths
  );
  let $ = get(
    events$1.handlers,
    path2 + separator_event + name2
  );
  if ($ instanceof Ok) {
    let handler = $[0];
    return [events$1, run(event4, handler)];
  } else {
    return [events$1, new Error(toList([]))];
  }
}
function has_dispatched_events(events, path2) {
  return matches(path2, events.dispatched_paths);
}
function do_add_event(handlers, mapper, path2, name2, handler) {
  return insert2(
    handlers,
    event3(path2, name2),
    map3(
      handler,
      (handler2) => {
        return new Handler(
          handler2.prevent_default,
          handler2.stop_propagation,
          identity2(mapper)(handler2.message)
        );
      }
    )
  );
}
function add_event(events, mapper, path2, name2, handler) {
  let handlers = do_add_event(events.handlers, mapper, path2, name2, handler);
  return new Events(
    handlers,
    events.dispatched_paths,
    events.next_dispatched_paths
  );
}
function add_attributes(handlers, mapper, path2, attributes) {
  return fold(
    attributes,
    handlers,
    (events, attribute3) => {
      if (attribute3 instanceof Event2) {
        let name2 = attribute3.name;
        let handler = attribute3.handler;
        return do_add_event(events, mapper, path2, name2, handler);
      } else {
        return events;
      }
    }
  );
}
function compose_mapper(mapper, child_mapper) {
  let $ = isReferenceEqual(mapper, identity2);
  let $1 = isReferenceEqual(child_mapper, identity2);
  if ($1) {
    return mapper;
  } else if ($) {
    return child_mapper;
  } else {
    return (msg) => {
      return mapper(child_mapper(msg));
    };
  }
}
function do_remove_children(loop$handlers, loop$path, loop$child_index, loop$children) {
  while (true) {
    let handlers = loop$handlers;
    let path2 = loop$path;
    let child_index = loop$child_index;
    let children = loop$children;
    if (children instanceof Empty) {
      return handlers;
    } else {
      let child = children.head;
      let rest = children.tail;
      let _pipe = handlers;
      let _pipe$1 = do_remove_child(_pipe, path2, child_index, child);
      loop$handlers = _pipe$1;
      loop$path = path2;
      loop$child_index = child_index + 1;
      loop$children = rest;
    }
  }
}
function do_remove_child(handlers, parent, child_index, child) {
  if (child instanceof Fragment) {
    let children = child.children;
    let path2 = add4(parent, child_index, child.key);
    return do_remove_children(handlers, path2, 0, children);
  } else if (child instanceof Element) {
    let attributes = child.attributes;
    let children = child.children;
    let path2 = add4(parent, child_index, child.key);
    let _pipe = handlers;
    let _pipe$1 = remove_attributes(_pipe, path2, attributes);
    return do_remove_children(_pipe$1, path2, 0, children);
  } else if (child instanceof Text) {
    return handlers;
  } else {
    let attributes = child.attributes;
    let path2 = add4(parent, child_index, child.key);
    return remove_attributes(handlers, path2, attributes);
  }
}
function remove_child(events, parent, child_index, child) {
  let handlers = do_remove_child(events.handlers, parent, child_index, child);
  return new Events(
    handlers,
    events.dispatched_paths,
    events.next_dispatched_paths
  );
}
function do_add_children(loop$handlers, loop$mapper, loop$path, loop$child_index, loop$children) {
  while (true) {
    let handlers = loop$handlers;
    let mapper = loop$mapper;
    let path2 = loop$path;
    let child_index = loop$child_index;
    let children = loop$children;
    if (children instanceof Empty) {
      return handlers;
    } else {
      let child = children.head;
      let rest = children.tail;
      let _pipe = handlers;
      let _pipe$1 = do_add_child(_pipe, mapper, path2, child_index, child);
      loop$handlers = _pipe$1;
      loop$mapper = mapper;
      loop$path = path2;
      loop$child_index = child_index + 1;
      loop$children = rest;
    }
  }
}
function do_add_child(handlers, mapper, parent, child_index, child) {
  if (child instanceof Fragment) {
    let children = child.children;
    let path2 = add4(parent, child_index, child.key);
    let composed_mapper = compose_mapper(mapper, child.mapper);
    return do_add_children(handlers, composed_mapper, path2, 0, children);
  } else if (child instanceof Element) {
    let attributes = child.attributes;
    let children = child.children;
    let path2 = add4(parent, child_index, child.key);
    let composed_mapper = compose_mapper(mapper, child.mapper);
    let _pipe = handlers;
    let _pipe$1 = add_attributes(_pipe, composed_mapper, path2, attributes);
    return do_add_children(_pipe$1, composed_mapper, path2, 0, children);
  } else if (child instanceof Text) {
    return handlers;
  } else {
    let attributes = child.attributes;
    let path2 = add4(parent, child_index, child.key);
    let composed_mapper = compose_mapper(mapper, child.mapper);
    return add_attributes(handlers, composed_mapper, path2, attributes);
  }
}
function add_child(events, mapper, parent, index5, child) {
  let handlers = do_add_child(events.handlers, mapper, parent, index5, child);
  return new Events(
    handlers,
    events.dispatched_paths,
    events.next_dispatched_paths
  );
}
function add_children(events, mapper, path2, child_index, children) {
  let handlers = do_add_children(
    events.handlers,
    mapper,
    path2,
    child_index,
    children
  );
  return new Events(
    handlers,
    events.dispatched_paths,
    events.next_dispatched_paths
  );
}

// build/dev/javascript/lustre/lustre/element.mjs
function element2(tag, attributes, children) {
  return element(
    "",
    identity2,
    "",
    tag,
    attributes,
    children,
    empty3(),
    false,
    false
  );
}
function namespaced(namespace2, tag, attributes, children) {
  return element(
    "",
    identity2,
    namespace2,
    tag,
    attributes,
    children,
    empty3(),
    false,
    false
  );
}
function text2(content) {
  return text("", identity2, content);
}
function none2() {
  return text("", identity2, "");
}

// build/dev/javascript/lustre/lustre/element/html.mjs
function text3(content) {
  return text2(content);
}
function footer(attrs, children) {
  return element2("footer", attrs, children);
}
function header(attrs, children) {
  return element2("header", attrs, children);
}
function h1(attrs, children) {
  return element2("h1", attrs, children);
}
function h2(attrs, children) {
  return element2("h2", attrs, children);
}
function h3(attrs, children) {
  return element2("h3", attrs, children);
}
function main(attrs, children) {
  return element2("main", attrs, children);
}
function div(attrs, children) {
  return element2("div", attrs, children);
}
function p(attrs, children) {
  return element2("p", attrs, children);
}
function button(attrs, children) {
  return element2("button", attrs, children);
}
function form(attrs, children) {
  return element2("form", attrs, children);
}
function input(attrs) {
  return element2("input", attrs, empty_list);
}
function label(attrs, children) {
  return element2("label", attrs, children);
}

// build/dev/javascript/lustre/lustre/vdom/patch.mjs
var Patch = class extends CustomType {
  constructor(index5, removed, changes, children) {
    super();
    this.index = index5;
    this.removed = removed;
    this.changes = changes;
    this.children = children;
  }
};
var ReplaceText = class extends CustomType {
  constructor(kind, content) {
    super();
    this.kind = kind;
    this.content = content;
  }
};
var ReplaceInnerHtml = class extends CustomType {
  constructor(kind, inner_html) {
    super();
    this.kind = kind;
    this.inner_html = inner_html;
  }
};
var Update = class extends CustomType {
  constructor(kind, added, removed) {
    super();
    this.kind = kind;
    this.added = added;
    this.removed = removed;
  }
};
var Move = class extends CustomType {
  constructor(kind, key, before) {
    super();
    this.kind = kind;
    this.key = key;
    this.before = before;
  }
};
var Replace = class extends CustomType {
  constructor(kind, index5, with$) {
    super();
    this.kind = kind;
    this.index = index5;
    this.with = with$;
  }
};
var Remove = class extends CustomType {
  constructor(kind, index5) {
    super();
    this.kind = kind;
    this.index = index5;
  }
};
var Insert = class extends CustomType {
  constructor(kind, children, before) {
    super();
    this.kind = kind;
    this.children = children;
    this.before = before;
  }
};
function new$5(index5, removed, changes, children) {
  return new Patch(index5, removed, changes, children);
}
var replace_text_kind = 0;
function replace_text(content) {
  return new ReplaceText(replace_text_kind, content);
}
var replace_inner_html_kind = 1;
function replace_inner_html(inner_html) {
  return new ReplaceInnerHtml(replace_inner_html_kind, inner_html);
}
var update_kind = 2;
function update(added, removed) {
  return new Update(update_kind, added, removed);
}
var move_kind = 3;
function move(key, before) {
  return new Move(move_kind, key, before);
}
var remove_kind = 4;
function remove2(index5) {
  return new Remove(remove_kind, index5);
}
var replace_kind = 5;
function replace2(index5, with$) {
  return new Replace(replace_kind, index5, with$);
}
var insert_kind = 6;
function insert3(children, before) {
  return new Insert(insert_kind, children, before);
}

// build/dev/javascript/lustre/lustre/vdom/diff.mjs
var Diff = class extends CustomType {
  constructor(patch, events) {
    super();
    this.patch = patch;
    this.events = events;
  }
};
var AttributeChange = class extends CustomType {
  constructor(added, removed, events) {
    super();
    this.added = added;
    this.removed = removed;
    this.events = events;
  }
};
function is_controlled(events, namespace2, tag, path2) {
  if (tag === "input" && namespace2 === "") {
    return has_dispatched_events(events, path2);
  } else if (tag === "select" && namespace2 === "") {
    return has_dispatched_events(events, path2);
  } else if (tag === "textarea" && namespace2 === "") {
    return has_dispatched_events(events, path2);
  } else {
    return false;
  }
}
function diff_attributes(loop$controlled, loop$path, loop$mapper, loop$events, loop$old, loop$new, loop$added, loop$removed) {
  while (true) {
    let controlled = loop$controlled;
    let path2 = loop$path;
    let mapper = loop$mapper;
    let events = loop$events;
    let old = loop$old;
    let new$8 = loop$new;
    let added = loop$added;
    let removed = loop$removed;
    if (new$8 instanceof Empty) {
      if (old instanceof Empty) {
        return new AttributeChange(added, removed, events);
      } else {
        let $ = old.head;
        if ($ instanceof Event2) {
          let prev = $;
          let old$1 = old.tail;
          let name2 = $.name;
          let removed$1 = prepend(prev, removed);
          let events$1 = remove_event(events, path2, name2);
          loop$controlled = controlled;
          loop$path = path2;
          loop$mapper = mapper;
          loop$events = events$1;
          loop$old = old$1;
          loop$new = new$8;
          loop$added = added;
          loop$removed = removed$1;
        } else {
          let prev = $;
          let old$1 = old.tail;
          let removed$1 = prepend(prev, removed);
          loop$controlled = controlled;
          loop$path = path2;
          loop$mapper = mapper;
          loop$events = events;
          loop$old = old$1;
          loop$new = new$8;
          loop$added = added;
          loop$removed = removed$1;
        }
      }
    } else if (old instanceof Empty) {
      let $ = new$8.head;
      if ($ instanceof Event2) {
        let next = $;
        let new$1 = new$8.tail;
        let name2 = $.name;
        let handler = $.handler;
        let added$1 = prepend(next, added);
        let events$1 = add_event(events, mapper, path2, name2, handler);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events$1;
        loop$old = old;
        loop$new = new$1;
        loop$added = added$1;
        loop$removed = removed;
      } else {
        let next = $;
        let new$1 = new$8.tail;
        let added$1 = prepend(next, added);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events;
        loop$old = old;
        loop$new = new$1;
        loop$added = added$1;
        loop$removed = removed;
      }
    } else {
      let next = new$8.head;
      let remaining_new = new$8.tail;
      let prev = old.head;
      let remaining_old = old.tail;
      let $ = compare5(prev, next);
      if ($ instanceof Lt) {
        if (prev instanceof Event2) {
          let name2 = prev.name;
          let removed$1 = prepend(prev, removed);
          let events$1 = remove_event(events, path2, name2);
          loop$controlled = controlled;
          loop$path = path2;
          loop$mapper = mapper;
          loop$events = events$1;
          loop$old = remaining_old;
          loop$new = new$8;
          loop$added = added;
          loop$removed = removed$1;
        } else {
          let removed$1 = prepend(prev, removed);
          loop$controlled = controlled;
          loop$path = path2;
          loop$mapper = mapper;
          loop$events = events;
          loop$old = remaining_old;
          loop$new = new$8;
          loop$added = added;
          loop$removed = removed$1;
        }
      } else if ($ instanceof Eq) {
        if (next instanceof Attribute) {
          if (prev instanceof Attribute) {
            let _block;
            let $1 = next.name;
            if ($1 === "value") {
              _block = controlled || prev.value !== next.value;
            } else if ($1 === "checked") {
              _block = controlled || prev.value !== next.value;
            } else if ($1 === "selected") {
              _block = controlled || prev.value !== next.value;
            } else {
              _block = prev.value !== next.value;
            }
            let has_changes = _block;
            let _block$1;
            if (has_changes) {
              _block$1 = prepend(next, added);
            } else {
              _block$1 = added;
            }
            let added$1 = _block$1;
            loop$controlled = controlled;
            loop$path = path2;
            loop$mapper = mapper;
            loop$events = events;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed;
          } else if (prev instanceof Event2) {
            let name2 = prev.name;
            let added$1 = prepend(next, added);
            let removed$1 = prepend(prev, removed);
            let events$1 = remove_event(events, path2, name2);
            loop$controlled = controlled;
            loop$path = path2;
            loop$mapper = mapper;
            loop$events = events$1;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed$1;
          } else {
            let added$1 = prepend(next, added);
            let removed$1 = prepend(prev, removed);
            loop$controlled = controlled;
            loop$path = path2;
            loop$mapper = mapper;
            loop$events = events;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed$1;
          }
        } else if (next instanceof Property) {
          if (prev instanceof Property) {
            let _block;
            let $1 = next.name;
            if ($1 === "scrollLeft") {
              _block = true;
            } else if ($1 === "scrollRight") {
              _block = true;
            } else if ($1 === "value") {
              _block = controlled || !isEqual2(
                prev.value,
                next.value
              );
            } else if ($1 === "checked") {
              _block = controlled || !isEqual2(
                prev.value,
                next.value
              );
            } else if ($1 === "selected") {
              _block = controlled || !isEqual2(
                prev.value,
                next.value
              );
            } else {
              _block = !isEqual2(prev.value, next.value);
            }
            let has_changes = _block;
            let _block$1;
            if (has_changes) {
              _block$1 = prepend(next, added);
            } else {
              _block$1 = added;
            }
            let added$1 = _block$1;
            loop$controlled = controlled;
            loop$path = path2;
            loop$mapper = mapper;
            loop$events = events;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed;
          } else if (prev instanceof Event2) {
            let name2 = prev.name;
            let added$1 = prepend(next, added);
            let removed$1 = prepend(prev, removed);
            let events$1 = remove_event(events, path2, name2);
            loop$controlled = controlled;
            loop$path = path2;
            loop$mapper = mapper;
            loop$events = events$1;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed$1;
          } else {
            let added$1 = prepend(next, added);
            let removed$1 = prepend(prev, removed);
            loop$controlled = controlled;
            loop$path = path2;
            loop$mapper = mapper;
            loop$events = events;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed$1;
          }
        } else if (prev instanceof Event2) {
          let name2 = next.name;
          let handler = next.handler;
          let has_changes = prev.prevent_default.kind !== next.prevent_default.kind || prev.stop_propagation.kind !== next.stop_propagation.kind || prev.immediate !== next.immediate || prev.debounce !== next.debounce || prev.throttle !== next.throttle;
          let _block;
          if (has_changes) {
            _block = prepend(next, added);
          } else {
            _block = added;
          }
          let added$1 = _block;
          let events$1 = add_event(events, mapper, path2, name2, handler);
          loop$controlled = controlled;
          loop$path = path2;
          loop$mapper = mapper;
          loop$events = events$1;
          loop$old = remaining_old;
          loop$new = remaining_new;
          loop$added = added$1;
          loop$removed = removed;
        } else {
          let name2 = next.name;
          let handler = next.handler;
          let added$1 = prepend(next, added);
          let removed$1 = prepend(prev, removed);
          let events$1 = add_event(events, mapper, path2, name2, handler);
          loop$controlled = controlled;
          loop$path = path2;
          loop$mapper = mapper;
          loop$events = events$1;
          loop$old = remaining_old;
          loop$new = remaining_new;
          loop$added = added$1;
          loop$removed = removed$1;
        }
      } else if (next instanceof Event2) {
        let name2 = next.name;
        let handler = next.handler;
        let added$1 = prepend(next, added);
        let events$1 = add_event(events, mapper, path2, name2, handler);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events$1;
        loop$old = old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed;
      } else {
        let added$1 = prepend(next, added);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events;
        loop$old = old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed;
      }
    }
  }
}
function do_diff(loop$old, loop$old_keyed, loop$new, loop$new_keyed, loop$moved, loop$moved_offset, loop$removed, loop$node_index, loop$patch_index, loop$path, loop$changes, loop$children, loop$mapper, loop$events) {
  while (true) {
    let old = loop$old;
    let old_keyed = loop$old_keyed;
    let new$8 = loop$new;
    let new_keyed = loop$new_keyed;
    let moved = loop$moved;
    let moved_offset = loop$moved_offset;
    let removed = loop$removed;
    let node_index = loop$node_index;
    let patch_index = loop$patch_index;
    let path2 = loop$path;
    let changes = loop$changes;
    let children = loop$children;
    let mapper = loop$mapper;
    let events = loop$events;
    if (new$8 instanceof Empty) {
      if (old instanceof Empty) {
        return new Diff(
          new Patch(patch_index, removed, changes, children),
          events
        );
      } else {
        let prev = old.head;
        let old$1 = old.tail;
        let _block;
        let $ = prev.key === "" || !has_key2(moved, prev.key);
        if ($) {
          _block = removed + 1;
        } else {
          _block = removed;
        }
        let removed$1 = _block;
        let events$1 = remove_child(events, path2, node_index, prev);
        loop$old = old$1;
        loop$old_keyed = old_keyed;
        loop$new = new$8;
        loop$new_keyed = new_keyed;
        loop$moved = moved;
        loop$moved_offset = moved_offset;
        loop$removed = removed$1;
        loop$node_index = node_index;
        loop$patch_index = patch_index;
        loop$path = path2;
        loop$changes = changes;
        loop$children = children;
        loop$mapper = mapper;
        loop$events = events$1;
      }
    } else if (old instanceof Empty) {
      let events$1 = add_children(
        events,
        mapper,
        path2,
        node_index,
        new$8
      );
      let insert4 = insert3(new$8, node_index - moved_offset);
      let changes$1 = prepend(insert4, changes);
      return new Diff(
        new Patch(patch_index, removed, changes$1, children),
        events$1
      );
    } else {
      let next = new$8.head;
      let prev = old.head;
      if (prev.key !== next.key) {
        let new_remaining = new$8.tail;
        let old_remaining = old.tail;
        let next_did_exist = get(old_keyed, next.key);
        let prev_does_exist = has_key2(new_keyed, prev.key);
        if (next_did_exist instanceof Ok) {
          if (prev_does_exist) {
            let match = next_did_exist[0];
            let $ = has_key2(moved, prev.key);
            if ($) {
              loop$old = old_remaining;
              loop$old_keyed = old_keyed;
              loop$new = new$8;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset - 1;
              loop$removed = removed;
              loop$node_index = node_index;
              loop$patch_index = patch_index;
              loop$path = path2;
              loop$changes = changes;
              loop$children = children;
              loop$mapper = mapper;
              loop$events = events;
            } else {
              let before = node_index - moved_offset;
              let changes$1 = prepend(
                move(next.key, before),
                changes
              );
              let moved$1 = insert2(moved, next.key, void 0);
              let moved_offset$1 = moved_offset + 1;
              loop$old = prepend(match, old);
              loop$old_keyed = old_keyed;
              loop$new = new$8;
              loop$new_keyed = new_keyed;
              loop$moved = moved$1;
              loop$moved_offset = moved_offset$1;
              loop$removed = removed;
              loop$node_index = node_index;
              loop$patch_index = patch_index;
              loop$path = path2;
              loop$changes = changes$1;
              loop$children = children;
              loop$mapper = mapper;
              loop$events = events;
            }
          } else {
            let index5 = node_index - moved_offset;
            let changes$1 = prepend(remove2(index5), changes);
            let events$1 = remove_child(events, path2, node_index, prev);
            let moved_offset$1 = moved_offset - 1;
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new$8;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset$1;
            loop$removed = removed;
            loop$node_index = node_index;
            loop$patch_index = patch_index;
            loop$path = path2;
            loop$changes = changes$1;
            loop$children = children;
            loop$mapper = mapper;
            loop$events = events$1;
          }
        } else if (prev_does_exist) {
          let before = node_index - moved_offset;
          let events$1 = add_child(
            events,
            mapper,
            path2,
            node_index,
            next
          );
          let insert4 = insert3(toList([next]), before);
          let changes$1 = prepend(insert4, changes);
          loop$old = old;
          loop$old_keyed = old_keyed;
          loop$new = new_remaining;
          loop$new_keyed = new_keyed;
          loop$moved = moved;
          loop$moved_offset = moved_offset + 1;
          loop$removed = removed;
          loop$node_index = node_index + 1;
          loop$patch_index = patch_index;
          loop$path = path2;
          loop$changes = changes$1;
          loop$children = children;
          loop$mapper = mapper;
          loop$events = events$1;
        } else {
          let change = replace2(node_index - moved_offset, next);
          let _block;
          let _pipe = events;
          let _pipe$1 = remove_child(_pipe, path2, node_index, prev);
          _block = add_child(_pipe$1, mapper, path2, node_index, next);
          let events$1 = _block;
          loop$old = old_remaining;
          loop$old_keyed = old_keyed;
          loop$new = new_remaining;
          loop$new_keyed = new_keyed;
          loop$moved = moved;
          loop$moved_offset = moved_offset;
          loop$removed = removed;
          loop$node_index = node_index + 1;
          loop$patch_index = patch_index;
          loop$path = path2;
          loop$changes = prepend(change, changes);
          loop$children = children;
          loop$mapper = mapper;
          loop$events = events$1;
        }
      } else {
        let $ = old.head;
        if ($ instanceof Fragment) {
          let $1 = new$8.head;
          if ($1 instanceof Fragment) {
            let next$1 = $1;
            let new$1 = new$8.tail;
            let prev$1 = $;
            let old$1 = old.tail;
            let composed_mapper = compose_mapper(mapper, next$1.mapper);
            let child_path = add4(path2, node_index, next$1.key);
            let child = do_diff(
              prev$1.children,
              prev$1.keyed_children,
              next$1.children,
              next$1.keyed_children,
              empty3(),
              0,
              0,
              0,
              node_index,
              child_path,
              empty_list,
              empty_list,
              composed_mapper,
              events
            );
            let _block;
            let $2 = child.patch;
            let $3 = $2.children;
            if ($3 instanceof Empty) {
              let $4 = $2.changes;
              if ($4 instanceof Empty) {
                let $5 = $2.removed;
                if ($5 === 0) {
                  _block = children;
                } else {
                  _block = prepend(child.patch, children);
                }
              } else {
                _block = prepend(child.patch, children);
              }
            } else {
              _block = prepend(child.patch, children);
            }
            let children$1 = _block;
            loop$old = old$1;
            loop$old_keyed = old_keyed;
            loop$new = new$1;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$path = path2;
            loop$changes = changes;
            loop$children = children$1;
            loop$mapper = mapper;
            loop$events = child.events;
          } else {
            let next$1 = $1;
            let new_remaining = new$8.tail;
            let prev$1 = $;
            let old_remaining = old.tail;
            let change = replace2(node_index - moved_offset, next$1);
            let _block;
            let _pipe = events;
            let _pipe$1 = remove_child(_pipe, path2, node_index, prev$1);
            _block = add_child(
              _pipe$1,
              mapper,
              path2,
              node_index,
              next$1
            );
            let events$1 = _block;
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$path = path2;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$mapper = mapper;
            loop$events = events$1;
          }
        } else if ($ instanceof Element) {
          let $1 = new$8.head;
          if ($1 instanceof Element) {
            let next$1 = $1;
            let prev$1 = $;
            if (prev$1.namespace === next$1.namespace && prev$1.tag === next$1.tag) {
              let new$1 = new$8.tail;
              let old$1 = old.tail;
              let composed_mapper = compose_mapper(
                mapper,
                next$1.mapper
              );
              let child_path = add4(path2, node_index, next$1.key);
              let controlled = is_controlled(
                events,
                next$1.namespace,
                next$1.tag,
                child_path
              );
              let $2 = diff_attributes(
                controlled,
                child_path,
                composed_mapper,
                events,
                prev$1.attributes,
                next$1.attributes,
                empty_list,
                empty_list
              );
              let added_attrs;
              let removed_attrs;
              let events$1;
              added_attrs = $2.added;
              removed_attrs = $2.removed;
              events$1 = $2.events;
              let _block;
              if (removed_attrs instanceof Empty && added_attrs instanceof Empty) {
                _block = empty_list;
              } else {
                _block = toList([update(added_attrs, removed_attrs)]);
              }
              let initial_child_changes = _block;
              let child = do_diff(
                prev$1.children,
                prev$1.keyed_children,
                next$1.children,
                next$1.keyed_children,
                empty3(),
                0,
                0,
                0,
                node_index,
                child_path,
                initial_child_changes,
                empty_list,
                composed_mapper,
                events$1
              );
              let _block$1;
              let $3 = child.patch;
              let $4 = $3.children;
              if ($4 instanceof Empty) {
                let $5 = $3.changes;
                if ($5 instanceof Empty) {
                  let $6 = $3.removed;
                  if ($6 === 0) {
                    _block$1 = children;
                  } else {
                    _block$1 = prepend(child.patch, children);
                  }
                } else {
                  _block$1 = prepend(child.patch, children);
                }
              } else {
                _block$1 = prepend(child.patch, children);
              }
              let children$1 = _block$1;
              loop$old = old$1;
              loop$old_keyed = old_keyed;
              loop$new = new$1;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$path = path2;
              loop$changes = changes;
              loop$children = children$1;
              loop$mapper = mapper;
              loop$events = child.events;
            } else {
              let next$2 = $1;
              let new_remaining = new$8.tail;
              let prev$2 = $;
              let old_remaining = old.tail;
              let change = replace2(node_index - moved_offset, next$2);
              let _block;
              let _pipe = events;
              let _pipe$1 = remove_child(
                _pipe,
                path2,
                node_index,
                prev$2
              );
              _block = add_child(
                _pipe$1,
                mapper,
                path2,
                node_index,
                next$2
              );
              let events$1 = _block;
              loop$old = old_remaining;
              loop$old_keyed = old_keyed;
              loop$new = new_remaining;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$path = path2;
              loop$changes = prepend(change, changes);
              loop$children = children;
              loop$mapper = mapper;
              loop$events = events$1;
            }
          } else {
            let next$1 = $1;
            let new_remaining = new$8.tail;
            let prev$1 = $;
            let old_remaining = old.tail;
            let change = replace2(node_index - moved_offset, next$1);
            let _block;
            let _pipe = events;
            let _pipe$1 = remove_child(_pipe, path2, node_index, prev$1);
            _block = add_child(
              _pipe$1,
              mapper,
              path2,
              node_index,
              next$1
            );
            let events$1 = _block;
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$path = path2;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$mapper = mapper;
            loop$events = events$1;
          }
        } else if ($ instanceof Text) {
          let $1 = new$8.head;
          if ($1 instanceof Text) {
            let next$1 = $1;
            let prev$1 = $;
            if (prev$1.content === next$1.content) {
              let new$1 = new$8.tail;
              let old$1 = old.tail;
              loop$old = old$1;
              loop$old_keyed = old_keyed;
              loop$new = new$1;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$path = path2;
              loop$changes = changes;
              loop$children = children;
              loop$mapper = mapper;
              loop$events = events;
            } else {
              let next$2 = $1;
              let new$1 = new$8.tail;
              let old$1 = old.tail;
              let child = new$5(
                node_index,
                0,
                toList([replace_text(next$2.content)]),
                empty_list
              );
              loop$old = old$1;
              loop$old_keyed = old_keyed;
              loop$new = new$1;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$path = path2;
              loop$changes = changes;
              loop$children = prepend(child, children);
              loop$mapper = mapper;
              loop$events = events;
            }
          } else {
            let next$1 = $1;
            let new_remaining = new$8.tail;
            let prev$1 = $;
            let old_remaining = old.tail;
            let change = replace2(node_index - moved_offset, next$1);
            let _block;
            let _pipe = events;
            let _pipe$1 = remove_child(_pipe, path2, node_index, prev$1);
            _block = add_child(
              _pipe$1,
              mapper,
              path2,
              node_index,
              next$1
            );
            let events$1 = _block;
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$path = path2;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$mapper = mapper;
            loop$events = events$1;
          }
        } else {
          let $1 = new$8.head;
          if ($1 instanceof UnsafeInnerHtml) {
            let next$1 = $1;
            let new$1 = new$8.tail;
            let prev$1 = $;
            let old$1 = old.tail;
            let composed_mapper = compose_mapper(mapper, next$1.mapper);
            let child_path = add4(path2, node_index, next$1.key);
            let $2 = diff_attributes(
              false,
              child_path,
              composed_mapper,
              events,
              prev$1.attributes,
              next$1.attributes,
              empty_list,
              empty_list
            );
            let added_attrs;
            let removed_attrs;
            let events$1;
            added_attrs = $2.added;
            removed_attrs = $2.removed;
            events$1 = $2.events;
            let _block;
            if (removed_attrs instanceof Empty && added_attrs instanceof Empty) {
              _block = empty_list;
            } else {
              _block = toList([update(added_attrs, removed_attrs)]);
            }
            let child_changes = _block;
            let _block$1;
            let $3 = prev$1.inner_html === next$1.inner_html;
            if ($3) {
              _block$1 = child_changes;
            } else {
              _block$1 = prepend(
                replace_inner_html(next$1.inner_html),
                child_changes
              );
            }
            let child_changes$1 = _block$1;
            let _block$2;
            if (child_changes$1 instanceof Empty) {
              _block$2 = children;
            } else {
              _block$2 = prepend(
                new$5(node_index, 0, child_changes$1, toList([])),
                children
              );
            }
            let children$1 = _block$2;
            loop$old = old$1;
            loop$old_keyed = old_keyed;
            loop$new = new$1;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$path = path2;
            loop$changes = changes;
            loop$children = children$1;
            loop$mapper = mapper;
            loop$events = events$1;
          } else {
            let next$1 = $1;
            let new_remaining = new$8.tail;
            let prev$1 = $;
            let old_remaining = old.tail;
            let change = replace2(node_index - moved_offset, next$1);
            let _block;
            let _pipe = events;
            let _pipe$1 = remove_child(_pipe, path2, node_index, prev$1);
            _block = add_child(
              _pipe$1,
              mapper,
              path2,
              node_index,
              next$1
            );
            let events$1 = _block;
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$path = path2;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$mapper = mapper;
            loop$events = events$1;
          }
        }
      }
    }
  }
}
function diff(events, old, new$8) {
  return do_diff(
    toList([old]),
    empty3(),
    toList([new$8]),
    empty3(),
    empty3(),
    0,
    0,
    0,
    0,
    root2,
    empty_list,
    empty_list,
    identity2,
    tick(events)
  );
}

// build/dev/javascript/lustre/lustre/vdom/reconciler.ffi.mjs
var setTimeout = globalThis.setTimeout;
var clearTimeout = globalThis.clearTimeout;
var createElementNS = (ns, name2) => document2().createElementNS(ns, name2);
var createTextNode = (data) => document2().createTextNode(data);
var createDocumentFragment = () => document2().createDocumentFragment();
var insertBefore = (parent, node, reference) => parent.insertBefore(node, reference);
var moveBefore = SUPPORTS_MOVE_BEFORE ? (parent, node, reference) => parent.moveBefore(node, reference) : insertBefore;
var removeChild = (parent, child) => parent.removeChild(child);
var getAttribute = (node, name2) => node.getAttribute(name2);
var setAttribute = (node, name2, value2) => node.setAttribute(name2, value2);
var removeAttribute = (node, name2) => node.removeAttribute(name2);
var addEventListener = (node, name2, handler, options) => node.addEventListener(name2, handler, options);
var removeEventListener = (node, name2, handler) => node.removeEventListener(name2, handler);
var setInnerHtml = (node, innerHtml) => node.innerHTML = innerHtml;
var setData = (node, data) => node.data = data;
var meta = Symbol("lustre");
var MetadataNode = class {
  constructor(kind, parent, node, key) {
    this.kind = kind;
    this.key = key;
    this.parent = parent;
    this.children = [];
    this.node = node;
    this.handlers = /* @__PURE__ */ new Map();
    this.throttles = /* @__PURE__ */ new Map();
    this.debouncers = /* @__PURE__ */ new Map();
  }
  get parentNode() {
    return this.kind === fragment_kind ? this.node.parentNode : this.node;
  }
};
var insertMetadataChild = (kind, parent, node, index5, key) => {
  const child = new MetadataNode(kind, parent, node, key);
  node[meta] = child;
  parent?.children.splice(index5, 0, child);
  return child;
};
var getPath = (node) => {
  let path2 = "";
  for (let current = node[meta]; current.parent; current = current.parent) {
    if (current.key) {
      path2 = `${separator_element}${current.key}${path2}`;
    } else {
      const index5 = current.parent.children.indexOf(current);
      path2 = `${separator_element}${index5}${path2}`;
    }
  }
  return path2.slice(1);
};
var Reconciler = class {
  #root = null;
  #dispatch = () => {
  };
  #useServerEvents = false;
  #exposeKeys = false;
  constructor(root3, dispatch, { useServerEvents = false, exposeKeys = false } = {}) {
    this.#root = root3;
    this.#dispatch = dispatch;
    this.#useServerEvents = useServerEvents;
    this.#exposeKeys = exposeKeys;
  }
  mount(vdom) {
    insertMetadataChild(element_kind, null, this.#root, 0, null);
    this.#insertChild(this.#root, null, this.#root[meta], 0, vdom);
  }
  push(patch) {
    this.#stack.push({ node: this.#root[meta], patch });
    this.#reconcile();
  }
  // PATCHING ------------------------------------------------------------------
  #stack = [];
  #reconcile() {
    const stack = this.#stack;
    while (stack.length) {
      const { node, patch } = stack.pop();
      const { children: childNodes } = node;
      const { changes, removed, children: childPatches } = patch;
      iterate(changes, (change) => this.#patch(node, change));
      if (removed) {
        this.#removeChildren(node, childNodes.length - removed, removed);
      }
      iterate(childPatches, (childPatch) => {
        const child = childNodes[childPatch.index | 0];
        this.#stack.push({ node: child, patch: childPatch });
      });
    }
  }
  #patch(node, change) {
    switch (change.kind) {
      case replace_text_kind:
        this.#replaceText(node, change);
        break;
      case replace_inner_html_kind:
        this.#replaceInnerHtml(node, change);
        break;
      case update_kind:
        this.#update(node, change);
        break;
      case move_kind:
        this.#move(node, change);
        break;
      case remove_kind:
        this.#remove(node, change);
        break;
      case replace_kind:
        this.#replace(node, change);
        break;
      case insert_kind:
        this.#insert(node, change);
        break;
    }
  }
  // CHANGES -------------------------------------------------------------------
  #insert(parent, { children, before }) {
    const fragment3 = createDocumentFragment();
    const beforeEl = this.#getReference(parent, before);
    this.#insertChildren(fragment3, null, parent, before | 0, children);
    insertBefore(parent.parentNode, fragment3, beforeEl);
  }
  #replace(parent, { index: index5, with: child }) {
    this.#removeChildren(parent, index5 | 0, 1);
    const beforeEl = this.#getReference(parent, index5);
    this.#insertChild(parent.parentNode, beforeEl, parent, index5 | 0, child);
  }
  #getReference(node, index5) {
    index5 = index5 | 0;
    const { children } = node;
    const childCount = children.length;
    if (index5 < childCount) {
      return children[index5].node;
    }
    let lastChild = children[childCount - 1];
    if (!lastChild && node.kind !== fragment_kind) return null;
    if (!lastChild) lastChild = node;
    while (lastChild.kind === fragment_kind && lastChild.children.length) {
      lastChild = lastChild.children[lastChild.children.length - 1];
    }
    return lastChild.node.nextSibling;
  }
  #move(parent, { key, before }) {
    before = before | 0;
    const { children, parentNode } = parent;
    const beforeEl = children[before].node;
    let prev = children[before];
    for (let i = before + 1; i < children.length; ++i) {
      const next = children[i];
      children[i] = prev;
      prev = next;
      if (next.key === key) {
        children[before] = next;
        break;
      }
    }
    const { kind, node, children: prevChildren } = prev;
    moveBefore(parentNode, node, beforeEl);
    if (kind === fragment_kind) {
      this.#moveChildren(parentNode, prevChildren, beforeEl);
    }
  }
  #moveChildren(domParent, children, beforeEl) {
    for (let i = 0; i < children.length; ++i) {
      const { kind, node, children: nestedChildren } = children[i];
      moveBefore(domParent, node, beforeEl);
      if (kind === fragment_kind) {
        this.#moveChildren(domParent, nestedChildren, beforeEl);
      }
    }
  }
  #remove(parent, { index: index5 }) {
    this.#removeChildren(parent, index5, 1);
  }
  #removeChildren(parent, index5, count) {
    const { children, parentNode } = parent;
    const deleted = children.splice(index5, count);
    for (let i = 0; i < deleted.length; ++i) {
      const { kind, node, children: nestedChildren } = deleted[i];
      removeChild(parentNode, node);
      this.#removeDebouncers(deleted[i]);
      if (kind === fragment_kind) {
        deleted.push(...nestedChildren);
      }
    }
  }
  #removeDebouncers(node) {
    const { debouncers, children } = node;
    for (const { timeout } of debouncers.values()) {
      if (timeout) {
        clearTimeout(timeout);
      }
    }
    debouncers.clear();
    iterate(children, (child) => this.#removeDebouncers(child));
  }
  #update({ node, handlers, throttles, debouncers }, { added, removed }) {
    iterate(removed, ({ name: name2 }) => {
      if (handlers.delete(name2)) {
        removeEventListener(node, name2, handleEvent);
        this.#updateDebounceThrottle(throttles, name2, 0);
        this.#updateDebounceThrottle(debouncers, name2, 0);
      } else {
        removeAttribute(node, name2);
        SYNCED_ATTRIBUTES[name2]?.removed?.(node, name2);
      }
    });
    iterate(added, (attribute3) => this.#createAttribute(node, attribute3));
  }
  #replaceText({ node }, { content }) {
    setData(node, content ?? "");
  }
  #replaceInnerHtml({ node }, { inner_html }) {
    setInnerHtml(node, inner_html ?? "");
  }
  // INSERT --------------------------------------------------------------------
  #insertChildren(domParent, beforeEl, metaParent, index5, children) {
    iterate(
      children,
      (child) => this.#insertChild(domParent, beforeEl, metaParent, index5++, child)
    );
  }
  #insertChild(domParent, beforeEl, metaParent, index5, vnode) {
    switch (vnode.kind) {
      case element_kind: {
        const node = this.#createElement(metaParent, index5, vnode);
        this.#insertChildren(node, null, node[meta], 0, vnode.children);
        insertBefore(domParent, node, beforeEl);
        break;
      }
      case text_kind: {
        const node = this.#createTextNode(metaParent, index5, vnode);
        insertBefore(domParent, node, beforeEl);
        break;
      }
      case fragment_kind: {
        const head = this.#createTextNode(metaParent, index5, vnode);
        insertBefore(domParent, head, beforeEl);
        this.#insertChildren(
          domParent,
          beforeEl,
          head[meta],
          0,
          vnode.children
        );
        break;
      }
      case unsafe_inner_html_kind: {
        const node = this.#createElement(metaParent, index5, vnode);
        this.#replaceInnerHtml({ node }, vnode);
        insertBefore(domParent, node, beforeEl);
        break;
      }
    }
  }
  #createElement(parent, index5, { kind, key, tag, namespace: namespace2, attributes }) {
    const node = createElementNS(namespace2 || NAMESPACE_HTML, tag);
    insertMetadataChild(kind, parent, node, index5, key);
    if (this.#exposeKeys && key) {
      setAttribute(node, "data-lustre-key", key);
    }
    iterate(attributes, (attribute3) => this.#createAttribute(node, attribute3));
    return node;
  }
  #createTextNode(parent, index5, { kind, key, content }) {
    const node = createTextNode(content ?? "");
    insertMetadataChild(kind, parent, node, index5, key);
    return node;
  }
  #createAttribute(node, attribute3) {
    const { debouncers, handlers, throttles } = node[meta];
    const {
      kind,
      name: name2,
      value: value2,
      prevent_default: prevent,
      debounce: debounceDelay,
      throttle: throttleDelay
    } = attribute3;
    switch (kind) {
      case attribute_kind: {
        const valueOrDefault = value2 ?? "";
        if (name2 === "virtual:defaultValue") {
          node.defaultValue = valueOrDefault;
          return;
        }
        if (valueOrDefault !== getAttribute(node, name2)) {
          setAttribute(node, name2, valueOrDefault);
        }
        SYNCED_ATTRIBUTES[name2]?.added?.(node, valueOrDefault);
        break;
      }
      case property_kind:
        node[name2] = value2;
        break;
      case event_kind: {
        if (handlers.has(name2)) {
          removeEventListener(node, name2, handleEvent);
        }
        const passive = prevent.kind === never_kind;
        addEventListener(node, name2, handleEvent, { passive });
        this.#updateDebounceThrottle(throttles, name2, throttleDelay);
        this.#updateDebounceThrottle(debouncers, name2, debounceDelay);
        handlers.set(name2, (event4) => this.#handleEvent(attribute3, event4));
        break;
      }
    }
  }
  #updateDebounceThrottle(map6, name2, delay) {
    const debounceOrThrottle = map6.get(name2);
    if (delay > 0) {
      if (debounceOrThrottle) {
        debounceOrThrottle.delay = delay;
      } else {
        map6.set(name2, { delay });
      }
    } else if (debounceOrThrottle) {
      const { timeout } = debounceOrThrottle;
      if (timeout) {
        clearTimeout(timeout);
      }
      map6.delete(name2);
    }
  }
  #handleEvent(attribute3, event4) {
    const { currentTarget, type } = event4;
    const { debouncers, throttles } = currentTarget[meta];
    const path2 = getPath(currentTarget);
    const {
      prevent_default: prevent,
      stop_propagation: stop,
      include,
      immediate
    } = attribute3;
    if (prevent.kind === always_kind) event4.preventDefault();
    if (stop.kind === always_kind) event4.stopPropagation();
    if (type === "submit") {
      event4.detail ??= {};
      event4.detail.formData = [
        ...new FormData(event4.target, event4.submitter).entries()
      ];
    }
    const data = this.#useServerEvents ? createServerEvent(event4, include ?? []) : event4;
    const throttle = throttles.get(type);
    if (throttle) {
      const now = Date.now();
      const last = throttle.last || 0;
      if (now > last + throttle.delay) {
        throttle.last = now;
        throttle.lastEvent = event4;
        this.#dispatch(data, path2, type, immediate);
      }
    }
    const debounce = debouncers.get(type);
    if (debounce) {
      clearTimeout(debounce.timeout);
      debounce.timeout = setTimeout(() => {
        if (event4 === throttles.get(type)?.lastEvent) return;
        this.#dispatch(data, path2, type, immediate);
      }, debounce.delay);
    }
    if (!throttle && !debounce) {
      this.#dispatch(data, path2, type, immediate);
    }
  }
};
var iterate = (list4, callback) => {
  if (Array.isArray(list4)) {
    for (let i = 0; i < list4.length; i++) {
      callback(list4[i]);
    }
  } else if (list4) {
    for (list4; list4.head; list4 = list4.tail) {
      callback(list4.head);
    }
  }
};
var handleEvent = (event4) => {
  const { currentTarget, type } = event4;
  const handler = currentTarget[meta].handlers.get(type);
  handler(event4);
};
var createServerEvent = (event4, include = []) => {
  const data = {};
  if (event4.type === "input" || event4.type === "change") {
    include.push("target.value");
  }
  if (event4.type === "submit") {
    include.push("detail.formData");
  }
  for (const property3 of include) {
    const path2 = property3.split(".");
    for (let i = 0, input2 = event4, output = data; i < path2.length; i++) {
      if (i === path2.length - 1) {
        output[path2[i]] = input2[path2[i]];
        break;
      }
      output = output[path2[i]] ??= {};
      input2 = input2[path2[i]];
    }
  }
  return data;
};
var syncedBooleanAttribute = /* @__NO_SIDE_EFFECTS__ */ (name2) => {
  return {
    added(node) {
      node[name2] = true;
    },
    removed(node) {
      node[name2] = false;
    }
  };
};
var syncedAttribute = /* @__NO_SIDE_EFFECTS__ */ (name2) => {
  return {
    added(node, value2) {
      node[name2] = value2;
    }
  };
};
var SYNCED_ATTRIBUTES = {
  checked: /* @__PURE__ */ syncedBooleanAttribute("checked"),
  selected: /* @__PURE__ */ syncedBooleanAttribute("selected"),
  value: /* @__PURE__ */ syncedAttribute("value"),
  autofocus: {
    added(node) {
      queueMicrotask(() => {
        node.focus?.();
      });
    }
  },
  autoplay: {
    added(node) {
      try {
        node.play?.();
      } catch (e) {
        console.error(e);
      }
    }
  }
};

// build/dev/javascript/lustre/lustre/element/keyed.mjs
function do_extract_keyed_children(loop$key_children_pairs, loop$keyed_children, loop$children) {
  while (true) {
    let key_children_pairs = loop$key_children_pairs;
    let keyed_children = loop$keyed_children;
    let children = loop$children;
    if (key_children_pairs instanceof Empty) {
      return [keyed_children, reverse(children)];
    } else {
      let rest = key_children_pairs.tail;
      let key = key_children_pairs.head[0];
      let element$1 = key_children_pairs.head[1];
      let keyed_element = to_keyed(key, element$1);
      let _block;
      if (key === "") {
        _block = keyed_children;
      } else {
        _block = insert2(keyed_children, key, keyed_element);
      }
      let keyed_children$1 = _block;
      let children$1 = prepend(keyed_element, children);
      loop$key_children_pairs = rest;
      loop$keyed_children = keyed_children$1;
      loop$children = children$1;
    }
  }
}
function extract_keyed_children(children) {
  return do_extract_keyed_children(
    children,
    empty3(),
    empty_list
  );
}
function element3(tag, attributes, children) {
  let $ = extract_keyed_children(children);
  let keyed_children;
  let children$1;
  keyed_children = $[0];
  children$1 = $[1];
  return element(
    "",
    identity2,
    "",
    tag,
    attributes,
    children$1,
    keyed_children,
    false,
    false
  );
}
function namespaced2(namespace2, tag, attributes, children) {
  let $ = extract_keyed_children(children);
  let keyed_children;
  let children$1;
  keyed_children = $[0];
  children$1 = $[1];
  return element(
    "",
    identity2,
    namespace2,
    tag,
    attributes,
    children$1,
    keyed_children,
    false,
    false
  );
}
function fragment2(children) {
  let $ = extract_keyed_children(children);
  let keyed_children;
  let children$1;
  keyed_children = $[0];
  children$1 = $[1];
  return fragment("", identity2, children$1, keyed_children);
}
function div2(attributes, children) {
  return element3("div", attributes, children);
}

// build/dev/javascript/lustre/lustre/vdom/virtualise.ffi.mjs
var virtualise = (root3) => {
  const rootMeta = insertMetadataChild(element_kind, null, root3, 0, null);
  let virtualisableRootChildren = 0;
  for (let child = root3.firstChild; child; child = child.nextSibling) {
    if (canVirtualiseNode(child)) virtualisableRootChildren += 1;
  }
  if (virtualisableRootChildren === 0) {
    const placeholder2 = document2().createTextNode("");
    insertMetadataChild(text_kind, rootMeta, placeholder2, 0, null);
    root3.replaceChildren(placeholder2);
    return none2();
  }
  if (virtualisableRootChildren === 1) {
    const children2 = virtualiseChildNodes(rootMeta, root3);
    return children2.head[1];
  }
  const fragmentHead = document2().createTextNode("");
  const fragmentMeta = insertMetadataChild(fragment_kind, rootMeta, fragmentHead, 0, null);
  const children = virtualiseChildNodes(fragmentMeta, root3);
  root3.insertBefore(fragmentHead, root3.firstChild);
  return fragment2(children);
};
var canVirtualiseNode = (node) => {
  switch (node.nodeType) {
    case ELEMENT_NODE:
      return true;
    case TEXT_NODE:
      return !!node.data;
    default:
      return false;
  }
};
var virtualiseNode = (meta2, node, key, index5) => {
  if (!canVirtualiseNode(node)) {
    return null;
  }
  switch (node.nodeType) {
    case ELEMENT_NODE: {
      const childMeta = insertMetadataChild(element_kind, meta2, node, index5, key);
      const tag = node.localName;
      const namespace2 = node.namespaceURI;
      const isHtmlElement = !namespace2 || namespace2 === NAMESPACE_HTML;
      if (isHtmlElement && INPUT_ELEMENTS.includes(tag)) {
        virtualiseInputEvents(tag, node);
      }
      const attributes = virtualiseAttributes(node);
      const children = virtualiseChildNodes(childMeta, node);
      const vnode = isHtmlElement ? element3(tag, attributes, children) : namespaced2(namespace2, tag, attributes, children);
      return vnode;
    }
    case TEXT_NODE:
      insertMetadataChild(text_kind, meta2, node, index5, null);
      return text2(node.data);
    default:
      return null;
  }
};
var INPUT_ELEMENTS = ["input", "select", "textarea"];
var virtualiseInputEvents = (tag, node) => {
  const value2 = node.value;
  const checked = node.checked;
  if (tag === "input" && node.type === "checkbox" && !checked) return;
  if (tag === "input" && node.type === "radio" && !checked) return;
  if (node.type !== "checkbox" && node.type !== "radio" && !value2) return;
  queueMicrotask(() => {
    node.value = value2;
    node.checked = checked;
    node.dispatchEvent(new Event("input", { bubbles: true }));
    node.dispatchEvent(new Event("change", { bubbles: true }));
    if (document2().activeElement !== node) {
      node.dispatchEvent(new Event("blur", { bubbles: true }));
    }
  });
};
var virtualiseChildNodes = (meta2, node) => {
  let children = null;
  let child = node.firstChild;
  let ptr = null;
  let index5 = 0;
  while (child) {
    const key = child.nodeType === ELEMENT_NODE ? child.getAttribute("data-lustre-key") : null;
    if (key != null) {
      child.removeAttribute("data-lustre-key");
    }
    const vnode = virtualiseNode(meta2, child, key, index5);
    const next = child.nextSibling;
    if (vnode) {
      const list_node = new NonEmpty([key ?? "", vnode], null);
      if (ptr) {
        ptr = ptr.tail = list_node;
      } else {
        ptr = children = list_node;
      }
      index5 += 1;
    } else {
      node.removeChild(child);
    }
    child = next;
  }
  if (!ptr) return empty_list;
  ptr.tail = empty_list;
  return children;
};
var virtualiseAttributes = (node) => {
  let index5 = node.attributes.length;
  let attributes = empty_list;
  while (index5-- > 0) {
    const attr = node.attributes[index5];
    if (attr.name === "xmlns") {
      continue;
    }
    attributes = new NonEmpty(virtualiseAttribute(attr), attributes);
  }
  return attributes;
};
var virtualiseAttribute = (attr) => {
  const name2 = attr.localName;
  const value2 = attr.value;
  return attribute2(name2, value2);
};

// build/dev/javascript/lustre/lustre/runtime/client/runtime.ffi.mjs
var is_browser = () => !!document2();
var Runtime = class {
  constructor(root3, [model, effects], view3, update4) {
    this.root = root3;
    this.#model = model;
    this.#view = view3;
    this.#update = update4;
    this.root.addEventListener("context-request", (event4) => {
      if (!(event4.context && event4.callback)) return;
      if (!this.#contexts.has(event4.context)) return;
      event4.stopImmediatePropagation();
      const context = this.#contexts.get(event4.context);
      if (event4.subscribe) {
        const unsubscribe = () => {
          context.subscribers = context.subscribers.filter(
            (subscriber) => subscriber !== event4.callback
          );
        };
        context.subscribers.push([event4.callback, unsubscribe]);
        event4.callback(context.value, unsubscribe);
      } else {
        event4.callback(context.value);
      }
    });
    this.#reconciler = new Reconciler(this.root, (event4, path2, name2) => {
      const [events, result] = handle(this.#events, path2, name2, event4);
      this.#events = events;
      if (result.isOk()) {
        const handler = result[0];
        if (handler.stop_propagation) event4.stopPropagation();
        if (handler.prevent_default) event4.preventDefault();
        this.dispatch(handler.message, false);
      }
    });
    this.#vdom = virtualise(this.root);
    this.#events = new$3();
    this.#shouldFlush = true;
    this.#tick(effects);
  }
  // PUBLIC API ----------------------------------------------------------------
  root = null;
  dispatch(msg, immediate = false) {
    this.#shouldFlush ||= immediate;
    if (this.#shouldQueue) {
      this.#queue.push(msg);
    } else {
      const [model, effects] = this.#update(this.#model, msg);
      this.#model = model;
      this.#tick(effects);
    }
  }
  emit(event4, data) {
    const target = this.root.host ?? this.root;
    target.dispatchEvent(
      new CustomEvent(event4, {
        detail: data,
        bubbles: true,
        composed: true
      })
    );
  }
  // Provide a context value for any child nodes that request it using the given
  // key. If the key already exists, any existing subscribers will be notified
  // of the change. Otherwise, we store the value and wait for any `context-request`
  // events to come in.
  provide(key, value2) {
    if (!this.#contexts.has(key)) {
      this.#contexts.set(key, { value: value2, subscribers: [] });
    } else {
      const context = this.#contexts.get(key);
      context.value = value2;
      for (let i = context.subscribers.length - 1; i >= 0; i--) {
        const [subscriber, unsubscribe] = context.subscribers[i];
        if (!subscriber) {
          context.subscribers.splice(i, 1);
          continue;
        }
        subscriber(value2, unsubscribe);
      }
    }
  }
  // PRIVATE API ---------------------------------------------------------------
  #model;
  #view;
  #update;
  #vdom;
  #events;
  #reconciler;
  #contexts = /* @__PURE__ */ new Map();
  #shouldQueue = false;
  #queue = [];
  #beforePaint = empty_list;
  #afterPaint = empty_list;
  #renderTimer = null;
  #shouldFlush = false;
  #actions = {
    dispatch: (msg, immediate) => this.dispatch(msg, immediate),
    emit: (event4, data) => this.emit(event4, data),
    select: () => {
    },
    root: () => this.root,
    provide: (key, value2) => this.provide(key, value2)
  };
  // A `#tick` is where we process effects and trigger any synchronous updates.
  // Once a tick has been processed a render will be scheduled if none is already.
  // p0
  #tick(effects) {
    this.#shouldQueue = true;
    while (true) {
      for (let list4 = effects.synchronous; list4.tail; list4 = list4.tail) {
        list4.head(this.#actions);
      }
      this.#beforePaint = listAppend(this.#beforePaint, effects.before_paint);
      this.#afterPaint = listAppend(this.#afterPaint, effects.after_paint);
      if (!this.#queue.length) break;
      [this.#model, effects] = this.#update(this.#model, this.#queue.shift());
    }
    this.#shouldQueue = false;
    if (this.#shouldFlush) {
      cancelAnimationFrame(this.#renderTimer);
      this.#render();
    } else if (!this.#renderTimer) {
      this.#renderTimer = requestAnimationFrame(() => {
        this.#render();
      });
    }
  }
  #render() {
    this.#shouldFlush = false;
    this.#renderTimer = null;
    const next = this.#view(this.#model);
    const { patch, events } = diff(this.#events, this.#vdom, next);
    this.#events = events;
    this.#vdom = next;
    this.#reconciler.push(patch);
    if (this.#beforePaint instanceof NonEmpty) {
      const effects = makeEffect(this.#beforePaint);
      this.#beforePaint = empty_list;
      queueMicrotask(() => {
        this.#shouldFlush = true;
        this.#tick(effects);
      });
    }
    if (this.#afterPaint instanceof NonEmpty) {
      const effects = makeEffect(this.#afterPaint);
      this.#afterPaint = empty_list;
      requestAnimationFrame(() => {
        this.#shouldFlush = true;
        this.#tick(effects);
      });
    }
  }
};
function makeEffect(synchronous) {
  return {
    synchronous,
    after_paint: empty_list,
    before_paint: empty_list
  };
}
function listAppend(a, b) {
  if (a instanceof Empty) {
    return b;
  } else if (b instanceof Empty) {
    return a;
  } else {
    return append(a, b);
  }
}
var copiedStyleSheets = /* @__PURE__ */ new WeakMap();
async function adoptStylesheets(shadowRoot) {
  const pendingParentStylesheets = [];
  for (const node of document2().querySelectorAll(
    "link[rel=stylesheet], style"
  )) {
    if (node.sheet) continue;
    pendingParentStylesheets.push(
      new Promise((resolve2, reject) => {
        node.addEventListener("load", resolve2);
        node.addEventListener("error", reject);
      })
    );
  }
  await Promise.allSettled(pendingParentStylesheets);
  if (!shadowRoot.host.isConnected) {
    return [];
  }
  shadowRoot.adoptedStyleSheets = shadowRoot.host.getRootNode().adoptedStyleSheets;
  const pending = [];
  for (const sheet of document2().styleSheets) {
    try {
      shadowRoot.adoptedStyleSheets.push(sheet);
    } catch {
      try {
        let copiedSheet = copiedStyleSheets.get(sheet);
        if (!copiedSheet) {
          copiedSheet = new CSSStyleSheet();
          for (const rule of sheet.cssRules) {
            copiedSheet.insertRule(rule.cssText, copiedSheet.cssRules.length);
          }
          copiedStyleSheets.set(sheet, copiedSheet);
        }
        shadowRoot.adoptedStyleSheets.push(copiedSheet);
      } catch {
        const node = sheet.ownerNode.cloneNode();
        shadowRoot.prepend(node);
        pending.push(node);
      }
    }
  }
  return pending;
}
var ContextRequestEvent = class extends Event {
  constructor(context, callback, subscribe) {
    super("context-request", { bubbles: true, composed: true });
    this.context = context;
    this.callback = callback;
    this.subscribe = subscribe;
  }
};

// build/dev/javascript/lustre/lustre/runtime/server/runtime.mjs
var EffectDispatchedMessage = class extends CustomType {
  constructor(message2) {
    super();
    this.message = message2;
  }
};
var EffectEmitEvent = class extends CustomType {
  constructor(name2, data) {
    super();
    this.name = name2;
    this.data = data;
  }
};
var SystemRequestedShutdown = class extends CustomType {
};

// build/dev/javascript/lustre/lustre/runtime/client/component.ffi.mjs
var make_component = ({ init: init3, update: update4, view: view3, config }, name2) => {
  if (!is_browser()) return new Error(new NotABrowser());
  if (!name2.includes("-")) return new Error(new BadComponentName(name2));
  if (customElements.get(name2)) {
    return new Error(new ComponentAlreadyRegistered(name2));
  }
  const attributes = /* @__PURE__ */ new Map();
  const observedAttributes = [];
  for (let attr = config.attributes; attr.tail; attr = attr.tail) {
    const [name3, decoder] = attr.head;
    if (attributes.has(name3)) continue;
    attributes.set(name3, decoder);
    observedAttributes.push(name3);
  }
  const [model, effects] = init3(void 0);
  const component2 = class Component extends HTMLElement {
    static get observedAttributes() {
      return observedAttributes;
    }
    static formAssociated = config.is_form_associated;
    #runtime;
    #adoptedStyleNodes = [];
    #shadowRoot;
    #contextSubscriptions = /* @__PURE__ */ new Map();
    constructor() {
      super();
      this.internals = this.attachInternals();
      if (!this.internals.shadowRoot) {
        this.#shadowRoot = this.attachShadow({
          mode: config.open_shadow_root ? "open" : "closed",
          delegatesFocus: config.delegates_focus
        });
      } else {
        this.#shadowRoot = this.internals.shadowRoot;
      }
      if (config.adopt_styles) {
        this.#adoptStyleSheets();
      }
      this.#runtime = new Runtime(
        this.#shadowRoot,
        [model, effects],
        view3,
        update4
      );
    }
    // CUSTOM ELEMENT LIFECYCLE METHODS ----------------------------------------
    connectedCallback() {
      const requested = /* @__PURE__ */ new Set();
      for (let ctx = config.contexts; ctx.tail; ctx = ctx.tail) {
        const [key, decoder] = ctx.head;
        if (!key) continue;
        if (requested.has(key)) continue;
        this.dispatchEvent(
          new ContextRequestEvent(
            key,
            (value2, unsubscribe) => {
              const previousUnsubscribe = this.#contextSubscriptions.get(key);
              if (previousUnsubscribe !== unsubscribe) {
                previousUnsubscribe?.();
              }
              const decoded = run(value2, decoder);
              this.#contextSubscriptions.set(key, unsubscribe);
              if (decoded.isOk()) {
                this.dispatch(decoded[0]);
              }
            },
            true
          )
        );
        requested.add(key);
      }
    }
    adoptedCallback() {
      if (config.adopt_styles) {
        this.#adoptStyleSheets();
      }
    }
    attributeChangedCallback(name3, _, value2) {
      const decoded = attributes.get(name3)(value2 ?? "");
      if (decoded.isOk()) {
        this.dispatch(decoded[0]);
      }
    }
    formResetCallback() {
      if (config.on_form_reset instanceof Some) {
        this.dispatch(config.on_form_reset[0]);
      }
    }
    formStateRestoreCallback(state, reason) {
      switch (reason) {
        case "restore":
          if (config.on_form_restore instanceof Some) {
            this.dispatch(config.on_form_restore[0](state));
          }
          break;
        case "autocomplete":
          if (config.on_form_populate instanceof Some) {
            this.dispatch(config.on_form_autofill[0](state));
          }
          break;
      }
    }
    disconnectedCallback() {
      for (const [_, unsubscribe] of this.#contextSubscriptions) {
        unsubscribe?.();
      }
      this.#contextSubscriptions.clear();
    }
    // LUSTRE RUNTIME METHODS --------------------------------------------------
    send(message2) {
      switch (message2.constructor) {
        case EffectDispatchedMessage: {
          this.dispatch(message2.message, false);
          break;
        }
        case EffectEmitEvent: {
          this.emit(message2.name, message2.data);
          break;
        }
        case SystemRequestedShutdown:
          break;
      }
    }
    dispatch(msg, immediate = false) {
      this.#runtime.dispatch(msg, immediate);
    }
    emit(event4, data) {
      this.#runtime.emit(event4, data);
    }
    provide(key, value2) {
      this.#runtime.provide(key, value2);
    }
    async #adoptStyleSheets() {
      while (this.#adoptedStyleNodes.length) {
        this.#adoptedStyleNodes.pop().remove();
        this.shadowRoot.firstChild.remove();
      }
      this.#adoptedStyleNodes = await adoptStylesheets(this.#shadowRoot);
    }
  };
  for (let prop = config.properties; prop.tail; prop = prop.tail) {
    const [name3, decoder] = prop.head;
    if (Object.hasOwn(component2.prototype, name3)) {
      continue;
    }
    Object.defineProperty(component2.prototype, name3, {
      get() {
        return this[`_${name3}`];
      },
      set(value2) {
        this[`_${name3}`] = value2;
        const decoded = run(value2, decoder);
        if (decoded.constructor === Ok) {
          this.dispatch(decoded[0]);
        }
      }
    });
  }
  customElements.define(name2, component2);
  return new Ok(void 0);
};

// build/dev/javascript/lustre/lustre/component.mjs
var Config2 = class extends CustomType {
  constructor(open_shadow_root, adopt_styles, delegates_focus, attributes, properties, contexts, is_form_associated, on_form_autofill, on_form_reset, on_form_restore) {
    super();
    this.open_shadow_root = open_shadow_root;
    this.adopt_styles = adopt_styles;
    this.delegates_focus = delegates_focus;
    this.attributes = attributes;
    this.properties = properties;
    this.contexts = contexts;
    this.is_form_associated = is_form_associated;
    this.on_form_autofill = on_form_autofill;
    this.on_form_reset = on_form_reset;
    this.on_form_restore = on_form_restore;
  }
};
function new$6(options) {
  let init3 = new Config2(
    true,
    true,
    false,
    empty_list,
    empty_list,
    empty_list,
    false,
    option_none,
    option_none,
    option_none
  );
  return fold(
    options,
    init3,
    (config, option) => {
      return option.apply(config);
    }
  );
}

// build/dev/javascript/lustre/lustre/runtime/client/spa.ffi.mjs
var Spa = class {
  #runtime;
  constructor(root3, [init3, effects], update4, view3) {
    this.#runtime = new Runtime(root3, [init3, effects], view3, update4);
  }
  send(message2) {
    switch (message2.constructor) {
      case EffectDispatchedMessage: {
        this.dispatch(message2.message, false);
        break;
      }
      case EffectEmitEvent: {
        this.emit(message2.name, message2.data);
        break;
      }
      case SystemRequestedShutdown:
        break;
    }
  }
  dispatch(msg, immediate) {
    this.#runtime.dispatch(msg, immediate);
  }
  emit(event4, data) {
    this.#runtime.emit(event4, data);
  }
};
var start = ({ init: init3, update: update4, view: view3 }, selector, flags) => {
  if (!is_browser()) return new Error(new NotABrowser());
  const root3 = selector instanceof HTMLElement ? selector : document2().querySelector(selector);
  if (!root3) return new Error(new ElementNotFound(selector));
  return new Ok(new Spa(root3, init3(flags), update4, view3));
};

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init3, update4, view3, config) {
    super();
    this.init = init3;
    this.update = update4;
    this.view = view3;
    this.config = config;
  }
};
var BadComponentName = class extends CustomType {
  constructor(name2) {
    super();
    this.name = name2;
  }
};
var ComponentAlreadyRegistered = class extends CustomType {
  constructor(name2) {
    super();
    this.name = name2;
  }
};
var ElementNotFound = class extends CustomType {
  constructor(selector) {
    super();
    this.selector = selector;
  }
};
var NotABrowser = class extends CustomType {
};
function component(init3, update4, view3, options) {
  return new App(init3, update4, view3, new$6(options));
}
function application(init3, update4, view3) {
  return new App(init3, update4, view3, new$6(empty_list));
}
function start3(app, selector, start_args) {
  return guard(
    !is_browser(),
    new Error(new NotABrowser()),
    () => {
      return start(app, selector, start_args);
    }
  );
}

// build/dev/javascript/gleam_stdlib/gleam/pair.mjs
function new$7(first2, second2) {
  return [first2, second2];
}

// build/dev/javascript/lustre/lustre/event.mjs
function emit2(event4, data) {
  return event2(event4, data);
}
function is_immediate_event(name2) {
  if (name2 === "input") {
    return true;
  } else if (name2 === "change") {
    return true;
  } else if (name2 === "focus") {
    return true;
  } else if (name2 === "focusin") {
    return true;
  } else if (name2 === "focusout") {
    return true;
  } else if (name2 === "blur") {
    return true;
  } else if (name2 === "select") {
    return true;
  } else {
    return false;
  }
}
function on(name2, handler) {
  return event(
    name2,
    map3(handler, (msg) => {
      return new Handler(false, false, msg);
    }),
    empty_list,
    never,
    never,
    is_immediate_event(name2),
    0,
    0
  );
}
function prevent_default(event4) {
  if (event4 instanceof Event2) {
    return new Event2(
      event4.kind,
      event4.name,
      event4.handler,
      event4.include,
      always,
      event4.stop_propagation,
      event4.immediate,
      event4.debounce,
      event4.throttle
    );
  } else {
    return event4;
  }
}
function on_click(msg) {
  return on("click", success(msg));
}
function on_input(msg) {
  return on(
    "input",
    subfield(
      toList(["target", "value"]),
      string2,
      (value2) => {
        return success(msg(value2));
      }
    )
  );
}
function on_change(msg) {
  return on(
    "change",
    subfield(
      toList(["target", "value"]),
      string2,
      (value2) => {
        return success(msg(value2));
      }
    )
  );
}
function formdata_decoder() {
  let string_value_decoder = field(
    0,
    string2,
    (key) => {
      return field(
        1,
        one_of(
          map3(string2, (var0) => {
            return new Ok(var0);
          }),
          toList([success(new Error(void 0))])
        ),
        (value2) => {
          let _pipe2 = value2;
          let _pipe$12 = map4(
            _pipe2,
            (_capture) => {
              return new$7(key, _capture);
            }
          );
          return success(_pipe$12);
        }
      );
    }
  );
  let _pipe = string_value_decoder;
  let _pipe$1 = list2(_pipe);
  return map3(_pipe$1, values2);
}
function on_submit(msg) {
  let _pipe = on(
    "submit",
    subfield(
      toList(["detail", "formData"]),
      formdata_decoder(),
      (formdata) => {
        let _pipe2 = formdata;
        let _pipe$1 = msg(_pipe2);
        return success(_pipe$1);
      }
    )
  );
  return prevent_default(_pipe);
}
function on_blur(msg) {
  return on("blur", success(msg));
}

// build/dev/javascript/gleam_stdlib/gleam/uri.mjs
var Uri = class extends CustomType {
  constructor(scheme, userinfo, host, port, path2, query, fragment3) {
    super();
    this.scheme = scheme;
    this.userinfo = userinfo;
    this.host = host;
    this.port = port;
    this.path = path2;
    this.query = query;
    this.fragment = fragment3;
  }
};
function is_valid_host_within_brackets_char(char) {
  return 48 >= char && char <= 57 || 65 >= char && char <= 90 || 97 >= char && char <= 122 || char === 58 || char === 46;
}
function parse_fragment(rest, pieces) {
  return new Ok(
    new Uri(
      pieces.scheme,
      pieces.userinfo,
      pieces.host,
      pieces.port,
      pieces.path,
      pieces.query,
      new Some(rest)
    )
  );
}
function parse_query_with_question_mark_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("#")) {
      if (size2 === 0) {
        let rest = uri_string.slice(1);
        return parse_fragment(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let query = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          new Some(query),
          pieces.fragment
        );
        return parse_fragment(rest, pieces$1);
      }
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          new Some(original),
          pieces.fragment
        )
      );
    } else {
      let $ = pop_codeunit(uri_string);
      let rest;
      rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_query_with_question_mark(uri_string, pieces) {
  return parse_query_with_question_mark_loop(uri_string, uri_string, pieces, 0);
}
function parse_path_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let path2 = string_codeunit_slice(original, 0, size2);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        pieces.port,
        path2,
        pieces.query,
        pieces.fragment
      );
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let path2 = string_codeunit_slice(original, 0, size2);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        pieces.port,
        path2,
        pieces.query,
        pieces.fragment
      );
      return parse_fragment(rest, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          original,
          pieces.query,
          pieces.fragment
        )
      );
    } else {
      let $ = pop_codeunit(uri_string);
      let rest;
      rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_path(uri_string, pieces) {
  return parse_path_loop(uri_string, uri_string, pieces, 0);
}
function parse_port_loop(loop$uri_string, loop$pieces, loop$port) {
  while (true) {
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let port = loop$port;
    if (uri_string.startsWith("0")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10;
    } else if (uri_string.startsWith("1")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 1;
    } else if (uri_string.startsWith("2")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 2;
    } else if (uri_string.startsWith("3")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 3;
    } else if (uri_string.startsWith("4")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 4;
    } else if (uri_string.startsWith("5")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 5;
    } else if (uri_string.startsWith("6")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 6;
    } else if (uri_string.startsWith("7")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 7;
    } else if (uri_string.startsWith("8")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 8;
    } else if (uri_string.startsWith("9")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 9;
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        new Some(port),
        pieces.path,
        pieces.query,
        pieces.fragment
      );
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        new Some(port),
        pieces.path,
        pieces.query,
        pieces.fragment
      );
      return parse_fragment(rest, pieces$1);
    } else if (uri_string.startsWith("/")) {
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        new Some(port),
        pieces.path,
        pieces.query,
        pieces.fragment
      );
      return parse_path(uri_string, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          new Some(port),
          pieces.path,
          pieces.query,
          pieces.fragment
        )
      );
    } else {
      return new Error(void 0);
    }
  }
}
function parse_port(uri_string, pieces) {
  if (uri_string.startsWith(":0")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 0);
  } else if (uri_string.startsWith(":1")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 1);
  } else if (uri_string.startsWith(":2")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 2);
  } else if (uri_string.startsWith(":3")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 3);
  } else if (uri_string.startsWith(":4")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 4);
  } else if (uri_string.startsWith(":5")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 5);
  } else if (uri_string.startsWith(":6")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 6);
  } else if (uri_string.startsWith(":7")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 7);
  } else if (uri_string.startsWith(":8")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 8);
  } else if (uri_string.startsWith(":9")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 9);
  } else if (uri_string === ":") {
    return new Ok(pieces);
  } else if (uri_string === "") {
    return new Ok(pieces);
  } else if (uri_string.startsWith("?")) {
    let rest = uri_string.slice(1);
    return parse_query_with_question_mark(rest, pieces);
  } else if (uri_string.startsWith(":?")) {
    let rest = uri_string.slice(2);
    return parse_query_with_question_mark(rest, pieces);
  } else if (uri_string.startsWith("#")) {
    let rest = uri_string.slice(1);
    return parse_fragment(rest, pieces);
  } else if (uri_string.startsWith(":#")) {
    let rest = uri_string.slice(2);
    return parse_fragment(rest, pieces);
  } else if (uri_string.startsWith("/")) {
    return parse_path(uri_string, pieces);
  } else if (uri_string.startsWith(":")) {
    let rest = uri_string.slice(1);
    if (rest.startsWith("/")) {
      return parse_path(rest, pieces);
    } else {
      return new Error(void 0);
    }
  } else {
    return new Error(void 0);
  }
}
function parse_host_outside_of_brackets_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(original),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        )
      );
    } else if (uri_string.startsWith(":")) {
      let host = string_codeunit_slice(original, 0, size2);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment
      );
      return parse_port(uri_string, pieces$1);
    } else if (uri_string.startsWith("/")) {
      let host = string_codeunit_slice(original, 0, size2);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment
      );
      return parse_path(uri_string, pieces$1);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size2);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment
      );
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size2);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment
      );
      return parse_fragment(rest, pieces$1);
    } else {
      let $ = pop_codeunit(uri_string);
      let rest;
      rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_host_within_brackets_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(uri_string),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        )
      );
    } else if (uri_string.startsWith("]")) {
      if (size2 === 0) {
        let rest = uri_string.slice(1);
        return parse_port(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let host = string_codeunit_slice(original, 0, size2 + 1);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_port(rest, pieces$1);
      }
    } else if (uri_string.startsWith("/")) {
      if (size2 === 0) {
        return parse_path(uri_string, pieces);
      } else {
        let host = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_path(uri_string, pieces$1);
      }
    } else if (uri_string.startsWith("?")) {
      if (size2 === 0) {
        let rest = uri_string.slice(1);
        return parse_query_with_question_mark(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let host = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_query_with_question_mark(rest, pieces$1);
      }
    } else if (uri_string.startsWith("#")) {
      if (size2 === 0) {
        let rest = uri_string.slice(1);
        return parse_fragment(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let host = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_fragment(rest, pieces$1);
      }
    } else {
      let $ = pop_codeunit(uri_string);
      let char;
      let rest;
      char = $[0];
      rest = $[1];
      let $1 = is_valid_host_within_brackets_char(char);
      if ($1) {
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size2 + 1;
      } else {
        return parse_host_outside_of_brackets_loop(
          original,
          original,
          pieces,
          0
        );
      }
    }
  }
}
function parse_host_within_brackets(uri_string, pieces) {
  return parse_host_within_brackets_loop(uri_string, uri_string, pieces, 0);
}
function parse_host_outside_of_brackets(uri_string, pieces) {
  return parse_host_outside_of_brackets_loop(uri_string, uri_string, pieces, 0);
}
function parse_host(uri_string, pieces) {
  if (uri_string.startsWith("[")) {
    return parse_host_within_brackets(uri_string, pieces);
  } else if (uri_string.startsWith(":")) {
    let pieces$1 = new Uri(
      pieces.scheme,
      pieces.userinfo,
      new Some(""),
      pieces.port,
      pieces.path,
      pieces.query,
      pieces.fragment
    );
    return parse_port(uri_string, pieces$1);
  } else if (uri_string === "") {
    return new Ok(
      new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(""),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment
      )
    );
  } else {
    return parse_host_outside_of_brackets(uri_string, pieces);
  }
}
function parse_userinfo_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("@")) {
      if (size2 === 0) {
        let rest = uri_string.slice(1);
        return parse_host(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let userinfo = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          pieces.scheme,
          new Some(userinfo),
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_host(rest, pieces$1);
      }
    } else if (uri_string === "") {
      return parse_host(original, pieces);
    } else if (uri_string.startsWith("/")) {
      return parse_host(original, pieces);
    } else if (uri_string.startsWith("?")) {
      return parse_host(original, pieces);
    } else if (uri_string.startsWith("#")) {
      return parse_host(original, pieces);
    } else {
      let $ = pop_codeunit(uri_string);
      let rest;
      rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_authority_pieces(string5, pieces) {
  return parse_userinfo_loop(string5, string5, pieces, 0);
}
function parse_authority_with_slashes(uri_string, pieces) {
  if (uri_string === "//") {
    return new Ok(
      new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(""),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment
      )
    );
  } else if (uri_string.startsWith("//")) {
    let rest = uri_string.slice(2);
    return parse_authority_pieces(rest, pieces);
  } else {
    return parse_path(uri_string, pieces);
  }
}
function parse_scheme_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("/")) {
      if (size2 === 0) {
        return parse_authority_with_slashes(uri_string, pieces);
      } else {
        let scheme = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          new Some(lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_authority_with_slashes(uri_string, pieces$1);
      }
    } else if (uri_string.startsWith("?")) {
      if (size2 === 0) {
        let rest = uri_string.slice(1);
        return parse_query_with_question_mark(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let scheme = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          new Some(lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_query_with_question_mark(rest, pieces$1);
      }
    } else if (uri_string.startsWith("#")) {
      if (size2 === 0) {
        let rest = uri_string.slice(1);
        return parse_fragment(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let scheme = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          new Some(lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_fragment(rest, pieces$1);
      }
    } else if (uri_string.startsWith(":")) {
      if (size2 === 0) {
        return new Error(void 0);
      } else {
        let rest = uri_string.slice(1);
        let scheme = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(
          new Some(lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment
        );
        return parse_authority_with_slashes(rest, pieces$1);
      }
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          original,
          pieces.query,
          pieces.fragment
        )
      );
    } else {
      let $ = pop_codeunit(uri_string);
      let rest;
      rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function to_string5(uri) {
  let _block;
  let $ = uri.fragment;
  if ($ instanceof Some) {
    let fragment3 = $[0];
    _block = toList(["#", fragment3]);
  } else {
    _block = toList([]);
  }
  let parts = _block;
  let _block$1;
  let $1 = uri.query;
  if ($1 instanceof Some) {
    let query = $1[0];
    _block$1 = prepend("?", prepend(query, parts));
  } else {
    _block$1 = parts;
  }
  let parts$1 = _block$1;
  let parts$2 = prepend(uri.path, parts$1);
  let _block$2;
  let $2 = uri.host;
  let $3 = starts_with(uri.path, "/");
  if (!$3 && $2 instanceof Some) {
    let host = $2[0];
    if (host !== "") {
      _block$2 = prepend("/", parts$2);
    } else {
      _block$2 = parts$2;
    }
  } else {
    _block$2 = parts$2;
  }
  let parts$3 = _block$2;
  let _block$3;
  let $4 = uri.host;
  let $5 = uri.port;
  if ($5 instanceof Some && $4 instanceof Some) {
    let port = $5[0];
    _block$3 = prepend(":", prepend(to_string(port), parts$3));
  } else {
    _block$3 = parts$3;
  }
  let parts$4 = _block$3;
  let _block$4;
  let $6 = uri.scheme;
  let $7 = uri.userinfo;
  let $8 = uri.host;
  if ($8 instanceof Some) {
    if ($7 instanceof Some) {
      if ($6 instanceof Some) {
        let h = $8[0];
        let u = $7[0];
        let s = $6[0];
        _block$4 = prepend(
          s,
          prepend(
            "://",
            prepend(u, prepend("@", prepend(h, parts$4)))
          )
        );
      } else {
        _block$4 = parts$4;
      }
    } else if ($6 instanceof Some) {
      let h = $8[0];
      let s = $6[0];
      _block$4 = prepend(s, prepend("://", prepend(h, parts$4)));
    } else {
      let h = $8[0];
      _block$4 = prepend("//", prepend(h, parts$4));
    }
  } else if ($7 instanceof Some) {
    if ($6 instanceof Some) {
      let s = $6[0];
      _block$4 = prepend(s, prepend(":", parts$4));
    } else {
      _block$4 = parts$4;
    }
  } else if ($6 instanceof Some) {
    let s = $6[0];
    _block$4 = prepend(s, prepend(":", parts$4));
  } else {
    _block$4 = parts$4;
  }
  let parts$5 = _block$4;
  return concat2(parts$5);
}
var empty4 = /* @__PURE__ */ new Uri(
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  "",
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None()
);
function parse2(uri_string) {
  return parse_scheme_loop(uri_string, uri_string, empty4, 0);
}

// build/dev/javascript/lustre_websocket/lustre_websocket.mjs
var InvalidUrl = class extends CustomType {
};
var OnOpen = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var OnTextMessage = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var OnBinaryMessage = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};

// build/dev/javascript/shared/shared_user.mjs
var UserId = class extends CustomType {
  constructor(v) {
    super();
    this.v = v;
  }
};
var Username = class extends CustomType {
  constructor(v) {
    super();
    this.v = v;
  }
};
var UserDto = class extends CustomType {
  constructor(id, username, email, email_verified) {
    super();
    this.id = id;
    this.username = username;
    this.email = email;
    this.email_verified = email_verified;
  }
};
var CreateUserDto = class extends CustomType {
  constructor(username, email, password) {
    super();
    this.username = username;
    this.email = email;
    this.password = password;
  }
};
var UserLoginDto = class extends CustomType {
  constructor(username, password) {
    super();
    this.username = username;
    this.password = password;
  }
};
var UsersByUsernameDto = class extends CustomType {
  constructor(username) {
    super();
    this.username = username;
  }
};
var UserMiniDto = class extends CustomType {
  constructor(id, username) {
    super();
    this.id = id;
    this.username = username;
  }
};
function decode_user_dto() {
  return field(
    "id",
    string2,
    (id) => {
      return field(
        "username",
        string2,
        (username) => {
          return field(
            "email",
            string2,
            (email) => {
              return field(
                "email_verified",
                bool,
                (email_verified) => {
                  return success(
                    new UserDto(
                      (() => {
                        let _pipe = id;
                        return new UserId(_pipe);
                      })(),
                      (() => {
                        let _pipe = username;
                        return new Username(_pipe);
                      })(),
                      email,
                      email_verified
                    )
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}
function create_user_dto_to_json(create_user) {
  return object2(
    toList([
      ["username", string3(create_user.username.v)],
      ["email", string3(create_user.email)],
      ["password", string3(create_user.password)]
    ])
  );
}
function user_loging_dto_to_json(user_login) {
  return object2(
    toList([
      ["username", string3(user_login.username)],
      ["password", string3(user_login.password)]
    ])
  );
}
function users_by_username_dto_to_json(dto) {
  return object2(toList([["username", string3(dto.username.v)]]));
}
function decode_user_mini_dto() {
  return field(
    "id",
    string2,
    (id) => {
      return field(
        "username",
        string2,
        (username) => {
          return success(
            new UserMiniDto(
              (() => {
                let _pipe = id;
                return new UserId(_pipe);
              })(),
              (() => {
                let _pipe = username;
                return new Username(_pipe);
              })()
            )
          );
        }
      );
    }
  );
}

// build/dev/javascript/shared/shared_chat.mjs
var ChatMessage = class extends CustomType {
  constructor(sender, receiver, delivery, sent_time, text_content) {
    super();
    this.sender = sender;
    this.receiver = receiver;
    this.delivery = delivery;
    this.sent_time = sent_time;
    this.text_content = text_content;
  }
};
var Draft = class extends CustomType {
};
var Sending = class extends CustomType {
};
var Sent = class extends CustomType {
};
var Delivered = class extends CustomType {
};
var Read = class extends CustomType {
};
function chat_message_delivery_to_json(chat_message_delivery) {
  if (chat_message_delivery instanceof Draft) {
    return string3("draft");
  } else if (chat_message_delivery instanceof Sending) {
    return string3("sending");
  } else if (chat_message_delivery instanceof Sent) {
    return string3("sent");
  } else if (chat_message_delivery instanceof Delivered) {
    return string3("delivered");
  } else {
    return string3("read");
  }
}
function chat_message_delivery_decoder() {
  return then$(
    string2,
    (variant) => {
      if (variant === "draft") {
        return success(new Draft());
      } else if (variant === "sending") {
        return success(new Sending());
      } else if (variant === "sent") {
        return success(new Sent());
      } else if (variant === "delivered") {
        return success(new Delivered());
      } else if (variant === "read") {
        return success(new Read());
      } else {
        return failure(new Draft(), "ChatMessageDelivery");
      }
    }
  );
}
function chat_message_to_json(chat_message) {
  let sender;
  let receiver;
  let delivery;
  let sent_time;
  let text_content;
  sender = chat_message.sender;
  receiver = chat_message.receiver;
  delivery = chat_message.delivery;
  sent_time = chat_message.sent_time;
  text_content = chat_message.text_content;
  return object2(
    toList([
      ["sender", string3(sender.v)],
      ["receiver", string3(receiver.v)],
      ["delivery", chat_message_delivery_to_json(delivery)],
      [
        "sent_time",
        (() => {
          if (sent_time instanceof Some) {
            let value2 = sent_time[0];
            let _pipe = value2;
            let _pipe$1 = to_unix_seconds(_pipe);
            let _pipe$2 = round2(_pipe$1);
            return int3(_pipe$2);
          } else {
            return null$();
          }
        })()
      ],
      ["text_content", array2(text_content, string3)]
    ])
  );
}
function chat_message_decoder() {
  return field(
    "sender",
    string2,
    (sender) => {
      return field(
        "receiver",
        string2,
        (receiver) => {
          return field(
            "delivery",
            chat_message_delivery_decoder(),
            (delivery) => {
              return field(
                "sent_time",
                (() => {
                  let _pipe = int2;
                  return optional(_pipe);
                })(),
                (sent_time) => {
                  return field(
                    "text_content",
                    (() => {
                      let _pipe = string2;
                      return list2(_pipe);
                    })(),
                    (text_content) => {
                      let _pipe = new ChatMessage(
                        (() => {
                          let _pipe2 = sender;
                          return new UserId(_pipe2);
                        })(),
                        (() => {
                          let _pipe2 = receiver;
                          return new UserId(_pipe2);
                        })(),
                        delivery,
                        (() => {
                          let _pipe2 = sent_time;
                          return map(
                            _pipe2,
                            from_unix_seconds
                          );
                        })(),
                        text_content
                      );
                      return success(_pipe);
                    }
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}

// build/dev/javascript/shared/shared_session.mjs
var SessionId = class extends CustomType {
  constructor(v) {
    super();
    this.v = v;
  }
};
var SessionDto = class extends CustomType {
  constructor(id, user_id, username, expires_at) {
    super();
    this.id = id;
    this.user_id = user_id;
    this.username = username;
    this.expires_at = expires_at;
  }
};
function decode_dto() {
  return field(
    "id",
    string2,
    (id) => {
      return field(
        "user_id",
        string2,
        (user_id) => {
          return field(
            "username",
            string2,
            (username) => {
              return field(
                "expires_at",
                int2,
                (expires_at) => {
                  let _pipe = new SessionDto(
                    (() => {
                      let _pipe2 = id;
                      return new SessionId(_pipe2);
                    })(),
                    (() => {
                      let _pipe2 = user_id;
                      return new UserId(_pipe2);
                    })(),
                    (() => {
                      let _pipe2 = username;
                      return new Username(_pipe2);
                    })(),
                    (() => {
                      let _pipe2 = expires_at;
                      return from_unix_seconds(_pipe2);
                    })()
                  );
                  return success(_pipe);
                }
              );
            }
          );
        }
      );
    }
  );
}
function to_json4(dto) {
  return object2(
    toList([
      [
        "id",
        (() => {
          let _pipe = dto.id.v;
          return string3(_pipe);
        })()
      ],
      [
        "user_id",
        (() => {
          let _pipe = dto.user_id.v;
          return string3(_pipe);
        })()
      ],
      [
        "username",
        (() => {
          let _pipe = dto.username.v;
          return string3(_pipe);
        })()
      ],
      [
        "expires_at",
        (() => {
          let _pipe = dto.expires_at;
          let _pipe$1 = to_unix_seconds(_pipe);
          let _pipe$2 = round2(_pipe$1);
          return int3(_pipe$2);
        })()
      ]
    ])
  );
}

// build/dev/javascript/gleam_http/gleam/http.mjs
var Get = class extends CustomType {
};
var Post = class extends CustomType {
};
var Head = class extends CustomType {
};
var Put = class extends CustomType {
};
var Delete = class extends CustomType {
};
var Trace = class extends CustomType {
};
var Connect = class extends CustomType {
};
var Options = class extends CustomType {
};
var Patch2 = class extends CustomType {
};
var Http = class extends CustomType {
};
var Https = class extends CustomType {
};
function method_to_string(method) {
  if (method instanceof Get) {
    return "GET";
  } else if (method instanceof Post) {
    return "POST";
  } else if (method instanceof Head) {
    return "HEAD";
  } else if (method instanceof Put) {
    return "PUT";
  } else if (method instanceof Delete) {
    return "DELETE";
  } else if (method instanceof Trace) {
    return "TRACE";
  } else if (method instanceof Connect) {
    return "CONNECT";
  } else if (method instanceof Options) {
    return "OPTIONS";
  } else if (method instanceof Patch2) {
    return "PATCH";
  } else {
    let s = method[0];
    return s;
  }
}
function scheme_to_string(scheme) {
  if (scheme instanceof Http) {
    return "http";
  } else {
    return "https";
  }
}
function scheme_from_string(scheme) {
  let $ = lowercase(scheme);
  if ($ === "http") {
    return new Ok(new Http());
  } else if ($ === "https") {
    return new Ok(new Https());
  } else {
    return new Error(void 0);
  }
}

// build/dev/javascript/gleam_http/gleam/http/request.mjs
var Request = class extends CustomType {
  constructor(method, headers, body, scheme, host, port, path2, query) {
    super();
    this.method = method;
    this.headers = headers;
    this.body = body;
    this.scheme = scheme;
    this.host = host;
    this.port = port;
    this.path = path2;
    this.query = query;
  }
};
function to_uri(request) {
  return new Uri(
    new Some(scheme_to_string(request.scheme)),
    new None(),
    new Some(request.host),
    request.port,
    request.path,
    request.query,
    new None()
  );
}
function from_uri(uri) {
  return try$(
    (() => {
      let _pipe = uri.scheme;
      let _pipe$1 = unwrap(_pipe, "");
      return scheme_from_string(_pipe$1);
    })(),
    (scheme) => {
      return try$(
        (() => {
          let _pipe = uri.host;
          return to_result(_pipe, void 0);
        })(),
        (host) => {
          let req = new Request(
            new Get(),
            toList([]),
            "",
            scheme,
            host,
            uri.port,
            uri.path,
            uri.query
          );
          return new Ok(req);
        }
      );
    }
  );
}
function set_header(request, key, value2) {
  let headers = key_set(request.headers, lowercase(key), value2);
  return new Request(
    request.method,
    headers,
    request.body,
    request.scheme,
    request.host,
    request.port,
    request.path,
    request.query
  );
}
function set_body(req, body) {
  let method;
  let headers;
  let scheme;
  let host;
  let port;
  let path2;
  let query;
  method = req.method;
  headers = req.headers;
  scheme = req.scheme;
  host = req.host;
  port = req.port;
  path2 = req.path;
  query = req.query;
  return new Request(method, headers, body, scheme, host, port, path2, query);
}
function set_method(req, method) {
  return new Request(
    method,
    req.headers,
    req.body,
    req.scheme,
    req.host,
    req.port,
    req.path,
    req.query
  );
}
function to(url) {
  let _pipe = url;
  let _pipe$1 = parse2(_pipe);
  return try$(_pipe$1, from_uri);
}

// build/dev/javascript/gleam_http/gleam/http/response.mjs
var Response = class extends CustomType {
  constructor(status, headers, body) {
    super();
    this.status = status;
    this.headers = headers;
    this.body = body;
  }
};
function get_header(response, key) {
  return key_find(response.headers, lowercase(key));
}

// build/dev/javascript/gleam_javascript/gleam_javascript_ffi.mjs
var PromiseLayer = class _PromiseLayer {
  constructor(promise) {
    this.promise = promise;
  }
  static wrap(value2) {
    return value2 instanceof Promise ? new _PromiseLayer(value2) : value2;
  }
  static unwrap(value2) {
    return value2 instanceof _PromiseLayer ? value2.promise : value2;
  }
};
function resolve(value2) {
  return Promise.resolve(PromiseLayer.wrap(value2));
}
function then_await(promise, fn) {
  return promise.then((value2) => fn(PromiseLayer.unwrap(value2)));
}
function map_promise(promise, fn) {
  return promise.then(
    (value2) => PromiseLayer.wrap(fn(PromiseLayer.unwrap(value2)))
  );
}

// build/dev/javascript/gleam_javascript/gleam/javascript/promise.mjs
function tap(promise, callback) {
  let _pipe = promise;
  return map_promise(
    _pipe,
    (a) => {
      callback(a);
      return a;
    }
  );
}
function try_await(promise, callback) {
  let _pipe = promise;
  return then_await(
    _pipe,
    (result) => {
      if (result instanceof Ok) {
        let a = result[0];
        return callback(a);
      } else {
        let e = result[0];
        return resolve(new Error(e));
      }
    }
  );
}

// build/dev/javascript/gleam_fetch/gleam_fetch_ffi.mjs
async function raw_send(request) {
  try {
    return new Ok(await fetch(request));
  } catch (error) {
    return new Error(new NetworkError(error.toString()));
  }
}
function from_fetch_response(response) {
  return new Response(
    response.status,
    List.fromArray([...response.headers]),
    response
  );
}
function request_common(request) {
  let url = to_string5(to_uri(request));
  let method = method_to_string(request.method).toUpperCase();
  let options = {
    headers: make_headers(request.headers),
    method
  };
  return [url, options];
}
function to_fetch_request(request) {
  let [url, options] = request_common(request);
  if (options.method !== "GET" && options.method !== "HEAD") options.body = request.body;
  return new globalThis.Request(url, options);
}
function make_headers(headersList) {
  let headers = new globalThis.Headers();
  for (let [k, v] of headersList) headers.append(k.toLowerCase(), v);
  return headers;
}
async function read_text_body(response) {
  let body;
  try {
    body = await response.body.text();
  } catch (error) {
    return new Error(new UnableToReadBody());
  }
  return new Ok(response.withFields({ body }));
}

// build/dev/javascript/gleam_fetch/gleam/fetch.mjs
var NetworkError = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var UnableToReadBody = class extends CustomType {
};
function send2(request) {
  let _pipe = request;
  let _pipe$1 = to_fetch_request(_pipe);
  let _pipe$2 = raw_send(_pipe$1);
  return try_await(
    _pipe$2,
    (resp) => {
      return resolve(new Ok(from_fetch_response(resp)));
    }
  );
}

// build/dev/javascript/rsvp/rsvp.mjs
var BadBody = class extends CustomType {
};
var HttpError = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var JsonError = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var NetworkError2 = class extends CustomType {
};
var UnhandledResponse = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Handler2 = class extends CustomType {
  constructor(run2) {
    super();
    this.run = run2;
  }
};
function expect_ok_response(handler) {
  return new Handler2(
    (result) => {
      return handler(
        try$(
          result,
          (response) => {
            let $ = response.status;
            let code = $;
            if (code >= 200 && code < 300) {
              return new Ok(response);
            } else {
              let code$1 = $;
              if (code$1 >= 400 && code$1 < 600) {
                return new Error(new HttpError(response));
              } else {
                return new Error(new UnhandledResponse(response));
              }
            }
          }
        )
      );
    }
  );
}
function expect_json_response(handler) {
  return expect_ok_response(
    (result) => {
      return handler(
        try$(
          result,
          (response) => {
            let $ = get_header(response, "content-type");
            if ($ instanceof Ok) {
              let $1 = $[0];
              if ($1 === "application/json") {
                return new Ok(response);
              } else if ($1.startsWith("application/json;")) {
                return new Ok(response);
              } else {
                return new Error(new UnhandledResponse(response));
              }
            } else {
              return new Error(new UnhandledResponse(response));
            }
          }
        )
      );
    }
  );
}
function do_send(request, handler) {
  return from(
    (dispatch) => {
      let _pipe = send2(request);
      let _pipe$1 = try_await(_pipe, read_text_body);
      let _pipe$2 = map_promise(
        _pipe$1,
        (_capture) => {
          return map_error(
            _capture,
            (error) => {
              if (error instanceof NetworkError) {
                return new NetworkError2();
              } else if (error instanceof UnableToReadBody) {
                return new BadBody();
              } else {
                return new BadBody();
              }
            }
          );
        }
      );
      let _pipe$3 = map_promise(_pipe$2, handler.run);
      tap(_pipe$3, dispatch);
      return void 0;
    }
  );
}
function send3(request, handler) {
  return do_send(request, handler);
}
function decode_json_body(response, decoder) {
  let _pipe = response.body;
  let _pipe$1 = parse(_pipe, decoder);
  return map_error(_pipe$1, (var0) => {
    return new JsonError(var0);
  });
}
function expect_json(decoder, handler) {
  return expect_json_response(
    (result) => {
      let _pipe = result;
      let _pipe$1 = try$(
        _pipe,
        (_capture) => {
          return decode_json_body(_capture, decoder);
        }
      );
      return handler(_pipe$1);
    }
  );
}

// build/dev/javascript/app/util/timeout.ffi.js
function setTimeout2(callback, milliseconds2) {
  globalThis.setTimeout(callback, milliseconds2);
}

// build/dev/javascript/app/util/time_util.mjs
function duration_to_millis(duration) {
  return round2(to_seconds(duration) * 1e3);
}
function set_timeout(callback, duration) {
  return setTimeout2(
    callback,
    (() => {
      let _pipe = duration;
      return duration_to_millis(_pipe);
    })()
  );
}
function timestamp_to_millis(timestamp) {
  return round2(to_unix_seconds(timestamp) * 1e3);
}
function millis_now() {
  let _pipe = system_time2();
  return timestamp_to_millis(_pipe);
}

// build/dev/javascript/app/util/toast.mjs
var FILEPATH = "src/util/toast.gleam";
var Toast = class extends CustomType {
  constructor(id, content, toast_style, duration) {
    super();
    this.id = id;
    this.content = content;
    this.toast_style = toast_style;
    this.duration = duration;
  }
};
var Info = class extends CustomType {
};
var Warning = class extends CustomType {
};
var Failure = class extends CustomType {
};
function encode_toast_style(style) {
  let _block;
  if (style instanceof Info) {
    _block = "info";
  } else if (style instanceof Warning) {
    _block = "warning";
  } else {
    _block = "failure";
  }
  let _pipe = _block;
  return string3(_pipe);
}
function encode_toast(toast) {
  return object2(
    toList([
      ["id", int3(toast.id)],
      ["content", string3(toast.content)],
      ["toast_style", encode_toast_style(toast.toast_style)],
      ["duration", int3(duration_to_millis(toast.duration))]
    ])
  );
}
function decode_toast_style() {
  let _pipe = string2;
  return map3(
    _pipe,
    (style) => {
      if (style === "failure") {
        return new Failure();
      } else if (style === "info") {
        return new Info();
      } else if (style === "warning") {
        return new Warning();
      } else {
        let other = style;
        throw makeError(
          "panic",
          FILEPATH,
          "util/toast",
          64,
          "decode_toast_style",
          "did not expect ToastStyle '" + other + "'",
          {}
        );
      }
    }
  );
}
function decode_toast() {
  return field(
    "id",
    int2,
    (id) => {
      return field(
        "content",
        string2,
        (content) => {
          return field(
            "toast_style",
            decode_toast_style(),
            (toast_style) => {
              return field(
                "duration",
                int2,
                (duration) => {
                  return success(
                    new Toast(
                      id,
                      content,
                      toast_style,
                      milliseconds(duration)
                    )
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}
function create_info_toast(content) {
  to_unix_seconds_and_nanoseconds(system_time2());
  return new Toast(
    millis_now(),
    content,
    new Info(),
    seconds(5)
  );
}
function create_error_toast(content) {
  to_unix_seconds_and_nanoseconds(system_time2());
  return new Toast(
    millis_now(),
    content,
    new Failure(),
    seconds(7)
  );
}
function add_toast(toasts, toast) {
  return prepend(toast, toasts);
}
function remove_toast_by_id(toasts, toast_id) {
  return filter(toasts, (toast) => {
    return toast.id !== toast_id;
  });
}
function view_single_toast(toast) {
  let _block;
  let $ = toast.toast_style;
  if ($ instanceof Info) {
    _block = "bg-blue-50 border-blue-200 text-blue-500";
  } else if ($ instanceof Warning) {
    _block = "bg-yellow-50 border-yellow-200 text-yellow-500";
  } else {
    _block = "bg-red-50 border-red-200 text-red-500";
  }
  let style_classes = _block;
  return div(
    toList([
      class$(
        "px-4 py-3 rounded-lg border shadow-sm pointer-events-auto min-w-64 max-w-80 whitespace-pre " + style_classes
      )
    ]),
    toList([text3(toast.content)])
  );
}
function view_toasts(toasts) {
  return div(
    toList([
      class$(
        "fixed top-4 right-4 z-50 flex flex-col gap-2 pointer-events-none"
      )
    ]),
    map2(toasts, view_single_toast)
  );
}

// build/dev/javascript/app/app_types.mjs
var Model = class extends CustomType {
  constructor(app_state, global_state) {
    super();
    this.app_state = app_state;
    this.global_state = global_state;
  }
};
var PreLogin = class extends CustomType {
};
var LoggedIn = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var GlobalState = class extends CustomType {
  constructor(toasts) {
    super();
    this.toasts = toasts;
  }
};
var LoginState = class extends CustomType {
  constructor(session, web_socket, new_conversation, selected_conversation, conversations) {
    super();
    this.session = session;
    this.web_socket = web_socket;
    this.new_conversation = new_conversation;
    this.selected_conversation = selected_conversation;
    this.conversations = conversations;
  }
};
var NewConversation = class extends CustomType {
  constructor(suggestions) {
    super();
    this.suggestions = suggestions;
  }
};
var Pending = class extends CustomType {
  constructor(since) {
    super();
    this.since = since;
  }
};
var Established = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var LoginSuccess = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var ShowToast = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var RemoveToast = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var WsWrapper = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var CheckedAuth = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var NewConversationMsg = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var UserOnSendSubmit = class extends CustomType {
};
var ApiChatMessageResponse = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var UserModalOpen = class extends CustomType {
};
var UserModalClose = class extends CustomType {
};
var UserSearchInputChange = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var ApiSearchResponse = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var UserConversationPartnerSelect = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};

// build/dev/javascript/app/location_ffi.mjs
function getProtocol() {
  return window.location.protocol;
}

// build/dev/javascript/app/util/cookie_ffi.mjs
function get_document_cookie() {
  return document.cookie || "";
}

// build/dev/javascript/app/util/cookie.mjs
function get_cookie(name2) {
  let _pipe = get_document_cookie();
  let _pipe$1 = split2(_pipe, ";");
  let _pipe$2 = map2(_pipe$1, trim);
  let _pipe$3 = filter_map(
    _pipe$2,
    (raw) => {
      return split_once(raw, "=");
    }
  );
  let _pipe$4 = find_map(
    _pipe$3,
    (cookie_pair) => {
      let key;
      let value2;
      key = cookie_pair[0];
      value2 = cookie_pair[1];
      let $ = key === name2;
      if ($) {
        return new Ok(value2);
      } else {
        return new Error(void 0);
      }
    }
  );
  return from_result(_pipe$4);
}

// build/dev/javascript/app/endpoints.mjs
var FILEPATH2 = "src/endpoints.gleam";
function get_api_url() {
  let $ = getProtocol();
  if ($ === "https:") {
    return "https://localhost:8000/api/";
  } else {
    return "http://localhost:8000/api/";
  }
}
function to_req(sub_path) {
  let url = get_api_url() + sub_path;
  let $ = (() => {
    let _pipe = url;
    return to(_pipe);
  })();
  if ($ instanceof Ok) {
    let r = $[0];
    return r;
  } else {
    throw makeError(
      "panic",
      FILEPATH2,
      "endpoints",
      60,
      "to_req",
      "failed building request for url: " + url,
      {}
    );
  }
}
function me() {
  let _pipe = "auth/me";
  return to_req(_pipe);
}
function login() {
  let _pipe = "auth/login";
  return to_req(_pipe);
}
function users() {
  let _pipe = "users";
  return to_req(_pipe);
}
function search_users() {
  let _pipe = "users/search";
  return to_req(_pipe);
}
function chats() {
  let _pipe = "chats";
  return to_req(_pipe);
}
function post_request(request, body, decoder, effect) {
  let _pipe = request;
  let _pipe$1 = set_method(_pipe, new Post());
  let _pipe$2 = set_header(_pipe$1, "content-type", "application/json");
  let _pipe$3 = set_header(
    _pipe$2,
    "x-csrf-token",
    (() => {
      let _pipe$32 = "csrf_token";
      let _pipe$42 = get_cookie(_pipe$32);
      return unwrap(_pipe$42, "");
    })()
  );
  let _pipe$4 = set_body(
    _pipe$3,
    (() => {
      let _pipe$42 = body;
      return to_string2(_pipe$42);
    })()
  );
  return send3(_pipe$4, expect_json(decoder, effect));
}
function get_request(request, decoder, effect) {
  let _pipe = request;
  let _pipe$1 = set_method(_pipe, new Get());
  return send3(_pipe$1, expect_json(decoder, effect));
}

// build/dev/javascript/app/util/form.mjs
var FormField = class extends CustomType {
  constructor(value2, touch, validators, error, custom_error) {
    super();
    this.value = value2;
    this.touch = touch;
    this.validators = validators;
    this.error = error;
    this.custom_error = custom_error;
  }
};
var StringField = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Predefined = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Custom = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Empty2 = class extends CustomType {
};
var MinLength = class extends CustomType {
  constructor(is, min2) {
    super();
    this.is = is;
    this.min = min2;
  }
};
var Pure = class extends CustomType {
};
var Dirty = class extends CustomType {
};
function get_form_field_value_as_string(field_value) {
  let v = field_value[0];
  return v;
}
function string_form_field(validators) {
  return new FormField(
    new StringField(""),
    new Pure(),
    validators,
    new None(),
    new None()
  );
}
function set_custom_error(form_field, custom_error) {
  return new FormField(
    form_field.value,
    form_field.touch,
    form_field.validators,
    form_field.error,
    new Some(custom_error)
  );
}
function clear_custom_error(form_field) {
  return new FormField(
    form_field.value,
    form_field.touch,
    form_field.validators,
    form_field.error,
    new None()
  );
}
function eval$(field2) {
  let error = fold(
    field2.validators,
    new None(),
    (acc, validator) => {
      if (acc instanceof None) {
        return validator(field2.value);
      } else {
        return acc;
      }
    }
  );
  return new FormField(
    field2.value,
    new Dirty(),
    field2.validators,
    error,
    field2.custom_error
  );
}
function set_value(field2, v) {
  let error = fold(
    field2.validators,
    new None(),
    (acc, validator) => {
      if (acc instanceof None) {
        return validator(v);
      } else {
        return acc;
      }
    }
  );
  return new FormField(
    v,
    new Dirty(),
    field2.validators,
    error,
    field2.custom_error
  );
}
function field_is_valid(field2) {
  let _pipe = fold(
    field2.validators,
    new None(),
    (acc, validator) => {
      if (acc instanceof None) {
        return validator(field2.value);
      } else {
        return acc;
      }
    }
  );
  return is_none(_pipe);
}
function get_error(field2) {
  return or(
    map(field2.error, (e) => {
      return new Predefined(e);
    }),
    map(field2.custom_error, (e) => {
      return new Custom(e);
    })
  );
}
function validator_nonempty() {
  return (value2) => {
    let $ = value2[0];
    if ($ === "") {
      return new Some(new Empty2());
    } else {
      return new None();
    }
  };
}
function validator_min_length(min2) {
  return (value2) => {
    let value$1 = value2[0];
    let is = string_length(value$1);
    let $ = is >= min2;
    if ($) {
      return new None();
    } else {
      return new Some(new MinLength(is, min2));
    }
  };
}

// build/dev/javascript/app/pre_login.mjs
var PreLoginState = class extends CustomType {
  constructor(mode, login_form_data, signup_form_data) {
    super();
    this.mode = mode;
    this.login_form_data = login_form_data;
    this.signup_form_data = signup_form_data;
  }
};
var PasswordMissmatch = class extends CustomType {
};
var LoginDetails = class extends CustomType {
  constructor(username, password) {
    super();
    this.username = username;
    this.password = password;
  }
};
var SignupFormData = class extends CustomType {
  constructor(username, email, password, password_confirm) {
    super();
    this.username = username;
    this.email = email;
    this.password = password;
    this.password_confirm = password_confirm;
  }
};
var Login = class extends CustomType {
};
var Signup = class extends CustomType {
};
var UserSetPreLoginMode = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var UserSubmitForm = class extends CustomType {
};
var UserChangeForm = class extends CustomType {
  constructor($0, $1) {
    super();
    this[0] = $0;
    this[1] = $1;
  }
};
var UserBlurForm = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var ApiRespondSignupRequest = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var ApiRespondLoginRequest = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var LoginUsername = class extends CustomType {
};
var LoginPassword = class extends CustomType {
};
var SignupUsername = class extends CustomType {
};
var SignupEmail = class extends CustomType {
};
var SignupPassword = class extends CustomType {
};
var SignupPasswordConfirm = class extends CustomType {
};
function element4(attributes) {
  return element2("pre-login", attributes, toList([]));
}
function on_login_success(handler) {
  return on(
    "login-success",
    (() => {
      let _pipe = at(toList(["detail"]), decode_dto());
      return map3(_pipe, handler);
    })()
  );
}
function on_show_toast(handler) {
  return on(
    "show-toast",
    (() => {
      let _pipe = at(toList(["detail"]), decode_toast());
      return map3(_pipe, handler);
    })()
  );
}
function init(_) {
  let default_validators = toList([
    validator_nonempty(),
    validator_min_length(5)
  ]);
  let model = new PreLoginState(
    new Login(),
    new LoginDetails(
      string_form_field(default_validators),
      string_form_field(default_validators)
    ),
    new SignupFormData(
      string_form_field(default_validators),
      string_form_field(default_validators),
      string_form_field(default_validators),
      string_form_field(toList([validator_nonempty()]))
    )
  );
  return [model, none()];
}
function evaluate_matching_passwords(model) {
  let _block;
  let $1 = !isEqual(model.password.value, model.password_confirm.value) && isEqual(
    model.password.touch,
    new Dirty()
  ) && isEqual(model.password_confirm.touch, new Dirty());
  if ($1) {
    _block = [
      set_custom_error(model.password, new PasswordMissmatch()),
      set_custom_error(model.password_confirm, new PasswordMissmatch())
    ];
  } else {
    _block = [
      clear_custom_error(model.password),
      clear_custom_error(model.password_confirm)
    ];
  }
  let $ = _block;
  let password_field;
  let password_confirm_field;
  password_field = $[0];
  password_confirm_field = $[1];
  return new SignupFormData(
    model.username,
    model.email,
    password_field,
    password_confirm_field
  );
}
function send_signup_req(signup_details, effect) {
  let _block;
  let _pipe = new CreateUserDto(
    (() => {
      let _pipe2 = signup_details.username.value;
      let _pipe$1 = get_form_field_value_as_string(_pipe2);
      return new Username(_pipe$1);
    })(),
    (() => {
      let _pipe2 = signup_details.email.value;
      return get_form_field_value_as_string(_pipe2);
    })(),
    (() => {
      let _pipe2 = signup_details.password.value;
      return get_form_field_value_as_string(_pipe2);
    })()
  );
  _block = create_user_dto_to_json(_pipe);
  let json_body = _block;
  return post_request(
    users(),
    json_body,
    decode_user_dto(),
    effect
  );
}
function send_login_req(login_details, effect) {
  let _block;
  let _pipe = new UserLoginDto(
    (() => {
      let _pipe2 = login_details.username.value;
      return get_form_field_value_as_string(_pipe2);
    })(),
    (() => {
      let _pipe2 = login_details.password.value;
      return get_form_field_value_as_string(_pipe2);
    })()
  );
  _block = user_loging_dto_to_json(_pipe);
  let json_body = _block;
  return post_request(
    login(),
    json_body,
    decode_dto(),
    effect
  );
}
function update2(model, msg) {
  let update_login = (f) => {
    return new PreLoginState(
      model.mode,
      f(model.login_form_data),
      model.signup_form_data
    );
  };
  let update_signup = (f) => {
    return new PreLoginState(
      model.mode,
      model.login_form_data,
      f(model.signup_form_data)
    );
  };
  let _block;
  if (msg instanceof UserSetPreLoginMode) {
    let mode = msg[0];
    _block = new PreLoginState(
      mode,
      model.login_form_data,
      model.signup_form_data
    );
  } else if (msg instanceof UserSubmitForm) {
    _block = model;
  } else if (msg instanceof UserChangeForm) {
    let field2 = msg[0];
    let value2 = msg[1];
    let value$1 = new StringField(value2);
    if (field2 instanceof LoginUsername) {
      _block = update_login(
        (l) => {
          return new LoginDetails(
            set_value(l.username, value$1),
            l.password
          );
        }
      );
    } else if (field2 instanceof LoginPassword) {
      _block = update_login(
        (l) => {
          return new LoginDetails(
            l.username,
            set_value(l.password, value$1)
          );
        }
      );
    } else if (field2 instanceof SignupUsername) {
      _block = update_signup(
        (r) => {
          let field$1 = set_value(r.username, value$1);
          return new SignupFormData(
            field$1,
            r.email,
            r.password,
            r.password_confirm
          );
        }
      );
    } else if (field2 instanceof SignupEmail) {
      _block = update_signup(
        (r) => {
          return new SignupFormData(
            r.username,
            set_value(r.email, value$1),
            r.password,
            r.password_confirm
          );
        }
      );
    } else if (field2 instanceof SignupPassword) {
      _block = update_signup(
        (r) => {
          let _pipe = new SignupFormData(
            r.username,
            r.email,
            set_value(r.password, value$1),
            r.password_confirm
          );
          return evaluate_matching_passwords(_pipe);
        }
      );
    } else {
      _block = update_signup(
        (r) => {
          let _pipe = new SignupFormData(
            r.username,
            r.email,
            r.password,
            set_value(r.password_confirm, value$1)
          );
          return evaluate_matching_passwords(_pipe);
        }
      );
    }
  } else if (msg instanceof UserBlurForm) {
    let field2 = msg[0];
    if (field2 instanceof LoginUsername) {
      _block = update_login(
        (l) => {
          return new LoginDetails(eval$(l.username), l.password);
        }
      );
    } else if (field2 instanceof LoginPassword) {
      _block = update_login(
        (l) => {
          return new LoginDetails(l.username, eval$(l.password));
        }
      );
    } else if (field2 instanceof SignupUsername) {
      _block = update_signup(
        (r) => {
          return new SignupFormData(
            eval$(r.username),
            r.email,
            r.password,
            r.password_confirm
          );
        }
      );
    } else if (field2 instanceof SignupEmail) {
      _block = update_signup(
        (r) => {
          return new SignupFormData(
            r.username,
            eval$(r.email),
            r.password,
            r.password_confirm
          );
        }
      );
    } else if (field2 instanceof SignupPassword) {
      _block = update_signup(
        (r) => {
          let _pipe = new SignupFormData(
            r.username,
            r.email,
            eval$(r.password),
            r.password_confirm
          );
          return evaluate_matching_passwords(_pipe);
        }
      );
    } else {
      _block = update_signup(
        (r) => {
          let _pipe = new SignupFormData(
            r.username,
            r.email,
            r.password,
            eval$(r.password_confirm)
          );
          return evaluate_matching_passwords(_pipe);
        }
      );
    }
  } else if (msg instanceof ApiRespondSignupRequest) {
    let $ = msg[0];
    if ($ instanceof Ok) {
      _block = new PreLoginState(
        new Login(),
        model.login_form_data,
        model.signup_form_data
      );
    } else {
      _block = model;
    }
  } else {
    _block = model;
  }
  let model$1 = _block;
  let _block$1;
  if (msg instanceof UserSubmitForm) {
    let $ = model$1.mode;
    if ($ instanceof Login) {
      _block$1 = send_login_req(
        model$1.login_form_data,
        (var0) => {
          return new ApiRespondLoginRequest(var0);
        }
      );
    } else {
      _block$1 = send_signup_req(
        model$1.signup_form_data,
        (var0) => {
          return new ApiRespondSignupRequest(var0);
        }
      );
    }
  } else if (msg instanceof ApiRespondSignupRequest) {
    let result = msg[0];
    if (result instanceof Ok) {
      let signup_response = result[0];
      let toast_msg = create_info_toast(
        "Signup successful for user: " + signup_response.username.v
      );
      _block$1 = emit2("show-toast", encode_toast(toast_msg));
    } else {
      let e = result[0];
      let _block$2;
      if (e instanceof HttpError) {
        let r = e[0];
        if (r.body === "username-taken") {
          _block$2 = "Signup failed:\nUsername is already taken";
        } else {
          let r$1 = e[0];
          if (r$1.body === "email-taken") {
            _block$2 = "Signup failed:\nEmail is already in use";
          } else {
            _block$2 = "Signup failed";
          }
        }
      } else {
        _block$2 = "Signup failed";
      }
      let error_message = _block$2;
      let toast_msg = create_error_toast(error_message);
      _block$1 = emit2("show-toast", encode_toast(toast_msg));
    }
  } else if (msg instanceof ApiRespondLoginRequest) {
    let result = msg[0];
    if (result instanceof Ok) {
      let session_dto = result[0];
      _block$1 = emit2(
        "login-success",
        to_json4(session_dto)
      );
    } else {
      let e = result[0];
      let _block$2;
      if (e instanceof HttpError) {
        let r = e[0];
        if (r.status === 401) {
          _block$2 = "Login failed:\nWrong username/password";
        } else {
          _block$2 = "Login failed:\nUnexpected Error";
        }
      } else {
        _block$2 = "Login failed:\nUnexpected Error";
      }
      let error_message = _block$2;
      let toast_msg = create_error_toast(error_message);
      _block$1 = emit2("show-toast", encode_toast(toast_msg));
    }
  } else {
    _block$1 = none();
  }
  let effect = _block$1;
  return [model$1, effect];
}
function get_error_text(field2) {
  let _pipe = get_error(field2);
  return map(
    _pipe,
    (e) => {
      if (e instanceof Predefined) {
        let $ = e[0];
        if ($ instanceof Empty2) {
          return "cannot be empty";
        } else {
          let is = $.is;
          let min2 = $.min;
          return "min length " + to_string(min2) + " (is " + to_string(
            is
          ) + ")";
        }
      } else {
        return "passwords don't match";
      }
    }
  );
}
function html_input(mode, property3, label2, type_2, name2, placeholder2, field2) {
  let key = (() => {
    if (mode instanceof Login) {
      return "login_";
    } else {
      return "signup_";
    }
  })() + name2;
  let _block;
  let _pipe = field2;
  _block = get_error_text(_pipe);
  let error = _block;
  let _block$1;
  let _pipe$1 = field2.value;
  _block$1 = get_form_field_value_as_string(_pipe$1);
  let value2 = _block$1;
  let _block$2;
  if (error instanceof Some) {
    let error_text = error[0];
    _block$2 = toList([
      p(
        toList([class$("mt-1 text-sm text-red-600")]),
        toList([text3(error_text)])
      )
    ]);
  } else {
    _block$2 = toList([]);
  }
  let error_element = _block$2;
  let _block$3;
  if (error instanceof Some) {
    _block$3 = "border rounded px-3 py-2 focus:outline-none focus:ring-2 \n         border-red-500 focus:ring-red-500 focus:border-red-500 \n         placeholder-red-400";
  } else {
    _block$3 = "border border-gray-300 rounded px-3 py-2 focus:outline-none \n         focus:ring-2 focus:ring-blue-500 focus:border-blue-500";
  }
  let input_classes = _block$3;
  return div2(
    toList([]),
    toList([
      [
        key,
        label(
          toList([
            class$(
              "flex flex-col gap-1 text-sm font-medium text-gray-700"
            )
          ]),
          prepend(
            text3(label2),
            prepend(
              input(
                toList([
                  class$(input_classes),
                  type_(type_2),
                  name(name2),
                  placeholder(placeholder2),
                  value(value2),
                  on_change(
                    (value3) => {
                      return new UserChangeForm(property3, value3);
                    }
                  ),
                  on_blur(new UserBlurForm(property3))
                ])
              ),
              error_element
            )
          )
        )
      ]
    ])
  );
}
function view(model) {
  let mode = model.mode;
  let _block;
  {
    let active_toggle_button_class = class$(
      "flex-1 px-3 py-2 rounded-md text-sm font-medium bg-white text-blue-600 shadow"
    );
    let inactive_toggle_button_class = class$(
      "flex-1 px-3 py-2 rounded-md text-sm font-medium text-gray-600 hover:text-gray-900"
    );
    _block = div(
      toList([class$("flex bg-gray-100 rounded-md p-1")]),
      toList([
        button(
          toList([
            (() => {
              if (mode instanceof Login) {
                return active_toggle_button_class;
              } else {
                return inactive_toggle_button_class;
              }
            })(),
            on_click(new UserSetPreLoginMode(new Login())),
            type_("button")
          ]),
          toList([text3("Login")])
        ),
        button(
          toList([
            (() => {
              if (mode instanceof Login) {
                return inactive_toggle_button_class;
              } else {
                return active_toggle_button_class;
              }
            })(),
            on_click(new UserSetPreLoginMode(new Signup())),
            type_("button")
          ]),
          toList([text3("Signup")])
        )
      ])
    );
  }
  let toggle_button = _block;
  let title = h1(
    toList([class$("text-xl font-bold text-blue-600")]),
    toList([
      text3(
        (() => {
          if (mode instanceof Login) {
            return "Login";
          } else {
            return "Create account";
          }
        })()
      )
    ])
  );
  let _block$1;
  if (mode instanceof Login) {
    _block$1 = toList([
      html_input(
        mode,
        new LoginUsername(),
        "Username",
        "text",
        "username",
        "your_username",
        model.login_form_data.username
      ),
      html_input(
        mode,
        new LoginPassword(),
        "Password",
        "password",
        "password",
        "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
        model.login_form_data.password
      )
    ]);
  } else {
    _block$1 = toList([
      html_input(
        mode,
        new SignupUsername(),
        "Username",
        "text",
        "username",
        "your_username",
        model.signup_form_data.username
      ),
      html_input(
        mode,
        new SignupEmail(),
        "Email",
        "email",
        "email",
        "you@example.com",
        model.signup_form_data.email
      ),
      html_input(
        mode,
        new SignupPassword(),
        "Password",
        "password",
        "password",
        "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
        model.signup_form_data.password
      ),
      html_input(
        mode,
        new SignupPasswordConfirm(),
        "Confirm password",
        "password",
        "password_confirm",
        "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
        model.signup_form_data.password_confirm
      )
    ]);
  }
  let fields = _block$1;
  let _block$2;
  if (mode instanceof Login) {
    _block$2 = (() => {
      let _pipe = model.login_form_data.username;
      return field_is_valid(_pipe);
    })() && (() => {
      let _pipe = model.login_form_data.password;
      return field_is_valid(_pipe);
    })();
  } else {
    _block$2 = (() => {
      let _pipe = model.signup_form_data.username;
      return field_is_valid(_pipe);
    })() && (() => {
      let _pipe = model.signup_form_data.email;
      return field_is_valid(_pipe);
    })() && (() => {
      let _pipe = model.signup_form_data.password;
      return field_is_valid(_pipe);
    })() && (() => {
      let _pipe = model.signup_form_data.password_confirm;
      return field_is_valid(_pipe);
    })();
  }
  let submit_allowed = _block$2;
  let submit_button = button(
    toList([
      class$(
        "mt-2 bg-blue-600 text-white font-semibold py-2 px-4 rounded transition-colors disabled:bg-gray-300 hover:bg-blue-700 "
      ),
      type_("submit"),
      disabled(
        (() => {
          let _pipe = submit_allowed;
          return negate2(_pipe);
        })()
      )
    ]),
    toList([
      text3(
        (() => {
          if (mode instanceof Login) {
            return "Log in";
          } else {
            return "Create account";
          }
        })()
      )
    ])
  );
  return div(
    toList([
      class$(
        "flex justify-center items-center w-full h-screen bg-gray-50"
      )
    ]),
    toList([
      form(
        toList([
          class$(
            "flex flex-col gap-5 p-8 w-80 border rounded-lg shadow-md bg-white"
          ),
          type_("submit"),
          on_submit((_) => {
            return new UserSubmitForm();
          })
        ]),
        flatten(
          toList([
            toList([toggle_button, title]),
            fields,
            toList([submit_button])
          ])
        )
      )
    ])
  );
}
function register() {
  let component2 = component(init, update2, view, toList([]));
  return make_component(component2, "pre-login");
}

// build/dev/javascript/app/util/button.mjs
function add_class(in$, add5) {
  return in$ + " " + add5;
}
function default_disabled_class(in$) {
  let _pipe = "disabled:bg-gray-300";
  return ((_capture) => {
    return add_class(in$, _capture);
  })(_pipe);
}
function default_hovered_class(in$) {
  let _pipe = "hover:bg-blue-700";
  return ((_capture) => {
    return add_class(in$, _capture);
  })(_pipe);
}

// build/dev/javascript/lustre/lustre/element/svg.mjs
var namespace = "http://www.w3.org/2000/svg";
function svg(attrs, children) {
  return namespaced(namespace, "svg", attrs, children);
}
function path(attrs) {
  return namespaced(namespace, "path", attrs, empty_list);
}

// build/dev/javascript/app/util/icons.mjs
function message_circle_plus(attributes) {
  return svg(
    prepend(
      attribute2("stroke-linejoin", "round"),
      prepend(
        attribute2("stroke-linecap", "round"),
        prepend(
          attribute2("stroke-width", "2"),
          prepend(
            attribute2("stroke", "currentColor"),
            prepend(
              attribute2("fill", "none"),
              prepend(
                attribute2("viewBox", "0 0 24 24"),
                prepend(
                  attribute2("height", "24"),
                  prepend(attribute2("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(
        toList([
          attribute2(
            "d",
            "M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719"
          )
        ])
      ),
      path(toList([attribute2("d", "M8 12h8")])),
      path(toList([attribute2("d", "M12 8v8")]))
    ])
  );
}

// build/dev/javascript/app/util/toast_state.mjs
function show_toast(model, toast_msg) {
  let new_toasts = add_toast(model.global_state.toasts, toast_msg);
  let new_global_state = new GlobalState(new_toasts);
  let timeout_effect = from(
    (dispatch) => {
      return set_timeout(
        () => {
          return dispatch(new RemoveToast(toast_msg.id));
        },
        toast_msg.duration
      );
    }
  );
  return [new Model(model.app_state, new_global_state), timeout_effect];
}
function remove_toast(model, toast_id) {
  let new_toasts = remove_toast_by_id(
    model.global_state.toasts,
    toast_id
  );
  let new_global_state = new GlobalState(new_toasts);
  return [new Model(model.app_state, new_global_state), none()];
}
function toast_incl_socket_disconnet(model) {
  let toasts_without_socket_error = filter(
    model.global_state.toasts,
    (toast_msg) => {
      return !starts_with(toast_msg.content, "Socket connection lost");
    }
  );
  let $ = model.app_state;
  if ($ instanceof LoggedIn) {
    let login_state = $[0];
    let $1 = login_state.web_socket;
    if ($1 instanceof Pending) {
      let since = $1.since;
      let $2 = compare4(
        (() => {
          let _pipe = since;
          return add3(_pipe, seconds(5));
        })(),
        system_time2()
      );
      if ($2 instanceof Gt) {
        return add_toast(
          model.global_state.toasts,
          create_error_toast("Socket connection lost - reconnecting...")
        );
      } else {
        return toasts_without_socket_error;
      }
    } else {
      return toasts_without_socket_error;
    }
  } else {
    return toasts_without_socket_error;
  }
}

// build/dev/javascript/app/app.mjs
var FILEPATH3 = "src/app.gleam";
function check_auth() {
  return get_request(
    me(),
    decode_dto(),
    (var0) => {
      return new CheckedAuth(var0);
    }
  );
}
function init2(_) {
  let model = new Model(new PreLogin(), new GlobalState(toList([])));
  let effect = check_auth();
  return [model, effect];
}
function send_message(model) {
  let $ = model.app_state;
  let login_state;
  if ($ instanceof LoggedIn) {
    login_state = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH3,
      "app",
      193,
      "send_message",
      "must be logged in at this point",
      {
        value: $,
        start: 5171,
        end: 5221,
        pattern_start: 5182,
        pattern_end: 5203
      }
    );
  }
  let _block;
  let _pipe = login_state.conversations;
  let _pipe$1 = map_to_list(_pipe);
  _block = find_map(
    _pipe$1,
    (item) => {
      let user;
      let messages;
      user = item[0];
      messages = item[1];
      let $2 = isEqual(
        new Some(user.id),
        map(
          login_state.selected_conversation,
          (conv) => {
            return conv.id;
          }
        )
      );
      if ($2) {
        return find2(
          messages,
          (msg) => {
            return isEqual(msg.delivery, new Draft());
          }
        );
      } else {
        return new Error(void 0);
      }
    }
  );
  let $1 = _block;
  let draft;
  if ($1 instanceof Ok) {
    draft = $1[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH3,
      "app",
      196,
      "send_message",
      "shouldn't be allowed to send without draft msg",
      {
        value: $1,
        start: 5266,
        end: 5672,
        pattern_start: 5277,
        pattern_end: 5286
      }
    );
  }
  return post_request(
    chats(),
    (() => {
      let _pipe$2 = draft;
      return chat_message_to_json(_pipe$2);
    })(),
    chat_message_decoder(),
    (var0) => {
      return new ApiChatMessageResponse(var0);
    }
  );
}
function search_usernames(value2) {
  let _block;
  let _pipe = value2;
  let _pipe$1 = new Username(_pipe);
  let _pipe$2 = new UsersByUsernameDto(_pipe$1);
  _block = users_by_username_dto_to_json(_pipe$2);
  let json_body = _block;
  return post_request(
    search_users(),
    json_body,
    list2(decode_user_mini_dto()),
    (r) => {
      return new NewConversationMsg(new ApiSearchResponse(r));
    }
  );
}
function handle_new_conversation_msg(model, msg) {
  let $ = model.app_state;
  let login_state;
  if ($ instanceof LoggedIn) {
    login_state = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH3,
      "app",
      118,
      "handle_new_conversation_msg",
      "must be logged in at this point",
      {
        value: $,
        start: 3262,
        end: 3312,
        pattern_start: 3273,
        pattern_end: 3294
      }
    );
  }
  let _block;
  if (msg instanceof UserModalOpen) {
    _block = [new Some(new NewConversation(toList([]))), search_usernames("")];
  } else if (msg instanceof UserModalClose) {
    _block = [new None(), none()];
  } else if (msg instanceof UserSearchInputChange) {
    let v = msg[0];
    _block = [login_state.new_conversation, search_usernames(v)];
  } else if (msg instanceof ApiSearchResponse) {
    let $22 = msg[0];
    if ($22 instanceof Ok) {
      let items = $22[0];
      _block = [
        new Some(
          new NewConversation(
            filter(
              items,
              (item) => {
                return !isEqual(item.id, login_state.session.user_id);
              }
            )
          )
        ),
        none()
      ];
    } else {
      _block = [login_state.new_conversation, none()];
    }
  } else {
    _block = [new None(), none()];
  }
  let $1 = _block;
  let new_conversation;
  let effect;
  new_conversation = $1[0];
  effect = $1[1];
  let _block$1;
  if (msg instanceof ApiSearchResponse) {
    let $3 = msg[0];
    if ($3 instanceof Error) {
      let toast_effect = from(
        (dispatch) => {
          return dispatch(
            new ShowToast(create_error_toast("Failed to search users"))
          );
        }
      );
      _block$1 = [
        login_state.selected_conversation,
        login_state.conversations,
        toast_effect
      ];
    } else {
      _block$1 = [
        login_state.selected_conversation,
        login_state.conversations,
        none()
      ];
    }
  } else if (msg instanceof UserConversationPartnerSelect) {
    let dto = msg[0];
    let next_conversations = upsert(
      login_state.conversations,
      dto,
      (curr) => {
        if (curr instanceof Some) {
          let chat_messages = curr[0];
          return chat_messages;
        } else {
          return toList([]);
        }
      }
    );
    _block$1 = [new Some(dto), next_conversations, none()];
  } else {
    _block$1 = [
      login_state.selected_conversation,
      login_state.conversations,
      none()
    ];
  }
  let $2 = _block$1;
  let selected_conversation;
  let conversations;
  let additional_effect;
  selected_conversation = $2[0];
  conversations = $2[1];
  additional_effect = $2[2];
  return [
    new Model(
      new LoggedIn(
        new LoginState(
          login_state.session,
          login_state.web_socket,
          new_conversation,
          selected_conversation,
          conversations
        )
      ),
      model.global_state
    ),
    batch(toList([effect, additional_effect]))
  ];
}
function handle_socket_event(model, socket_event) {
  if (socket_event instanceof InvalidUrl) {
    throw makeError(
      "panic",
      FILEPATH3,
      "app",
      240,
      "handle_socket_event",
      "invalid socket url",
      {}
    );
  } else if (socket_event instanceof OnOpen) {
    let socket = socket_event[0];
    console_log("WebSocket connected successfully");
    let $ = model.app_state;
    if ($ instanceof LoggedIn) {
      let login_state = $[0];
      let updated_login_state = new LoginState(
        login_state.session,
        new Established(socket),
        login_state.new_conversation,
        login_state.selected_conversation,
        login_state.conversations
      );
      return [
        new Model(new LoggedIn(updated_login_state), model.global_state),
        none()
      ];
    } else {
      return [model, none()];
    }
  } else if (socket_event instanceof OnTextMessage) {
    let message2 = socket_event[0];
    console_log("Received WebSocket message: " + message2);
    return [model, none()];
  } else if (socket_event instanceof OnBinaryMessage) {
    throw makeError(
      "panic",
      FILEPATH3,
      "app",
      255,
      "handle_socket_event",
      "received unexpected binary message",
      {}
    );
  } else {
    let close_reason = socket_event[0];
    console_log("WebSocket closed: " + inspect2(close_reason));
    let $ = model.app_state;
    if ($ instanceof LoggedIn) {
      let login_state = $[0];
      let updated_login_state = new LoginState(
        login_state.session,
        new Pending(system_time2()),
        login_state.new_conversation,
        login_state.selected_conversation,
        login_state.conversations
      );
      return [
        new Model(new LoggedIn(updated_login_state), model.global_state),
        none()
      ];
    } else {
      return [model, none()];
    }
  }
}
function update3(model, msg) {
  let noop = [model, none()];
  let login2 = (session_dto) => {
    return [
      new Model(
        new LoggedIn(
          new LoginState(
            session_dto,
            new Pending(system_time2()),
            new None(),
            new None(),
            new_map()
          )
        ),
        model.global_state
      ),
      batch(toList([]))
    ];
  };
  if (msg instanceof LoginSuccess) {
    let session_dto = msg[0];
    let $ = model.app_state;
    if ($ instanceof PreLogin) {
      let _pipe = session_dto;
      return login2(_pipe);
    } else {
      return noop;
    }
  } else if (msg instanceof ShowToast) {
    let toast_msg = msg[0];
    return show_toast(model, toast_msg);
  } else if (msg instanceof RemoveToast) {
    let toast_id = msg[0];
    return remove_toast(model, toast_id);
  } else if (msg instanceof WsWrapper) {
    let socket_event = msg[0];
    return handle_socket_event(model, socket_event);
  } else if (msg instanceof CheckedAuth) {
    let $ = msg[0];
    if ($ instanceof Ok) {
      let session_dto = $[0];
      let _pipe = session_dto;
      return login2(_pipe);
    } else {
      return noop;
    }
  } else if (msg instanceof NewConversationMsg) {
    let msg$1 = msg[0];
    return handle_new_conversation_msg(model, msg$1);
  } else if (msg instanceof UserOnSendSubmit) {
    return [model, send_message(model)];
  } else {
    throw makeError(
      "todo",
      FILEPATH3,
      "app",
      110,
      "update",
      "`todo` expression evaluated. This code has not yet been implemented.",
      {}
    );
  }
}
function view_new_conversation(state) {
  return div(
    toList([class$("fixed inset-0 z-50")]),
    toList([
      div(
        toList([
          class$("absolute inset-0 bg-gray-400/70"),
          on_click(new NewConversationMsg(new UserModalClose()))
        ]),
        toList([])
      ),
      div(
        toList([
          class$(
            "absolute inset-0 grid place-items-center z-10 pointer-events-none"
          )
        ]),
        toList([
          div(
            toList([
              class$(
                "pointer-events-auto bg-white rounded-lg shadow-xl p-6 w-full max-w-md"
              )
            ]),
            toList([
              h3(
                toList([class$("text-xl font-bold text-blue-600 mb-4")]),
                toList([text3("Start a new conversation")])
              ),
              input(
                toList([
                  class$(
                    "w-full border border-gray-300 rounded px-3 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  ),
                  placeholder("Search user..."),
                  on_input(
                    (value2) => {
                      return new NewConversationMsg(
                        new UserSearchInputChange(value2)
                      );
                    }
                  )
                ])
              ),
              div(
                toList([]),
                toList([
                  (() => {
                    let $ = state.suggestions;
                    if ($ instanceof Empty) {
                      return p(
                        toList([class$("text-gray-500")]),
                        toList([text3("Search results will appear here.")])
                      );
                    } else {
                      let dtos = $;
                      return div(
                        toList([]),
                        map2(
                          dtos,
                          (dto) => {
                            return button(
                              toList([
                                class$(
                                  "flex items-center gap-1 p-4 hover:bg-gray-100 cursor-pointer w-full"
                                ),
                                on_click(
                                  (() => {
                                    let _pipe = dto;
                                    let _pipe$1 = new UserConversationPartnerSelect(
                                      _pipe
                                    );
                                    return new NewConversationMsg(_pipe$1);
                                  })()
                                )
                              ]),
                              toList([text3(dto.username.v)])
                            );
                          }
                        )
                      );
                    }
                  })()
                ])
              )
            ])
          )
        ])
      )
    ])
  );
}
function latest_message_time(messages) {
  let _pipe = messages;
  let _pipe$1 = first(_pipe);
  let _pipe$2 = map4(
    _pipe$1,
    (msg) => {
      return unwrap(msg.sent_time, from_unix_seconds(0));
    }
  );
  return unwrap2(_pipe$2, from_unix_seconds(0));
}
function view_chat(model) {
  let session;
  let new_conv;
  let selected_conversation;
  let conversations;
  session = model.session;
  new_conv = model.new_conversation;
  selected_conversation = model.selected_conversation;
  conversations = model.conversations;
  return div(
    toList([class$("flex h-screen bg-gray-50 text-gray-800")]),
    toList([
      div(
        toList([class$("w-1/3 flex flex-col bg-white border-r border-gray-200")]),
        toList([
          div(
            toList([class$("p-4 bUserModalOpenr-b border-gray-200")]),
            toList([
              h2(
                toList([class$("text-xl font-bold text-blue-600")]),
                toList([text3("Chats")])
              )
            ])
          ),
          div(
            toList([class$("p-4")]),
            toList([
              input(
                toList([
                  class$(
                    "w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  ),
                  placeholder("Search chats...")
                ])
              )
            ])
          ),
          div(
            toList([class$("flex-1 overflow-y-auto")]),
            prepend(
              button(
                toList([
                  class$(
                    "flex items-center gap-1 p-4 hover:bg-gray-100 cursor-pointer w-full"
                  ),
                  on_click(new NewConversationMsg(new UserModalOpen()))
                ]),
                toList([
                  message_circle_plus(toList([class$("size-4")])),
                  text3("New conversation")
                ])
              ),
              (() => {
                let _pipe = conversations;
                let _pipe$1 = map_to_list(_pipe);
                let _pipe$2 = sort(
                  _pipe$1,
                  (left, right) => {
                    return break_tie(
                      compare4(
                        latest_message_time(left[1]),
                        latest_message_time(right[1])
                      ),
                      compare3(left[0].username.v, right[0].username.v)
                    );
                  }
                );
                return map2(
                  _pipe$2,
                  (conversation) => {
                    return div(
                      toList([class$("p-4 hover:bg-gray-100 cursor-pointer")]),
                      toList([text3(conversation[0].username.v)])
                    );
                  }
                );
              })()
            )
          )
        ])
      ),
      div(
        toList([class$("w-2/3 flex flex-col")]),
        toList([
          header(
            toList([class$("p-4 border-b border-gray-200 bg-white shadow-sm")]),
            toList([
              h1(
                toList([class$("text-xl font-semibold")]),
                toList([text3("Welcome " + session.username.v + "!")])
              )
            ])
          ),
          main(
            toList([class$("flex-1 p-4 overflow-y-auto")]),
            toList([
              p(
                toList([]),
                toList([text3("Select a friend to start chatting...")])
              )
            ])
          ),
          footer(
            toList([class$("p-4 bg-white border-t border-gray-200")]),
            toList([
              div(
                toList([class$("flex")]),
                toList([
                  input(
                    toList([
                      class$(
                        "w-full border border-gray-300 rounded-l-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100 "
                      ),
                      disabled(
                        (() => {
                          let _pipe = selected_conversation;
                          return is_none(_pipe);
                        })()
                      ),
                      placeholder("Message...")
                    ])
                  ),
                  button(
                    toList([
                      class$(
                        (() => {
                          let _pipe = "bg-blue-600 text-white font-semibold py-2 px-4 rounded-r-md transition-colors";
                          let _pipe$1 = default_disabled_class(_pipe);
                          return default_hovered_class(_pipe$1);
                        })()
                      ),
                      disabled(
                        (() => {
                          let _pipe = selected_conversation;
                          return is_none(_pipe);
                        })()
                      ),
                      on_click(new UserOnSendSubmit())
                    ]),
                    toList([text3("Send")])
                  )
                ])
              )
            ])
          )
        ])
      ),
      (() => {
        if (new_conv instanceof Some) {
          let new_conv_state = new_conv[0];
          return view_new_conversation(new_conv_state);
        } else {
          return div(toList([]), toList([]));
        }
      })()
    ])
  );
}
function view2(model) {
  let toasts = toast_incl_socket_disconnet(model);
  return div(
    toList([]),
    toList([
      (() => {
        let $ = model.app_state;
        if ($ instanceof PreLogin) {
          return element4(
            toList([
              on_login_success(
                (var0) => {
                  return new LoginSuccess(var0);
                }
              ),
              on_show_toast(
                (var0) => {
                  return new ShowToast(var0);
                }
              )
            ])
          );
        } else {
          let login_state = $[0];
          return view_chat(login_state);
        }
      })(),
      view_toasts(toasts)
    ])
  );
}
function main2() {
  let app = application(init2, update3, view2);
  let $ = register();
  if (!($ instanceof Ok)) {
    throw makeError(
      "let_assert",
      FILEPATH3,
      "app",
      40,
      "main",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 1228,
        end: 1267,
        pattern_start: 1239,
        pattern_end: 1244
      }
    );
  }
  let $1 = start3(app, "#app", void 0);
  if (!($1 instanceof Ok)) {
    throw makeError(
      "let_assert",
      FILEPATH3,
      "app",
      41,
      "main",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $1,
        start: 1270,
        end: 1319,
        pattern_start: 1281,
        pattern_end: 1286
      }
    );
  }
  return $1;
}

// build/.lustre/entry.mjs
main2();
