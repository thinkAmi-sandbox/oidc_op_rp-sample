import Link from 'next/link';
import {OpenidRequest, OpenidResponse} from "express-openid-connect";

type ReturnValues = {
  props: {
    email: string
  }
} | {
  notFound: boolean
}

type Args = {
  req: OpenidRequest
  res: OpenidResponse
}

// 型を拡張してるので、左辺にGetServerSidePropsを書くのではなく、右辺にPromiseを明示的に書く
// 関数の引数の分割代入に対する型指定をワンライナーで書く場合
// export const getServerSideProps = async function ({ req, res }: {req: OpenidRequest, res: OpenidResponse}): Promise<ReturnValues> {
export const getServerSideProps = async function ({ req, res }: Args): Promise<ReturnValues> {

  // requireAuth() の中身を移植
  // https://github.com/auth0/express-openid-connect/blob/v2.5.0/middleware/requiresAuth.js#L40
  // https://github.com/auth0/express-openid-connect/blob/v2.5.0/middleware/requiresAuth.js#L4
  if (!req.oidc.isAuthenticated()) {

    // これだと、最初に `/profile` へアクセスしたとしても、ログイン後は `/` に戻ってしまう
    // return {
    //   redirect: {
    //     // 途中のエラーが表示される
    //     // destination: '/login',
    //     // Next.js の外としてルーティング
    //     destination: `${process.env.NEXT_HOST}:${process.env.PORT}/login`,
    //     permanent: false
    //   },
    // }

    // ログインしても `/profile` へ遷移するようにした
    // ただ、クライアントサイドでの遷移が発生すると、CORSエラーが出る
    // CORS error: Cross-Origin Resource Sharing error: MissingAllowOriginHeader
    if (!res.oidc.errorOnRequiredAuth && req.accepts('html')) {
      await res.oidc.login()
      return {
        props: {
          email: ''
        }
      }
    }
    return {
      notFound: true
    }
  }

  // UserInfoエンドポイントへリクエストを投げて、値を取得する
  // この書き方だとアクセスするたびにUserInfoへリクエストを投げるので注意
  return await req.oidc.fetchUserInfo()
    .then(response => {
      return {
        props: {
          email: response.email
        }
      }
    })
}


type Props = {
  email: string
}

export default function Profile({ email }: Props): JSX.Element {
  return (
    <>
      <h1>Your Profile</h1>
      <p>Email: {email}</p>

      <Link href="/" passHref>
        <button>Go Home</button>
      </Link>
    </>
  )
}
