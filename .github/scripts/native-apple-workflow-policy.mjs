import { createHash } from 'node:crypto';
import path from 'node:path';

export const nativeAppleWorkflowFile = 'native-apple-check.yml';

// This exception approves one complete unsigned workflow, not a hosted runner pool.
const unsignedWorkflowDigest = '945856c7987480e5d0d23df5b8415355e4c6b90b575ad465a988650620a702c0';

export function isExactNativeAppleWorkflow(text, file) {
  return path.basename(file) === nativeAppleWorkflowFile
    && createHash('sha256').update(text).digest('hex') === unsignedWorkflowDigest;
}

export function validateNativeAppleWorkflow(text, file) {
  if (path.basename(file) !== nativeAppleWorkflowFile || isExactNativeAppleWorkflow(text, file)) {
    return [];
  }
  return [`${file}: native Apple hosted runner requires the exact approved unsigned workflow`];
}
