const http = require('http');

function getGuestToken(callback) {
  const options = {
    hostname: 'localhost',
    port: 7007,
    path: '/api/auth/guest/refresh?optional=true',
    method: 'GET'
  };

  const req = http.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      if (res.statusCode !== 200) {
        console.error(`Failed to get guest token: ${res.statusCode} ${data}`);
        process.exit(1);
      }
      try {
        const body = JSON.parse(data);
        const token = body.backstageIdentity.token;
        callback(token);
      } catch (e) {
        console.error(`Failed to parse guest token response: ${e.message}`);
        process.exit(1);
      }
    });
  });

  req.on('error', (e) => {
    console.error(`Token request error: ${e.message}`);
    process.exit(1);
  });

  req.end();
}

getGuestToken((token) => {
  const payload = JSON.stringify({
    templateRef: 'template:default/onboard-team',
    values: {
      teamName: 'team-beta',
      displayName: 'Beta Team',
      teamEmail: 'alpha@example.com',
      costCenter: 'CC-1234',
      members: 'nimishmehta8779',
      primaryRegion: 'us-east-1'
    }
  });

  const reqOptions = {
    hostname: 'localhost',
    port: 7007,
    path: '/api/scaffolder/v2/tasks',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload),
      'Authorization': `Bearer ${token}`
    }
  };

  const req = http.request(reqOptions, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      if (res.statusCode !== 201) {
        console.error(`Failed to trigger task: ${res.statusCode} ${data}`);
        process.exit(1);
      }
      const response = JSON.parse(data);
      const taskId = response.id;
      console.log(`Task triggered successfully. Task ID: ${taskId}`);
      pollTaskStatus(taskId, token);
    });
  });

  req.on('error', (e) => {
    console.error(`Request error: ${e.message}`);
    process.exit(1);
  });

  req.write(payload);
  req.end();
});

function pollTaskStatus(taskId, token) {
  const pollInterval = setInterval(() => {
    const options = {
      hostname: 'localhost',
      port: 7007,
      path: `/api/scaffolder/v2/tasks/${taskId}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    };

    const pollReq = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode !== 200) {
          console.error(`Failed to fetch task status: ${res.statusCode} ${data}`);
          clearInterval(pollInterval);
          process.exit(1);
        }
        const task = JSON.parse(data);
        console.log(`Task status: ${task.status}`);
        
        if (task.status === 'completed') {
          console.log('Task completed successfully! ✅');
          clearInterval(pollInterval);
          process.exit(0);
        } else if (task.status === 'failed') {
          console.error('Task failed! ❌');
          // Fetch events to show logs
          fetchTaskLogs(taskId, token, () => {
            clearInterval(pollInterval);
            process.exit(1);
          });
        }
      });
    });

    pollReq.on('error', (e) => {
      console.error(`Poll request error: ${e.message}`);
      clearInterval(pollInterval);
      process.exit(1);
    });

    pollReq.end();
  }, 3000);
}

function fetchTaskLogs(taskId, token, callback) {
  const options = {
    hostname: 'localhost',
    port: 7007,
    path: `/api/scaffolder/v2/tasks/${taskId}/events`,
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  };

  const logReq = http.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      if (res.statusCode === 200) {
        try {
          const events = JSON.parse(data);
          console.log('\n--- Task Execution Logs ---');
          events.forEach(event => {
            if (event.body && event.body.message) {
              console.log(`[${event.body.stepId || 'system'}] ${event.body.message}`);
            }
          });
        } catch (e) {
          console.log('Could not parse logs:', data);
        }
      } else {
        console.error('Failed to fetch events:', res.statusCode);
      }
      callback();
    });
  });

  logReq.on('error', () => callback());
  logReq.end();
}
