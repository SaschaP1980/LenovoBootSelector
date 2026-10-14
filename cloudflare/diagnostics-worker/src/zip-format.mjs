// Strict canonical ZIP structure validation; does not inflate or publish any
// diagnostic contents. A bounded parser prevents path traversal, zip bombs,
// extra files, multi-disk archives, encryption, symlinks and ZIP64 surprises.
export const REQUIRED_ENTRIES = Object.freeze([
  "runtime.jsonl", "environment.json", "task-broker-summary.json", "summary.txt",
]);
const MAX_EXPANDED_ARCHIVE = 8 * 1024 * 1024;
function reject() { throw new Error("invalid_diagnostic_zip"); }
function uint16(view, offset) { return view.getUint16(offset, true); }
function uint32(view, offset) { return view.getUint32(offset, true); }

function asciiName(bytes, offset, length) {
  let text = "";
  if (length === 0 || length > 64 || offset + length > bytes.length) reject();
  for (let i=offset; i<offset+length; i++) {
    const code = bytes[i];
    if (code < 32 || code > 126) reject();
    text += String.fromCharCode(code);
  }
  return text;
}

export function inspectDiagnosticZip(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length < 22 ||
      bytes.length > 2 * 1024 * 1024) reject();
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let end = -1;
  // ZIP end-of-central-directory may contain a variable-length comment.
  for (let i = bytes.length-22; i>=Math.max(0,bytes.length-65557); i--) {
    if (uint32(v,i) === 0x06054b50 &&
        i + 22 + uint16(v,i+20) === bytes.length) { end=i; break; }
  }
  if (end<0 || uint16(v,end+4)!==0 || uint16(v,end+6)!==0) reject();
  const count = uint16(v,end+10);
  if (count!==REQUIRED_ENTRIES.length || uint16(v,end+8)!==count) reject();
  const dirSize=uint32(v,end+12), dirStart=uint32(v,end+16);
  if (dirStart+dirSize!==end || dirStart<0 || dirSize<46*count) reject();
  const found = new Set();
  const entries=[];
  let cursor=dirStart, uncompressedTotal=0;
  for(let i=0;i<count;i++) {
    if(cursor+46>end || uint32(v,cursor)!==0x02014b50) reject();
    const flags=uint16(v,cursor+8), method=uint16(v,cursor+10);
    if ((flags & (1|0x40)) !== 0 || (method!==0 && method!==8)) reject();
    const compressed=uint32(v,cursor+20), expanded=uint32(v,cursor+24);
    const nameLength=uint16(v,cursor+28), extra=uint16(v,cursor+30);
    const comment=uint16(v,cursor+32);
    const localOffset=uint32(v,cursor+42);
    const extAttr=uint32(v,cursor+38), madeBy=uint16(v,cursor+4);
    const mode=extAttr>>>16;
    if ((madeBy>>>8)===3 && (mode & 0xf000)===0xa000) reject();
    const next=cursor+46+nameLength+extra+comment;
    if(next>end || compressed>bytes.length || expanded>MAX_EXPANDED_ARCHIVE) reject();
    const name=asciiName(bytes,cursor+46,nameLength);
    if(!REQUIRED_ENTRIES.includes(name) || found.has(name) || name.includes("/") ||
        name.includes("\\") || name.includes("..")) reject();
    found.add(name);
    uncompressedTotal+=expanded;
    if(uncompressedTotal>MAX_EXPANDED_ARCHIVE) reject();
    if(localOffset+30+nameLength>dirStart ||
       uint32(v,localOffset)!==0x04034b50) reject();
    const localFlags=uint16(v,localOffset+6);
    const localMethod=uint16(v,localOffset+8);
    const localNameSize=uint16(v,localOffset+26);
    const localExtraSize=uint16(v,localOffset+28);
    if(localMethod!==method || localFlags!==flags || localNameSize!==nameLength ||
       asciiName(bytes,localOffset+30,localNameSize)!==name) reject();
    const dataOffset=localOffset+30+localNameSize+localExtraSize;
    if(dataOffset+compressed>dirStart) reject();
    entries.push({name, method, compressedBytes:compressed,
      expandedBytes:expanded, dataOffset, crc32:uint32(v,cursor+16)});
    cursor=next;
  }
  if(cursor!==end || found.size!==REQUIRED_ENTRIES.length) reject();
  return Object.freeze({entries:Object.freeze(entries),expandedBytes:uncompressedTotal});
}


// Bounded decompression for private, read-only ChatGPT text diagnostics.
// Only four validated canonical entries are eligible; no arbitrary filenames.
const MAX_SINGLE_ENTRY_BYTES = 2 * 1024 * 1024;

async function readBounded(stream, maxBytes) {
  const reader = stream.getReader();
  const chunks = [];
  let size=0;
  try {
    while(true) {
      const {done,value}=await reader.read();
      if(done) break;
      if (!(value instanceof Uint8Array)) throw new Error("invalid_decompressed_chunk");
      size+=value.byteLength;
      if(size>maxBytes) throw new Error("expanded_archive_limit");
      chunks.push(value);
    }
    const data=new Uint8Array(size);
    let offset=0;
    for(const chunk of chunks){data.set(chunk,offset);offset+=chunk.byteLength;}
    return data;
  } finally {
    reader.releaseLock();
  }
}
function crc32(bytes) {
  let crc=-1;
  for(const byte of bytes) {
    crc^=byte;
    for(let b=0;b<8;b++)crc=(crc>>>1)^((crc&1)?0xEDB88320:0);
  }
  return (crc^-1)>>>0;
}

export async function extractDiagnosticText(bytes) {
  const structure=inspectDiagnosticZip(bytes);
  const output={};
  const textDecoder=new TextDecoder("utf-8",{fatal:true});
  let total=0;
  for(const entry of structure.entries) {
    if(entry.expandedBytes>MAX_SINGLE_ENTRY_BYTES) throw new Error("expanded_archive_limit");
    const compressed=bytes.subarray(entry.dataOffset,entry.dataOffset+entry.compressedBytes);
    const plain=entry.method===0
      ? compressed
      : await readBounded(new Blob([compressed]).stream()
            .pipeThrough(new DecompressionStream("deflate-raw")),MAX_SINGLE_ENTRY_BYTES);
    if(plain.byteLength!==entry.expandedBytes || crc32(plain)!==entry.crc32) {
      throw new Error("diagnostic_archive_integrity_failure");
    }
    total+=plain.byteLength;
    if(total>MAX_EXPANDED_ARCHIVE) throw new Error("expanded_archive_limit");
    output[entry.name]=textDecoder.decode(plain);
  }
  return output;
}
