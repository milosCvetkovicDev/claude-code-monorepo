#!/usr/bin/env node

/**
 * Pre-commit hook: Enforce work email for Git commits
 *
 * Ensures all commits use me@initech.example
 * instead of personal email me@example.com
 */
import { execSync } from 'child_process';
import { dirname } from 'path';
import { fileURLToPath } from 'url';

const REQUIRED_EMAIL = 'me@initech.example';
const PERSONAL_EMAIL = 'me@example.com';

function getGitConfig(key) {
  try {
    return execSync(`git config ${key}`, { encoding: 'utf8' }).trim();
  } catch (error) {
    return null;
  }
}

function setGitConfig(key, value, scope = 'local') {
  execSync(`git config --${scope} ${key} "${value}"`, { encoding: 'utf8' });
}

function main() {
  // Get current Git email
  const currentEmail = getGitConfig('user.email');

  if (!currentEmail) {
    console.error(`\n❌ Git user.email not configured!`);
    console.error(`\nSetting to: ${REQUIRED_EMAIL}\n`);
    setGitConfig('user.email', REQUIRED_EMAIL);
    return;
  }

  // Check if using personal email
  if (currentEmail === PERSONAL_EMAIL) {
    console.warn(`\n⚠️  WARNING: Using personal email for commits!`);
    console.warn(`   Current: ${PERSONAL_EMAIL}`);
    console.warn(`   Required: ${REQUIRED_EMAIL}`);
    console.warn(`\n🔧 Auto-correcting Git config...\n`);

    // Fix the email
    setGitConfig('user.email', REQUIRED_EMAIL);

    console.log(`✅ Git email updated to: ${REQUIRED_EMAIL}`);
    console.log(`   This commit will use the correct email.\n`);
    return;
  }

  // Check if using correct email
  if (currentEmail !== REQUIRED_EMAIL) {
    console.warn(`\n⚠️  WARNING: Unexpected Git email!`);
    console.warn(`   Current: ${currentEmail}`);
    console.warn(`   Expected: ${REQUIRED_EMAIL}`);
    console.warn(`\n🔧 Auto-correcting Git config...\n`);

    // Fix the email
    setGitConfig('user.email', REQUIRED_EMAIL);

    console.log(`✅ Git email updated to: ${REQUIRED_EMAIL}`);
    console.log(`   This commit will use the correct email.\n`);
    return;
  }

  // Email is correct - silent success
}

// Run the check
try {
  main();
} catch (error) {
  console.error(`\n❌ Error checking Git email:`, error.message);
  console.error(`\nPlease manually set your Git email:`);
  console.error(`   git config user.email "${REQUIRED_EMAIL}"\n`);
  process.exit(1);
}
