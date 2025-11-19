# MongoDB Replica Set Setup

A dynamic, interactive MongoDB replica set setup system that can be executed directly from GitHub. This tool automates the entire process of deploying MongoDB replica sets with automatic dependency checking, interactive configuration, and full user management capabilities.

## Features

- 🚀 **Direct GitHub Execution** - Run without cloning the repository
- 🔍 **Automatic Dependency Checking** - Validates all required tools before setup
- ⚙️ **Interactive Configuration** - Smart prompts with auto-detected defaults
- 🔐 **Secure by Default** - Auto-generated credentials and keyfiles
- 📦 **Dynamic Scaling** - Configure 1-50 replica set members
- 👥 **User Management** - JSON-based user and role configuration
- 🔄 **Configuration Preservation** - Keeps existing settings on re-runs

## Quick Start

### Execute from GitHub

Run the setup directly from GitHub without cloning:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/app/mongo-setup/initiate.sh)
```

### Execute Locally

If you have the repository cloned:

```bash
cd /path/to/repository
bash initiate.sh
```

## Prerequisites

The system will automatically check for these dependencies:

- **Docker** (with daemon running)
- **Docker Compose** (v2.x or higher)
- **bash** (v4.0+)
- **curl** or **wget**
- **jq** (for JSON processing)
- **openssl** (for keyfile generation)

If any dependency is missing, the system will display installation instructions for your operating system.

## Configuration Parameters

The system will interactively prompt for the following configuration parameters:

| Parameter | Environment Variable | Default Value | Description |
|-----------|---------------------|---------------|-------------|
| **Replica Count** | `REPLICA_COUNT` | `3` | Number of MongoDB replica set members (1-50) |
| **Host IP** | `REPLICA_HOST_IP` | Auto-detected | IPv4 address for replica set communication |
| **Starting Port** | `STARTING_PORT` | `27017` | Base port number for MongoDB instances |
| **Users JSON Path** | `USERS_JSON_PATH` | `./scripts/users.json` | Path to user definitions file |
| **Keyfile Path** | `KEYFILE_PATH` | `./secrets/mongodb-keyfile` | Path to replica set keyfile |
| **Root Username** | `MONGO_INITDB_ROOT_USERNAME` | Auto-generated | MongoDB root username |
| **Root Password** | `MONGO_INITDB_ROOT_PASSWORD` | Auto-generated | MongoDB root password |

### Configuration File (.env)

All configuration is stored in a `.env` file. Example:

```bash
# MongoDB Replica Set Configuration
# Generated on: 2024-11-19T10:30:00Z

# Root Credentials
MONGO_INITDB_ROOT_USERNAME=admin_a1b2c3d4
MONGO_INITDB_ROOT_PASSWORD=e5f6g7h8i9j0k1l2m3n4o5p6

# Replica Set Configuration
REPLICA_COUNT=3
REPLICA_HOST_IP=192.168.1.100
STARTING_PORT=27017

