# OWNER GATE

The normal UI shows progress and whether owner action is required. Technical logs remain inside the details disclosure.

Owner notifications link directly to `/?approval=<task-id>`. The gate explains the real-world consequence and offers an action-specific button plus `中止する`. A valid one-time approval token changes the task to received and immediately dispatches it; the owner does not need to return to chat to resume the Worker.

No gate may automate CAPTCHA, identity evidence, payment confirmation, public publication or irreversible deletion.

