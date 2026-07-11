# Security

Treebeard starts an unauthenticated local inference API. It binds to
`127.0.0.1` by default. If you change the bind address, add authentication,
TLS, firewall rules, request limits, and appropriate logging before allowing
untrusted clients to connect.

Treat model-generated tool calls as untrusted input. Validate arguments,
authorize privileged actions, confirm external side effects, sandbox tool
execution, and retain audit logs.

Please report suspected vulnerabilities with GitHub's private vulnerability
reporting feature rather than opening a public issue containing exploit or
credential details.