# File Paths
USERS_JSON_PATH=./scripts/users.json
KEYFILE_PATH=./secrets/mongodb-keyfile
```

## Usage

### Automated Setup (Recommended)

Select option **1. Automated Setup** from the menu. This will:

1. ✅ Check all system dependencies
2. ⚙️ Gather configuration (interactive or from existing .env)
3. 📝 Generate required files (.env, keyfile, users.json)
4. 🐳 Create and start Docker containers
5. 🔄 Initialize MongoDB replica set
6. 👥 Create users from users.json

### Manual Steps

You can also run individual steps from the menu:

- **2. Create Container** - Generate docker-compose.yaml and start containers
- **3. Initialize Replicaset** - Initialize the MongoDB replica set
- **4. Create Users** - Create users and roles from users.json
- **5. Connect to DB** - Connect to MongoDB via mongosh
- **6. Reset Everything** - Remove all containers, volumes, and generated files
- **7. Show URL** - Display connection strings

## User Management

### users.json Format

Define users in JSON format at the configured path (default: `./scripts/users.json`):

```json
[
  {
    "user": "admin_user",
    "pass": "secure_password_123",
    "roles": [
      {
        "role": "root",
        "db": "admin"
      }
    ]
  },
  {
    "user": "app_user",
    "pass": "app_password_456",
    "roles": [
      {
        "role": "readWrite",
        "db": "myapp_db"
      },
      {
        "role": "read",
        "db": "analytics_db"
      }
    ]
  }
]
```

### Available MongoDB Roles

Common roles you can assign:

- **Database User Roles**: `read`, `readWrite`
- **Database Admin Roles**: `dbAdmin`, `dbOwner`, `userAdmin`
- **Cluster Admin Roles**: `clusterAdmin`, `clusterManager`, `clusterMonitor`
- **Backup/Restore Roles**: `backup`, `restore`
- **All-Database Roles**: `readAnyDatabase`, `readWriteAnyDatabase`, `userAdminAnyDatabase`, `dbAdminAnyDatabase`
- **Superuser Roles**: `root`

## Connection Strings

### Standard Connection

```bash
mongodb://username:password@host:port/database?replicaSet=rs0
```

### Root User Connection

```bash
mongodb://admin_a1b2c3d4:e5f6g7h8i9j0k1l2m3n4o5p6@192.168.1.100:27017/?replicaSet=rs0
```

### Application Connection (Multiple Hosts)

```bash
mongodb://app_user:app_password@192.168.1.100:27017,192.168.1.100:27018,192.168.1.100:27019/myapp_db?replicaSet=rs0
```

## Management Commands

### View Container Logs

```bash
docker compose logs -f
```

### View Specific Container Logs

```bash
docker compose logs -f mongo1
```

### Stop Containers

```bash
docker compose down
```

### Restart Containers

```bash
docker compose restart
```

### Check Replica Set Status

```bash
bash scripts/connect-to-db.sh
# Then in mongosh:
rs.status()
```

### Reset Everything

```bash
bash scripts/reset-all.sh
```

This will remove:
- All Docker containers
- All volumes and data
- Generated docker-compose.yaml
- (Optional) .env and configuration files

## Directory Structure

```
.
├── initiate.sh                 # Main entry point
├── .env                        # Configuration file (generated)
├── docker-compose.yaml         # Docker Compose file (generated)
├── scripts/
│   ├── check-dependencies.sh   # Dependency validation
│   ├── config-manager.sh       # Interactive configuration
│   ├── file-generator.sh       # File generation utilities
│   ├── network-utils.sh        # Network and IPv4 detection
│   ├── validators.sh           # Input validation functions
│   ├── create-container.sh     # Container creation
│   ├── initiate-replicate.sh   # Replica set initialization
│   ├── user-management.sh      # User creation
│   ├── connect-to-db.sh        # MongoDB connection helper
│   ├── show-url.sh             # Display connection URLs
│   ├── reset-all.sh            # Cleanup script
│   └── users.json              # User definitions (generated)
├── secrets/
│   └── mongodb-keyfile         # Replica set keyfile (generated)
├── data/
│   ├── mongo1/                 # MongoDB data for replica 1
│   ├── mongo2/                 # MongoDB data for replica 2
│   └── mongo3/                 # MongoDB data for replica 3
└── logs/
    ├── setup-success.log       # Success operation logs
    └── setup-error.log         # Error logs
```

## Troubleshooting

### Issue: "Docker daemon is not running"

**Solution:**
```bash
# Start Docker daemon
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker
```

### Issue: "Permission denied" when creating files

**Solution:**
```bash
# Ensure you have write permissions in the current directory
chmod u+w .

