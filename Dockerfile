FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install -g serve

COPY . .
RUN npm install && npm run build

EXPOSE 3000

CMD ["serve", "-s", "build", "-l", "3000"]
