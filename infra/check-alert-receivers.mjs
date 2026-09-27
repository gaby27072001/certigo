import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Read a fresh GET actionGroups response using API 2026-03-01-preview.
// Enabled alone does not establish tenant-wide email OTP verification.
export function checkAlertReceivers(group) {
  if (group?.properties?.enabled !== true) {
    throw new Error('Action group is missing or disabled.');
  }
  const receivers = group.properties.emailReceivers;
  if (!Array.isArray(receivers) || !receivers.some((receiver) => receiver?.name === 'secops')) {
    throw new Error('Required secops email receiver is missing.');
  }
  for (const receiver of receivers) {
    if (receiver?.status !== 'Enabled' || receiver?.verificationStatus !== 'Verified') {
      throw new Error(
        'Email receiver is disabled, unverified, or verification state is unknown. '
        + 'Read API 2026-03-01-preview and complete OTP via the portal; do not skip this check.',
      );
    }
    if (typeof receiver.emailAddress !== 'string' || !receiver.emailAddress.trim()) {
      throw new Error('Email receiver has no address.');
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (process.argv.length !== 3) {
      throw new Error('Usage: node infra/check-alert-receivers.mjs <fresh-action-group.json>');
    }
    let group;
    try {
      group = JSON.parse(readFileSync(process.argv[2], 'utf8').replace(/^\uFEFF/, ''));
    } catch {
      throw new Error('Action-group response is unreadable or invalid JSON.');
    }
    checkAlertReceivers(group);
    console.log('Alert email receivers are enabled and OTP-verified. This is not proof of email delivery.');
  } catch (error) {
    console.error(`alert-receivers: ${error.message}`);
    process.exitCode = 1;
  }
}
