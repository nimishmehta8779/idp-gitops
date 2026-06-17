const fs = require('fs');
const path = require('path');

const BACKSTAGE_BACKEND_URL = process.env.BACKSTAGE_BACKEND_URL || 'http://localhost:7007';
const REPO_OWNER = 'nimishmehta8779';
const REPO_NAME = 'idp-gitops';

async function fetchToken() {
  try {
    const res = await fetch(`${BACKSTAGE_BACKEND_URL}/api/auth/guest/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    if (!res.ok) {
      throw new Error(`Auth failed with status ${res.status}`);
    }
    const data = await res.json();
    return data.backstageIdentity?.token;
  } catch (err) {
    console.error(`Error fetching Backstage auth token: ${err.message}`);
    process.exit(1);
  }
}

async function fetchEntities(token) {
  try {
    const res = await fetch(`${BACKSTAGE_BACKEND_URL}/api/catalog/entities`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      throw new Error(`Catalog fetch failed with status ${res.status}`);
    }
    return await res.json();
  } catch (err) {
    console.error(`Error fetching catalog entities: ${err.message}`);
    process.exit(1);
  }
}

function parseEntityRef(ref, defaultKind = 'component') {
  if (!ref) return null;
  const parts = ref.split(':');
  let kind = defaultKind;
  let rest = ref;
  if (parts.length > 1 && !parts[0].includes('/')) {
    kind = parts[0].toLowerCase();
    rest = parts.slice(1).join(':');
  }
  const restParts = rest.split('/');
  const namespace = restParts.length > 1 ? restParts[0].toLowerCase() : 'default';
  const name = restParts[restParts.length - 1].toLowerCase();
  return { kind, namespace, name, full: `${kind}:${namespace}/${name}` };
}

async function handleGitHubIssue(findings, markdownTable) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.log('GITHUB_TOKEN not set, skipping GitHub issue creation/update.');
    return;
  }

  const issueTitle = '[Catalog Hygiene] Findings';
  const timestamp = new Date().toISOString();
  let body = `## Catalog Hygiene Scan Report\n\n`;
  if (findings.length === 0) {
    body += `✅ **All entities are compliant.** No orphans or invalid owners found.\n\n*Last scanned at: ${timestamp}*`;
  } else {
    body += `⚠️ **Orphaned or invalid entities were found.** Please review and resolve them.\n\n${markdownTable}\n\n*Last scanned at: ${timestamp}*`;
  }

  const headers = {
    Authorization: `token ${token}`,
    Accept: 'application/vnd.github.v3+json',
    'User-Agent': 'Backstage-Hygiene-Scanner',
    'Content-Type': 'application/json',
  };

  try {
    // 1. Search for existing open issue
    const searchUrl = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues?state=open&creator=${REPO_OWNER}`;
    const searchRes = await fetch(searchUrl, { headers });
    if (!searchRes.ok) {
      throw new Error(`Failed to search GitHub issues: ${searchRes.statusText}`);
    }
    const issues = await searchRes.json();
    const existingIssue = issues.find((issue) => issue.title === issueTitle);

    if (existingIssue) {
      // Update existing issue
      const updateUrl = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues/${existingIssue.number}`;
      console.log(`Updating existing GitHub issue #${existingIssue.number}...`);
      const updateRes = await fetch(updateUrl, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ body }),
      });
      if (!updateRes.ok) {
        throw new Error(`Failed to update issue: ${updateRes.statusText}`);
      }
      console.log(`Successfully updated GitHub issue.`);
    } else {
      // Create new issue
      const createUrl = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues`;
      console.log('Creating new GitHub issue...');
      const createRes = await fetch(createUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify({ title: issueTitle, body }),
      });
      if (!createRes.ok) {
        throw new Error(`Failed to create issue: ${createRes.statusText}`);
      }
      const newIssue = await createRes.json();
      console.log(`Successfully created GitHub issue #${newIssue.number}.`);
    }
  } catch (err) {
    console.error(`GitHub API integration failed: ${err.message}`);
  }
}

