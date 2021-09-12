import Link from 'next/link';

export const getServerSideProps = async function ({ req, res }) {
  // requireAuth() の中身を移植
  // https://github.com/auth0/express-openid-connect/blob/v2.5.0/middleware/requiresAuth.js#L40
  // https://github.com/auth0/express-openid-connect/blob/v2.5.0/middleware/requiresAuth.js#L4
  if (!req.oidc.isAuthenticated()) {

    // これだと、最初に `/profile` へアクセスしたとしても、ログイン後は `/` に戻ってしまう
    return {
      redirect: {
        // 途中のエラーが表示される
        // destination: '/login',
        // Next.js の外としてルーティング
        destination: `${process.env.NEXT_HOST}:${process.env.PORT}/login`,
        permanent: false
      },
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

export default function Profile({ email }) {
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
