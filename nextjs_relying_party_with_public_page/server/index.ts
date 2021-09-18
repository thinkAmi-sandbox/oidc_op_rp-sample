import express from 'express'
import { auth } from 'express-openid-connect'
import  next from 'next'
// Redisの設定
import redis from 'redis'
import connectRedis from 'connect-redis'
import {parse} from "url";
const RedisStore = connectRedis(auth)

const dev = process.env.NODE_ENV !== 'production'

const app = next({ dev })
const handle = app.getRequestHandler()

app.prepare().then(() => {
  const server = express();
  const port = process.env.PORT

  // Redisクライアントを定義
  // https://docs.redis.com/latest/rs/references/client_references/client_nodejs/
  // TypeScriptでのエラーが出るため、undefined にならないようにしておく
  const redisPort = process.env.REDIS_PORT || '16380'
  const redisClient = redis.createClient({
    host: process.env.REDIS_HOST,
    port: parseInt(redisPort, 10),
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
      name: 'sessionOfExpressPublic', // sessionの名前を変える
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      store: new RedisStore({client: redisClient}) // セッションストアをRedisにする
    },
    authRequired: false,
  }));

  server.all('*', (req, res) => {
    return handle(req, res)
  })

  // https://stackoverflow.com/questions/56291321/how-to-handle-errors-with-express-listen-in-typescript
  // https://stackoverflow.com/questions/56465562/how-to-check-error-in-express-listen-callback
  // https://github.com/expressjs/express/issues/2856
  server.listen(port, () => {
    console.log(`> Ready on http://localhost:${port}`)
  }).on('error', function(e) {
    console.log('Error happened: ', e.message)
  })
})
