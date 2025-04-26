# Dockerfile for Patient Service

# 1. Base Image
FROM node:18

# 2. Set working directory
WORKDIR /app

# 3. Copy package files (assuming you create a minimal package.json)
COPY package*.json ./

# 4. Install dependencies
RUN npm install

# 5. Copy all source code
COPY . .

# 6. Expose the port (default 3001)
EXPOSE 3001

# 7. Command to run the app
CMD ["node", "appointment-service.js"]
