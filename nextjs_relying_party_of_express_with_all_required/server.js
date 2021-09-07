const express = require('express')
const { auth } = require('express-openid-connect');
const next = require('next');
// Redisの設定
const redis = require('redis');
const {requiresAuth} = require('express-openid-connect');
const RedisStore = require('connect-redis')(auth);


// 本番環境の場合は、package.jsonで以下の設定を行う
// "start": "NODE_ENV=production node server.js"
// https://nextjs.org/docs/advanced-features/custom-server
const dev = process.env.NODE_ENV !== 'production'

const app = next({ dev })
const handle = app.getRequestHandler()

// ここで Redis Clientを定義した場合、
// .env.local の設定値は読み込まれない
// https://nextjs.org/docs/basic-features/environment-variables#loading-environment-variables
// const redisClient = redis.createClient({
//   host: process.env.REDIS_HOST,
//   port: parseInt(process.env.REDIS_PORT, 10),
// });


app.prepare().then(() => {
  const server = express();
  const port = parseInt(process.env.PORT, 10)

  // Redisクライアントを定義
  // https://docs.redis.com/latest/rs/references/client_references/client_nodejs/
  const redisClient = redis.createClient({
    host: process.env.REDIS_HOST,
    port: parseInt(process.env.REDIS_PORT, 10),
  });

  // express-openid-connectの設定を追加
  server.use(auth({
    issuerBaseURL: process.env.OP_BASE_URL,
    baseURL: `${process.env.NEXT_HOST}:${process.env.PORT}`,
    clientID: process.env.CLIENT_ID_OF_MY_OP,
    clientSecret: process.env.CLIENT_SECRET_OF_MY_OP,
    secret: process.env.SECRET_OF_OIDC,
    authorizationParams: {
      response_type: 'code',
      scope: 'openid',
    },
    session: {
      name: 'sessionOfExpressJs', // sessionの名前を変える
      store: new RedisStore({client: redisClient}) // セッションストアをRedisにする
    }
  }));

  server.all('*', requiresAuth(), (req, res) => {
    return handle(req, res)
  })

  server.listen(port, (err) => {
    if (err) throw err
    console.log(`> Ready on http://localhost:${port}`)
  })
})
