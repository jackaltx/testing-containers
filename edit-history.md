# 202041229 PM 

Let me summarize our Rocky Linux container debugging journey:

1. Initial Issue:
   - Debian container was working
   - Rocky container failed with sudo permission errors
   - Error: "sudo: /usr/bin/sudo must be owned by uid 0 and have the setuid bit set"

2. First Attempt - Containerfile Changes:
   - Added explicit sudo permissions (chmod 4755)
   - Added explicit ownership (chown root:root)
   - Added permission verification steps
   - Added SSH host key generation (ssh-keygen -A)

3. Second Attempt - Container Runtime:
   - Added debugging steps to check container state
   - Added permission checks after container start
   - Used numeric UIDs (0:0) instead of root:root
   - Added verification of sudo setup

4. Final Working Solution:
   - Modified container run command with better security options:
     ```bash
     podman run -d \
         --name test_container \
         --privileged \
         --security-opt label=disable \
         -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
         --cgroupns=host \
         -p 2222:22 \
         "$CONTAINER_TYPE" \
         /sbin/init
     ```
   - Changed inventory to use root directly:
     ```yaml
     ansible_user: root  # Instead of using sudo escalation
     ```
   - Added explicit sudo setup after container start

5. Key Learnings:
   - Rocky Linux needs different container security settings than Debian
   - SELinux considerations are important for Rocky
   - Using root directly is more reliable than sudo for initial setup
   - Systemd and cgroup handling differs between distributions

6. Remaining Tasks:
   - Test the working configuration with a full deployment
   - Document the differences between Debian and Rocky setups
   - Consider if we should standardize the approach between distributions

Would you like me to elaborate on any of these points or look at any specific aspect in more detail?


# 20241229 AM

Let me summarize the key changes we made to get the build script working:

1. Initial Issue - Permission Denied:
   - First encountered error accessing podman configuration in root's directory
   - Tried to fix by setting up user directories and permissions

2. Configuration Files:
   - Created proper podman configuration structure:
   ```
   ~/.config/containers/
   ├── auth.json
   ├── containers.conf
   ├── registries.conf
   └── registries.conf.d/
   ```
   - Set proper permissions (700 for directories, 600 for auth.json)

3. Podman Approach Change:
   - Major shift from running podman with sudo to rootless podman
   - Simplified script by removing complex sudo handling
   - Verified podman was working correctly as user with `podman version`

4. Ansible Integration:
   - First hit an error with the podman connection plugin
   - Switched to using community.docker.docker connection plugin instead
   - Fixed systemd container configuration in podman run command:
   ```bash
   podman run -d \
       --name test_container \
       --privileged \
       -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
       -p 2222:22 \
       "$CONTAINER_TYPE" \
       /sbin/init
   ```

5. Final Fixes:
   - Updated inventory.yml with proper ansible configuration:
     - Set ansible_remote_tmp to /tmp
     - Enabled pipelining
     - Specified Python interpreter
   - Modified Containerfile to:
     - Install python3-pip
     - Create ansible temp directory with proper permissions
     - Set up systemd correctly

The key learning points were:
1. Rootless podman is preferred over running with sudo
2. Container connections in Ansible need careful configuration for systemd containers
3. Temporary directory permissions are critical for Ansible operations
4. The docker connection plugin can work well with podman containers

Would you like me to show you any specific parts of these changes in more detail?