# Or run from a directory where you have write access
cd ~/projects
bash <(curl -fsSL https://raw.githubusercontent.com/subrata-pasdt/scripts/main/app/mongo-setup/initiate.sh)
```

### Issue: "Failed to download scripts from GitHub"

**Possible Causes:**
- No internet connection
- GitHub is down or rate-limited
- Incorrect repository URL

**Solution:**
```bash
# Check internet connectivity
ping -c 3 github.com

# Try again after a few minutes (GitHub rate limiting)
# Or clone the repository and run locally:
git clone https://github.com/subrata-pasdt/scripts.git
cd scripts/app/mongo-setup
bash initiate.sh
```

### Issue: "Port already in use"

**Solution:**
```bash
# Check what's using the port
sudo lsof -i :27017

# Stop the conflicting service or choose a different starting port
# When prompted, enter a different starting port (e.g., 27020)
```

### Issue: "Replica set initialization failed"

**Solution:**
```bash
# Check container logs
docker compose logs mongo1

# Ensure all containers are running
docker compose ps

# Verify network connectivity between containers
docker compose exec mongo1 ping mongo2

# Try manual initialization
bash scripts/initiate-replicate.sh mongo1
```

### Issue: "User creation failed"

**Possible Causes:**
- Invalid JSON format in users.json
- Replica set not initialized
- Incorrect credentials

**Solution:**
```bash
# Validate JSON format
jq . scripts/users.json

# Check replica set status
docker compose exec mongo1 mongosh --eval "rs.status()"

# Verify root credentials in .env file
cat .env | grep MONGO_INITDB_ROOT

# Retry user creation
bash scripts/user-management.sh mongo1
```

### Issue: "Cannot connect to MongoDB"

**Solution:**
```bash
# Verify containers are running
docker compose ps

# Check if MongoDB is accepting connections
docker compose exec mongo1 mongosh --eval "db.adminCommand('ping')"

# Verify firewall rules (if connecting remotely)
sudo ufw status
sudo ufw allow 27017/tcp

# Check connection string format
bash scripts/show-url.sh
```

### Issue: "Keyfile permission errors"

**Solution:**
```bash
# Keyfile must have 400 permissions and be owned by MongoDB user
chmod 400 secrets/mongodb-keyfile
sudo chown 999:999 secrets/mongodb-keyfile

# Restart containers
docker compose restart
```

### Issue: "Out of disk space"

**Solution:**
```bash
# Check disk usage
df -h

# Clean up Docker resources
docker system prune -a --volumes

# Remove old MongoDB data
rm -rf data/*

# Re-run setup
bash initiate.sh
```

## Advanced Configuration

### Custom Replica Set Name

Edit `scripts/create-container.sh` and `scripts/initiate-replicate.sh` to change `rs0` to your desired name.

### TLS/SSL Configuration

Currently not supported. Future enhancement planned.

### Remote Replica Set Members

To configure replica set members across different hosts:

1. Ensure network connectivity between hosts
2. Configure firewall rules to allow MongoDB ports
3. Use public IP addresses for `REPLICA_HOST_IP`
4. Manually edit the replica set configuration after initialization

### Custom MongoDB Version

Edit `scripts/create-container.sh` and change the image version:

```yaml
image: mongo:7.0  # Change to desired version
```

## Security Best Practices

1. **Change Default Passwords**: Always update the auto-generated passwords in `.env` and `users.json`
2. **Restrict Network Access**: Use firewall rules to limit MongoDB port access
3. **Use Strong Passwords**: Minimum 16 characters with mixed case, numbers, and symbols
4. **Rotate Credentials**: Regularly update passwords and keyfiles
5. **Backup Keyfile**: Store the keyfile securely; it's required for replica set authentication
6. **Don't Commit Secrets**: Never commit `.env`, `secrets/`, or `users.json` to version control
7. **Use TLS**: Enable TLS/SSL for production deployments (future enhancement)
8. **Limit Root Access**: Create application-specific users with minimal required permissions
9. **Monitor Access**: Regularly review MongoDB logs for unauthorized access attempts
10. **Keep Updated**: Regularly update MongoDB and Docker to latest stable versions

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues, questions, or contributions:

- **GitHub Issues**: [Create an issue](https://github.com/subrata-pasdt/scripts/issues)
- **Documentation**: This README and inline script comments
- **MongoDB Documentation**: [MongoDB Manual](https://docs.mongodb.com/manual/)

## Changelog

### Version 2.0 (Current)
- ✨ Direct GitHub execution support
- ✨ Interactive configuration with smart defaults
- ✨ Automatic dependency checking
- ✨ Dynamic replica set scaling (1-50 members)
- ✨ Auto-generated credentials and keyfiles
- ✨ Configuration preservation and backup
- ✨ Comprehensive error handling and validation
- ✨ Colored output for better UX

### Version 1.0
- Basic MongoDB replica set setup
- Manual configuration
- Fixed 3-member replica sets

## Acknowledgments

- Built with [pasdt-devops-scripts](https://github.com/subrata-pasdt/scripts) for colored output
- Powered by [Docker](https://www.docker.com/) and [MongoDB](https://www.mongodb.com/)

---

**Made with ❤️ for the MongoDB community**
