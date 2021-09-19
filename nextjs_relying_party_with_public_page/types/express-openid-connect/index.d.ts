import 'express-openid-connect'

// 型を拡張する
// https://code-log.hatenablog.com/entry/2020/02/16/195510
declare module 'express-openid-connect' {
  interface ResponseContext {
    errorOnRequiredAuth? :boolean
  }
}