async function main() {
  const token = await fetchToken();
  const entities = await fetchEntities(token);

  // 1. Collect all Groups
  const groupRefs = new Set();
  entities.forEach((entity) => {
    if (entity.kind.toLowerCase() === 'group') {
      const namespace = entity.metadata.namespace?.toLowerCase() || 'default';
      const name = entity.metadata.name.toLowerCase();
      groupRefs.add(`group:${namespace}/${name}`);
    }
  });

  const findings = [];

  // 2. Scan entities
  entities.forEach((entity) => {
    const kind = entity.kind.toLowerCase();
    const name = entity.metadata.name.toLowerCase();
    const namespace = entity.metadata.namespace?.toLowerCase() || 'default';
    const entityRef = `${kind}:${namespace}/${name}`;

    // Exclude organizational/infra types
    if (['group', 'user', 'location'].includes(kind)) {
      return;
    }

    const owner = entity.spec?.owner;

    // Check 1: Owner missing
    if (!owner) {
      findings.push({
        ref: entityRef,
        kind: entity.kind,
        problem: 'Missing owner (spec.owner) entirely',
        fix: 'Add spec.owner referencing an existing Group',
      });
      return;
    }

    // Check 2: Group does not exist
    const parsedOwner = parseEntityRef(owner, 'group');
    if (parsedOwner) {
      if (parsedOwner.kind !== 'group') {
        findings.push({
          ref: entityRef,
          kind: entity.kind,
          problem: `Owner kind is '${parsedOwner.kind}' instead of 'group'`,
          fix: 'Update spec.owner to reference a Group instead of a User',
        });
      } else {
        const ownerKey = `group:${parsedOwner.namespace}/${parsedOwner.name}`;
        if (!groupRefs.has(ownerKey)) {
          findings.push({
            ref: entityRef,
            kind: entity.kind,
            problem: `Owner Group '${owner}' does not exist in catalog`,
            fix: `Register the Group or update spec.owner to reference an existing Group`,
          });
        }
      }
    }

    // Check 3: Ghost cluster entry
    if (kind === 'resource' && entity.spec?.type === 'kubernetes-cluster') {
      // Exclude platform-level static clusters
      if (['kind-local-cluster', 'aws-eks-cluster-template'].includes(name)) {
        return;
      }

      // Check local files for claim
      let ownerGroupName = 'None';
      if (parsedOwner && parsedOwner.kind === 'group') {
        ownerGroupName = parsedOwner.name;
      }

      const claimPath1 = path.join('gitops', 'cluster-claims', ownerGroupName, `${name}.yaml`);
      const claimPath2 = path.join('gitops', 'cluster-claims', ownerGroupName, name, 'catalog-info.yaml');

      const exists1 = fs.existsSync(claimPath1);
      const exists2 = fs.existsSync(claimPath2);

      if (!exists1 && !exists2) {
        findings.push({
          ref: entityRef,
          kind: entity.kind,
          problem: 'Ghost cluster entry: corresponding claim file no longer exists in GitOps checkout',
          fix: 'Decommission this resource or recreate the GitOps claim file',
        });
      }
    }

    // Check 4: Component missing score.yaml specification
    if (kind === 'component') {
      const annotations = entity.metadata.annotations || {};
      if (!annotations['score.dev/workload-spec']) {
        findings.push({
          ref: entityRef,
          kind: entity.kind,
          problem: 'Missing score.yaml specification (score.dev/workload-spec annotation)',
          fix: 'Add score.yaml file to repository and add score.dev/workload-spec annotation to catalog-info.yaml',
        });
      }
    }
  });

  // 3. Print report
  let markdownTable = '';
  if (findings.length === 0) {
    console.log('\nAll entities are compliant. No orphans or invalid owners found.\n');
  } else {
    markdownTable = '| Entity Ref | Kind | Problem | Suggested Fix |\n';
    markdownTable += '| --- | --- | --- | --- |\n';
    findings.forEach((f) => {
      markdownTable += `| \`${f.ref}\` | ${f.kind} | ${f.problem} | ${f.fix} |\n`;
    });
    console.log('\n--- Catalog Hygiene Report ---\n');
    console.log(markdownTable);
  }

  // 4. Handle GitHub integration
  await handleGitHubIssue(findings, markdownTable);

  // 5. Exit appropriately
  if (findings.length > 0) {
    console.error(`\nHygiene Check Failed: Found ${findings.length} issues.`);
    process.exit(1);
  } else {
    console.log('Hygiene Check Passed.');
    process.exit(0);
  }
}

main();
