import Link from 'next/link';

export const getServerSideProps = async function ({ req, res }) {
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
